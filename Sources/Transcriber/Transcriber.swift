//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Speech
import AVFoundation
import Accelerate
import OSLog

// MARK: - SilenceState Extension
extension Transcriber {
    fileprivate struct SilenceState {
        var isSilent: Bool = false
        var startTime: CFAbsoluteTime = 0
        var hasEnded: Bool = false
        
        mutating func update(rms: Float, currentTime: CFAbsoluteTime, threshold: Float, duration: TimeInterval) -> Bool {
            if rms < threshold {
                if !isSilent {
                    isSilent = true
                    startTime = currentTime
                } else if !hasEnded && (currentTime - startTime) >= duration {
                    hasEnded = true
                    return true
                }
            } else {
                isSilent = false
            }
            return false
        }
    }
}

// MARK: - Speech Recognition Service
/// An actor that manages speech recognition operations using Apple's Speech framework
public actor Transcriber {
    // MARK: - Properties
    private let config: TranscriberConfiguration
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private var hasBuiltLm = false
    private var customLmTask: Task<Void, Error>?
    private var lmConfiguration: SFSpeechLanguageModel.Configuration?
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let logger: DebugLogger
    
    // MARK: - Initialization
    
    /// Initialize a new speech recognition service
    /// - Parameters:
    ///   - config: Configuration for speech recognition behavior and settings
    ///   - debugLogging: Enable detailed debug logging (defaults to false)
    public init?(config: TranscriberConfiguration, debugLogging: Bool = false) {
        guard let recognizer = SFSpeechRecognizer(locale: config.locale) else { return nil }
        self.speechRecognizer = recognizer
        self.audioEngine = AVAudioEngine()
        self.config = config
        self.logger = DebugLogger(.transcriber, isEnabled: debugLogging)
        
        if let languageModelInfo = config.languageModelInfo {
            logger.debug("Initializing with custom model: \(languageModelInfo.url.lastPathComponent)")
            self.lmConfiguration = SFSpeechLanguageModel.Configuration(languageModel: languageModelInfo.url)
            Task {
                await self.prepareCustomModel(modelURL: languageModelInfo.url)
            }
        }

        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Custom Model Management
    private func prepareCustomModel(modelURL: URL) async {
        guard let lmConfiguration = lmConfiguration else { return }
        
        logger.debug("Starting custom model preparation")
        customLmTask = Task.detached {
            do {
                try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                    for: modelURL,
                    clientIdentifier: self.config.appIdentifier,
                    configuration: lmConfiguration
                )
                await self.markModelAsBuilt()
                self.logger.debug("Custom model preparation completed")
            } catch {
                self.logger.error("Custom model preparation failed: \(error.localizedDescription)")
                throw TranscriberError.customLanguageModelFailure(error)
            }
        }
    }

    private func markModelAsBuilt() {
        hasBuiltLm = true
        logger.debug("Custom model marked as built")
    }

    // MARK: - Authorization
    
    /// Request authorization for speech recognition
    /// - Returns: The current authorization status
    public func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Recognition Setup
    private func setupRecognition() throws -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        
        // Apply all configuration settings
        request.shouldReportPartialResults = config.shouldReportPartialResults
        request.requiresOnDeviceRecognition = config.requiresOnDeviceRecognition
        request.addsPunctuation = config.addsPunctuation
        request.taskHint = config.taskHint
        
        // Only set contextual strings if provided
        if let contextualStrings = config.contextualStrings {
            logger.debug("Setting contextual strings: \(contextualStrings)")
            request.contextualStrings = contextualStrings
        }
        
        // Apply custom language model if configured
        if let lmConfiguration = lmConfiguration {
            logger.debug("Applying custom language model")
            request.requiresOnDeviceRecognition = true // Force on-device when using custom model
            request.customizedLanguageModel = lmConfiguration
        }
        
        // Store in actor state
        recognitionRequest = request
        return request
    }
    
    // MARK: - Recognition Task Management
    private func createRecognitionTask(
        request: SFSpeechAudioBufferRecognitionRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let transcription = result.bestTranscription.formattedString
                self?.logger.debug("Transcription update: \(transcription)")
                continuation.yield(transcription)
            }
            if let error {
                self?.logger.error("Recognition error: \(error.localizedDescription)")
                continuation.finish(throwing: TranscriberError.recognitionFailure(error))
            } else if result?.isFinal == true {
                self?.logger.debug("Recognition completed")
                continuation.finish()
            }
        }
        recognitionTask = task
    }
    
    private func resetRecognitionState() {
        logger.debug("Resetting recognition state")
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Public Interface
    
    /// Start a stream of speech recognition results
    /// - Returns: An async throwing stream of transcribed text
    /// - Throws: TranscriberError if setup or recognition fails
    public func startRecordingStream() async throws -> AsyncThrowingStream<String, Error> {
        logger.debug("Starting recording stream")
        
        // Wait for model
        if let customLmTask = customLmTask, !hasBuiltLm {
            logger.debug("Waiting for custom model preparation")
            try await customLmTask.value
        }
        
        // Reset state
        resetRecognitionState()
        
        // Setup new recognition
        let localRequest = try setupRecognition()
        
        // Setup audio
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create local silence state
        var silenceState = SilenceState()
        
        // Install tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard !silenceState.hasEnded else { return }
            
            let rms = buffer.calculateRMS()
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            self.logger.debug("Current RMS: \(rms)")
            
            if silenceState.update(
                rms: rms,
                currentTime: currentTime,
                threshold: self.config.silenceThreshold,
                duration: self.config.silenceDuration
            ) {
                self.logger.debug("Silence detected, ending audio")
                localRequest.endAudio()
                Task { @MainActor in
                    await self.stopRecording()
                }
                return
            }
            
            localRequest.append(buffer)
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            logger.debug("Audio engine started")
        } catch {
            logger.error("Audio engine start failed: \(error.localizedDescription)")
            throw TranscriberError.engineFailure(error)
        }

        // Create and return stream
        return AsyncThrowingStream { continuation in
            createRecognitionTask(request: localRequest, continuation: continuation)
        }
    }

    /// Stop the current recording session
    public func stopRecording() {
        logger.debug("Stopping recording")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask = nil
        recognitionRequest = nil
    }
}
