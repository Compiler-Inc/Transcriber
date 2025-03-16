//  Copyright 2025 Compiler, Inc. All rights reserved.

import SwiftUI
import Speech
import Transcriber

// Example usage in view
struct ContentView: View {
    @State private var model = TranscriptionModel()
    
    var body: some View {
        VStack {
            // Add input selection picker
            Picker("Audio Input", selection: Binding(
                get: { model.selectedInput },
                set: { if let input = $0 { model.selectInput(input) }}
            )) {
                ForEach(model.availableInputs, id: \.uid) { input in
                    Text(input.portName)
                        .tag(Optional(input))
                }
            }
            .pickerStyle(.menu)
            .padding()
            
            Text(model.transcribedText.isEmpty ? "No transcription yet" : model.transcribedText)
                .padding()
            
            SpeechButton(
                isRecording: model.isRecording,
                rmsValue: model.rmsLevel,
                isProcessing: false,
                supportsThinkingState: false,
                onTap: {
                    model.toggleRecording()
                }
            )
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
        // Add onAppear to refresh inputs when view appears
        .onAppear {
            model.fetchAvailableInputs()
        }
    }
}

#Preview {
    ContentView()
}
