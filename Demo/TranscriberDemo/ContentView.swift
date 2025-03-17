//  Copyright 2025 Compiler, Inc. All rights reserved.

import SwiftUI
import Speech
import Transcriber

// Example usage in view
struct ContentView: View {
    @State private var presenter = DefaultTranscriberPresenter()
    
    var body: some View {
        VStack {
            #if os(iOS)
            // Add input selection picker with proper selection handling
            Picker("Audio Input", selection: Binding(
                get: { presenter.selectedInput },
                set: { if let input = $0 { presenter.selectInput(input) }}
            )) {
                ForEach(presenter.availableInputs, id: \.uid) { input in
                    HStack {
                        Text(input.portName)
                        if input.uid == presenter.selectedInput?.uid {
                            Image(systemName: "checkmark")
                        }
                    }
                    .tag(Optional(input))
                }
            }
            .pickerStyle(.menu)
            .padding()
            #endif
            
            Text(presenter.transcribedText.isEmpty ? "No transcription yet" : presenter.transcribedText)
                .padding()
            
            SpeechButton(
                isRecording: presenter.isRecording,
                rmsValue: presenter.rmsLevel,
                isProcessing: false,
                supportsThinkingState: false,
                onTap: {
                    presenter.toggleRecording { finalText in
                        print("Recording completed with text: \(finalText)")
                    }
                }
            )
            .disabled(presenter.authStatus != .authorized)

            if let error = presenter.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            do {
                try await presenter.requestAuthorization()
            } catch {
                print(error.localizedDescription)
            }
        }
        // Refresh inputs when view appears
        .onAppear {
            #if os(iOS)
            presenter.fetchAvailableInputs()
            #endif
        }
    }
}

#Preview {
    ContentView()
}
