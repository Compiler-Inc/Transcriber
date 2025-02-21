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
    
    public let transcriber: Transcriber?
    private var recordingTask: Task<Void, Never>?
    
    public init(config: TranscriberConfiguration = DefaultTranscriberConfig()) {
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
        } else {
            recordingTask = Task {
                do {
                    isRecording = true
                    let stream = try await transcriber.startRecordingStream()
                    
                    for try await transcription in stream {
                        transcribedText = transcription
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
