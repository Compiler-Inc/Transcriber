# Transcriber

A modern, Swift-native wrapper around Apple's `Speech` framework and `SFSpeechRecognizer` that provides an actor-based interface for speech recognition with automatic silence detection and custom language model support.

## Features

- ✨ Modern Swift concurrency with async/await
- 🔒 Thread-safe actor-based design
- 🎯 Automatic silence detection using RMS power analysis
- 🔊 Support for custom language models
- 📱 Works across iOS, macOS, and other Apple platforms
- 💻 SwiftUI-ready with MVVM support
- 🔍 Comprehensive error handling
- 📊 Debug logging support

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Compiler-Inc/Transcriber.git", from: "0.1.1")
]
```

Or in Xcode:
1. File > Add Packages...
2. Enter `https://github.com/Compiler-Inc/Transcriber.git`
3. Select "Up to Next Major Version" with "0.1.1"

### Privacy Keys

The service requires microphone and speech recognition access. Add these keys to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to transcribe your speech.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We need speech recognition to convert your voice to text.</string>
```

Or in Xcode:
1. Select your project in the sidebar
2. Select your target
3. Select the "Info" tab
4. Add `Privacy - Microphone Usage Description` and `Privacy - Speech Recognition Usage Description`

## Usage

### Basic Implementation

The simplest way to use the service is with the default configuration:

```swift
func startRecording() async throws {
    // Initialize with default configuration
    let transcriber = Transcriber(config: DefaultTranscriberConfig())
    
    // Request authorization
    let status = await transcriber.requestAuthorization()
    guard status == .authorized else {
        throw TranscriberError.notAuthorized
    }
    
    // Start recording and receive transcriptions
    let stream = try await transcriber.startRecordingStream()
    for try await transcription in stream {
        print("Transcribed text: \(transcription)")
    }
}
```

### Configuration Options

The service is highly configurable through the `TranscriberConfiguration` protocol:

```swift
struct MyConfig: TranscriberConfiguration {
    // Required
    let appIdentifier: String = "com.myapp.speech"
    
    // Speech Recognition Settings
    var locale: Locale = .current                     // Recognition language
    var requiresOnDeviceRecognition: Bool = false    // Force on-device processing
    var shouldReportPartialResults: Bool = true      // Get results as they're processed
    var addsPunctuation: Bool = true                 // Automatic punctuation
    var taskHint: SFSpeechRecognitionTaskHint = .unspecified  // Optimize for specific speech types
    var contextualStrings: [String]? = ["Custom", "Words"]    // Improve recognition of specific terms
    
    // Silence Detection
    var silenceThreshold: Float = 0.001      // RMS power threshold (0.0 to 1.0)
    var silenceDuration: TimeInterval = 1.5   // Duration of silence before stopping
    
    // Custom Language Model (Optional)
    var languageModelInfo: LanguageModelInfo? = nil       // For domain-specific recognition
}
```

### Using in SwiftUI

For SwiftUI applications, we provide a protocol-based MVVM pattern:

```swift
// 1. Create your view model
@Observable
@MainActor
class MyViewModel: Transcribable {
    public var isRecording = false
    public var transcribedText = ""
    public var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    public var error: Error?
    
    public let transcriber: Transcriber?
    private var recordingTask: Task<Void, Never>?
    
    init() {
        self.transcriber = Transcriber(config: DefaultTranscriberConfig())
    }
    
    // Required protocol methods
    public func requestAuthorization() async throws {
        guard let transcriber else {
            throw TrannscriberError.noRecognizer
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
// 2. Use in your SwiftUI view
struct MySpeechView: View {
    @State private var viewModel = MyViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.transcribedText)
            Button(viewModel.isRecording ? "Stop" : "Start") {
                viewModel.toggleRecording()
            }
            .disabled(viewModel.authStatus != .authorized)
            
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }
        }
        .task {
            try? await viewModel.requestAuthorization()
        }
    }
}
```

## Advanced Features

### Debug Logging

Enable detailed logging for debugging:

```swift
let transcriber = Transcriber(config: config, debugLogging: true)
```

### Custom Language Models

Support for custom language models with version tracking:

```swift
let model = LanguageModelInfo(url: modelURL,version: "2.0-beta")
let config = DefaultTranscriberConfig(languageModelInfo: model)
```

You can easily build `SFCustomLanguageModelData` models with our [SpeechModelBuilder CLI Tool](https://github.com/Compiler-Inc/SpeechModelBuilder)

### Silence Detection

Automatic silence detection using RMS power analysis with configurable threshold and duration:

```swift
struct SensitiveConfig: TranscriberConfiguration {
    var silenceThreshold: Float = 0.001  // Very sensitive
    var silenceDuration: TimeInterval = 2.0  // Longer confirmation
    // ... other properties
}
```

## License

This project is licensed under the MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 
