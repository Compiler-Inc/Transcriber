//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Combine
import Speech

@Observable
@MainActor
public class TranscriptionModel: Transcribable {
    
    public var isRecording = false
    public var transcribedText = ""
    public var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public var error: Error?
    public var rmsLevel: Float = 0
    
    public let transcriber: Transcriber?
    private var recordingTask: Task<Void, Never>?
    
    
    public init(config: TranscriberConfiguration = TranscriberConfiguration(silenceThreshold: 0.01)) {
        self.transcriber = Transcriber(config: config)
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
