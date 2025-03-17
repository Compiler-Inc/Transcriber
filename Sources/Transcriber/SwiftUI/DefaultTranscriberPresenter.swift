//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Speech
import AVFoundation

/// Default implementation of SpeechRecognitionPresenter
/// Provides ready-to-use speech recognition functionality for SwiftUI views
@Observable
@MainActor
public class DefaultTranscriberPresenter: TranscriberPresenter {
    public var isRecording = false
    public var transcribedText = ""
    public var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public var error: Error?
    public var rmsLevel: Float = 0
    
    private let transcriber: Transcriber?
    private var recordingTask: Task<Void, Never>?
    private var onCompleteHandler: ((String) -> Void)?
    
    #if os(iOS)
    public var availableInputs: [AVAudioSessionPortDescription] = []
    public var selectedInput: AVAudioSessionPortDescription?
    #endif
    
    public init(config: TranscriberConfiguration = TranscriberConfiguration()) {
        self.transcriber = Transcriber(config: config, debugLogging: true)
        
        #if os(iOS)
        setupAudioSession()
        self.fetchAvailableInputs()
        #endif
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Configure for both playback and recording with all possible options
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [
                .allowAirPlay,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .defaultToSpeaker
            ])
            // Set preferred I/O buffer duration
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            fatalError("Error: \(error.localizedDescription)")
        }
    }
    
    public func toggleRecording(onComplete: ((String) -> Void)? = nil) {
        self.onCompleteHandler = onComplete
        
        guard let transcriber else {
            error = TranscriberError.noRecognizer
            return
        }
        
        if isRecording {
            recordingTask?.cancel()
            recordingTask = nil
            Task {
                await transcriber.stopStream()
                isRecording = false
                onCompleteHandler?(transcribedText)
            }
        } else {
            transcribedText = "" // Reset text when starting new recording
            recordingTask = Task {
                do {
                    isRecording = true
                    let stream = try await transcriber.startStream()
                    
                    for try await signal in stream {
                        switch signal {
                        case .rms(let float):
                            rmsLevel = float
                        case .transcription(let string):
                            transcribedText = string
                        }
                    }
                    
                    // Stream ended naturally (silence detected)
                    isRecording = false
                    onCompleteHandler?(transcribedText)
                } catch {
                    self.error = error
                    isRecording = false
                }
            }
        }
    }
    
    public func requestAuthorization() async throws {
        guard let transcriber else {
            throw TranscriberError.noRecognizer
        }
        authStatus = await transcriber.requestAuthorization()
        guard authStatus == .authorized else {
            throw TranscriberError.notAuthorized
        }
    }
    
    #if os(iOS)
    public func fetchAvailableInputs() {
        availableInputs = AudioInputs.getAvailableInputs()
        // Set initial selection to current input
        if let currentInput = AVAudioSession.sharedInstance().currentRoute.inputs.first,
           let matchingInput = availableInputs.first(where: { $0.uid == currentInput.uid }) {
            selectedInput = matchingInput
        }
    }
    
    public func selectInput(_ input: AVAudioSessionPortDescription) {
        do {
            try AudioInputs.selectInput(input)
            selectedInput = input
        } catch {
            self.error = TranscriberError.audioSessionFailure(error)
        }
    }
    #endif
}
