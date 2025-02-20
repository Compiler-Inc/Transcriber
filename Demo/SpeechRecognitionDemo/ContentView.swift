//  Copyright © 2025 Compiler, Inc. All rights reserved.

import SwiftUI
import SpeechRecognitionService
import Speech

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
