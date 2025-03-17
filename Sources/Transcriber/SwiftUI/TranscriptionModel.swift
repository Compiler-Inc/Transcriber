//  Copyright 2025 Compiler, Inc. All rights reserved.

import Combine
import Speech
import AVFoundation

@Observable
@MainActor
public class TranscriptionModel: TranscriberViewModeling {
    
    public var isRecording = false
    public var transcribedText = ""
    public var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public var error: Error?
    public var rmsLevel: Float = 0
    
    public let transcriber: Transcriber?
    private var recordingTask: Task<Void, Never>?
    
    public var availableInputs: [AVAudioSessionPortDescription] = []
    public var selectedInput: AVAudioSessionPortDescription?
    
    public init(config: TranscriberConfiguration = TranscriberConfiguration(silenceThreshold: 0.01)) {
        self.transcriber = Transcriber(config: config, debugLogging: true)
        self.setupAudioSession()
        self.fetchAvailableInputs()
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
    
    public func fetchAvailableInputs() {
        do {
            availableInputs = AVAudioSession.sharedInstance().availableInputs ?? []
        } catch {
            print("Error fetching inputs: \(error.localizedDescription)")
        }
    }
    
    public func selectInput(_ input: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(input)
            if let dataSources = input.dataSources, let firstSource = dataSources.first {
                try input.setPreferredDataSource(firstSource)
            }
            selectedInput = input
        } catch {
            print("Error selecting input: \(error.localizedDescription)")
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
    
    public func toggleRecording() {
        guard let transcriber else {
            error = TranscriberError.noRecognizer
            return
        }
        
        if isRecording {
            recordingTask?.cancel()
            recordingTask = nil
            isRecording = false
            Task {
                await transcriber.stopStream()
                isRecording = false
            }
        } else {
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
                    
                    isRecording = false
                } catch {
                    self.error = error
                    isRecording = false
                }
            }
        }
    }
}
