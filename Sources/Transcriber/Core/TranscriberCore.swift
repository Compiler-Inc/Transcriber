//  Copyright 2025 Compiler, Inc. All rights reserved.

import Speech
import AVFoundation
import OSLog

// MARK: - Speech Recognition Service
/// An actor that manages speech recognition operations using Apple's Speech framework
public actor TranscriberCore {
    private let config: TranscriberConfiguration
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    
    private lazy var languageModelManager: LanguageModelManager? = {
        guard let modelInfo = config.languageModelInfo else { return nil }
        return LanguageModelManager(modelInfo: modelInfo)
    }()
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    public init?(config: TranscriberConfiguration = TranscriberConfiguration(), debugLogging: Bool = false) {
        guard let recognizer = SFSpeechRecognizer(locale: config.locale) else { return nil }
        self.speechRecognizer = recognizer
        self.audioEngine = AVAudioEngine()
        self.config = config
        self.logger = DebugLogger(.transcriber, isEnabled: debugLogging)
    }
    
    /// Request authorization for speech recognition
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
        
        // Store in actor state
        recognitionRequest = request
        return request
    }
    
    /// Start a stream of speech recognition results
    /// - Returns: An AsyncThrowingStream of transcribed text and RMS values
    /// - Throws: TranscriberError if setup or recognition fails
    private func startCombinedStream() async throws -> AsyncThrowingStream<String, Error> {
        logger.debug("Starting transcription stream...")
        
        if let languageModelManager = languageModelManager {
            try await languageModelManager.waitForModel()
        }
        
        // Reset state
        resetRecognitionState()
        
        let localRequest = try setupRecognition()
        
        // Configure language model only if one exists
        languageModelManager?.configureRequest(request)
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false)
        
        guard let processingFormat = processingFormat else {
            throw TranscriberError.engineFailure(NSError(
                domain: "Transcriber",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create processing format"]))
        }
        
        // Add converter for stereo signals
        let converter = AVAudioConverter(from: inputFormat, to: processingFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard !silenceState.hasEnded else { return }
            
            let rms = buffer.calculateRMS()
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            self.logger.debug("RMS: \(rms)")
            
            // Send RMS value to stream using local continuation
            
            if silenceState.update(
                rms: rms,
                currentTime: currentTime,
                threshold: self.config.silenceThreshold,
                duration: self.config.silenceDuration
            ) {
                self.logger.debug("Silence detected, ending steram")
                localRequest.endAudio()
                Task { @MainActor in
                    await self.stopStream()
                }
                return
            }
            
            // Convert buffer for stereo signal to mono
            if let converter = converter {
                let frameCount = AVAudioFrameCount(buffer.frameLength)
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: processingFormat,
                    frameCapacity: frameCount)
                else { return }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer,
                                error: &error,
                                withInputFrom: inputBlock)
                
                if error == nil {
                    localRequest.append(convertedBuffer)
                }
            } else {
                localRequest.append(buffer)
            }
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
