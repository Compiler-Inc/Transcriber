//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Speech
import AVFoundation
import Accelerate
import OSLog

// MARK: - TranscriberSignal Enum
/// Signal types emitted by the Transcriber's unified stream
///
/// This enum represents the two types of data that can be emitted by the Transcriber:
/// - Audio level data (RMS values) for visualizing microphone input
/// - Transcription text from speech recognition
///
/// Use with `startStream()` to receive both types of data in a single stream.
public enum TranscriberSignal: Sendable {
    /// An audio level measurement (Root Mean Square)
    /// - Parameter Float: A value between 0.0 and 1.0 representing the audio level
    case rms(Float)
    
    /// A transcription result from speech recognition
    /// - Parameter String: The transcribed text
    case transcription(String)
}


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
    
    // RMS streaming support
    private var rmsStream: AsyncStream<Float>?
    private var rmsContinuation: AsyncStream<Float>.Continuation?
    
    private let logger: DebugLogger
    
    // MARK: - Initialization
    
    /// Initialize a new transcriber
    /// - Parameters:
    ///   - config: Configuration for speech recognition behavior and settings
    ///   - debugLogging: Enable detailed debug logging (defaults to false)
    public init?(config: TranscriberConfiguration = TranscriberConfiguration(), debugLogging: Bool = false) {
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
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
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

    // MARK: - RMS Stream Management
    /// Creates a new RMS stream for audio level monitoring
    /// - Returns: An AsyncStream of Float values representing audio RMS levels
    private func createRMSStream() -> AsyncStream<Float> {
        logger.debug("Creating RMS stream")
        
        // Clean up any existing stream
        rmsContinuation?.finish()
        rmsContinuation = nil
        
        // Create a new stream with continuation
        return AsyncStream { continuation in
            self.rmsContinuation = continuation
        }
    }

    // MARK: - Public Interface
    
    /// Start a stream of speech recognition results
    /// - Returns: An async throwing stream of transcribed text
    /// - Throws: TranscriberError if setup or recognition fails
    private func startRecordingStream() async throws -> AsyncThrowingStream<String, Error> {
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
        
        // Create RMS stream and capture continuation locally
        rmsStream = createRMSStream()
        let localRMSContinuation = rmsContinuation
        
        // Install tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard !silenceState.hasEnded else { return }
            
            let rms = buffer.calculateRMS()
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            self.logger.debug("Current RMS: \(rms)")
            
            // Send RMS value to stream using local continuation
            localRMSContinuation?.yield(rms)
            
            if silenceState.update(
                rms: rms,
                currentTime: currentTime,
                threshold: self.config.silenceThreshold,
                duration: self.config.silenceDuration
            ) {
                self.logger.debug("Silence detected, ending audio")
                localRequest.endAudio()
                Task { @MainActor in
                    await self.stopStream()
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
    public func stopStream() {
        logger.debug("Stopping recording")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Clean up RMS stream
        rmsContinuation?.finish()
        rmsContinuation = nil
        rmsStream = nil

        recognitionTask = nil
        recognitionRequest = nil
    }

    // For backward compatibility
    @available(*, deprecated, renamed: "stopStream")
    public func stopRecording() {
        stopStream()
    }
    
    /// Start a stream that provides both transcription and RMS values in a unified stream
    /// 
    /// This method returns a single stream that emits both transcription text and audio level (RMS) values
    /// as they become available. The stream emits values as `TranscriberSignal` enum cases:
    /// 
    /// - `.transcription(String)`: Contains the latest transcribed text from speech recognition
    /// - `.rms(Float)`: Contains the latest Root Mean Square audio level (0.0-1.0) for visualizing audio input
    ///
    /// Example usage:
    /// ```swift
    /// let stream = try await transcriber.startStream()
    /// for await signal in stream {
    ///     switch signal {
    ///     case .transcription(let text):
    ///         // Update UI with transcribed text
    ///         updateTranscriptionLabel(text)
    ///     case .rms(let level):
    ///         // Update audio visualization
    ///         updateAudioLevelIndicator(level)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An AsyncStream of TranscriberSignal values containing either transcription or RMS data
    /// - Throws: TranscriberError if setup or recognition fails
    public func startStream() async throws -> AsyncStream<TranscriberSignal> {
        // Start the transcription stream
        let transcriptionStream = try await startRecordingStream()
        
        // Create a combined stream
        return AsyncStream<TranscriberSignal> { continuation in
            // Task for handling transcription values
            Task {
                do {
                    for try await transcription in transcriptionStream {
                        continuation.yield(.transcription(transcription))
                    }
                } catch {
                    logger.error("Transcription stream error: \(error.localizedDescription)")
                    // We don't finish the continuation here as RMS might still be active
                }
                // When transcription ends naturally, we don't finish the stream
                // as RMS values might still be coming
            }
            
            // Task for handling RMS values
            if let rmsStream = self.rmsStream {
                Task {
                    for await rms in rmsStream {
                        continuation.yield(.rms(rms))
                    }
                    // When RMS stream ends, we can finish the combined stream
                    continuation.finish()
                }
            }
        }
    }
}
