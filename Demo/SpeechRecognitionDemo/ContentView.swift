//  Copyright © 2025 Compiler, Inc. All rights reserved.

import SwiftUI
import SpeechRecognitionService
import Speech

@Observable
@MainActor
public class DefaultSpeechViewModel: SpeechRecognitionManaging {
    
    public var isRecording = false
    public var transcribedText = ""
    public var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public var error: Error?
    
    public let speechService: SpeechRecognitionService?
    private var recordingTask: Task<Void, Never>?
    
    public init(config: SpeechRecognitionConfiguration = DefaultSpeechConfig()) {
        self.speechService = SpeechRecognitionService(config: config)
    }
    
    public func requestAuthorization() async throws {
        guard let speechService else {
            throw SpeechRecognitionError.noRecognizer
        }
        authStatus = await speechService.requestAuthorization()
        guard authStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
    }
    
    public func toggleRecording() {
        guard let speechService else {
            error = SpeechRecognitionError.noRecognizer
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
                    let stream = try await speechService.startRecordingStream()
                    
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

// Example usage in view
struct ContentView: View {
    @State private var viewModel = DefaultSpeechViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.transcribedText.isEmpty ? "No transcription yet" : viewModel.transcribedText)
                .padding()
            
            Button(viewModel.isRecording ? "Stop Recording" : "Start Recording") {
                viewModel.toggleRecording()
            }
            .disabled(viewModel.authStatus != .authorized)
            
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            do {
                try await viewModel.requestAuthorization()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
