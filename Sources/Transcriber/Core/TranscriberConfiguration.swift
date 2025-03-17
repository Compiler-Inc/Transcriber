//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Speech

/// A basic configuration implementation for testing purposes
///
/// This configuration provides reasonable defaults for testing speech recognition
/// without requiring extensive customization. It can be used as a starting point
/// for more specific configurations.
public struct TranscriberConfiguration: Sendable {
    /// The locale to use for speech recognition
    public let locale: Locale
    
    /// The RMS threshold below which audio is considered silence
    /// Values typically range from 0.0 to 1.0, with lower values being more sensitive
    /// Default silence threshold is very sensitive
    public let silenceThreshold: Float
    
    /// The duration of silence required to end recognition
    /// Specified in seconds (default 1.5)
    public let silenceDuration: TimeInterval
    
    
    public let languageModelInfo: LanguageModelInfo?
    
    /// Whether recognition must be performed on-device
    /// Note: This is automatically set to true when using a custom model
    /// Default to allowing server-side recognition
    public let requiresOnDeviceRecognition: Bool
    
    /// Whether to return partial recognition results as they become available
    /// Default to providing partial results for better user experience
    public let shouldReportPartialResults: Bool
    
    /// Optional array of strings that should be recognized even if not in system vocabulary
    /// Useful for domain-specific terms or proper nouns
    /// No contextual strings by default
    public let contextualStrings: [String]?
    
    /// The type of speech recognition task being performed
    /// This helps the recognizer optimize for different types of speech
    /// Default to unspecified task hint, letting the recognizer decide
    public let taskHint: SFSpeechRecognitionTaskHint
    
    /// Whether to automatically add punctuation to recognition results
    /// Default to adding punctuation for better readability
    public let addsPunctuation: Bool

    /// Creates a new TranscriberConfiguration with default values
    public init(
        locale: Locale = Locale(identifier: "en-US"),
        silenceThreshold: Float = 0.001,
        silenceDuration: TimeInterval = 1.5,
        languageModelInfo: LanguageModelInfo? = nil,
        requiresOnDeviceRecognition: Bool = false,
        shouldReportPartialResults: Bool = true,
        contextualStrings: [String]? = nil,
        taskHint: SFSpeechRecognitionTaskHint = .unspecified,
        addsPunctuation: Bool = true
    ) {
        self.locale = locale
        self.silenceThreshold = silenceThreshold
        self.silenceDuration = silenceDuration
        self.languageModelInfo = languageModelInfo
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.shouldReportPartialResults = shouldReportPartialResults
        self.contextualStrings = contextualStrings
        self.taskHint = taskHint
        self.addsPunctuation = addsPunctuation
    }
}
