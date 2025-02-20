//  Copyright © 2025 Compiler, Inc. All rights reserved.

import SwiftUI
import Speech
import Transcriber

// Example usage in view
struct ContentView: View {
    @State private var model = TranscriptionModel()
    
    var body: some View {
        VStack {
            Text(model.transcribedText.isEmpty ? "No transcription yet" : model.transcribedText)
                .padding()
            
            Button(model.isRecording ? "Stop Recording" : "Start Recording") {
                model.toggleRecording()
            }
            .disabled(model.authStatus != .authorized)
            
            if let error = model.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            do {
                try await model.requestAuthorization()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ContentView()
}
