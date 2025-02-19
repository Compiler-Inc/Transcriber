//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Foundation
import Speech

/// A model for configuring custom language models in speech recognition
public struct CustomModel: Sendable {
    /// The URL to the custom language model file
    public let url: URL
    /// Optional version identifier for the model, useful for tracking different model versions
    public let version: String?
    
    /// Initialize a new custom model configuration
    /// - Parameters:
    ///   - url: The URL to the custom language model file
    ///   - version: Optional version identifier for the model
    public init(url: URL, version: String? = nil) {
        self.url = url
        self.version = version
    }
}

/// Protocol defining the configuration options for speech recognition
///
/// This protocol provides a comprehensive set of configuration options for speech recognition,
/// including both core settings and recognition request settings. Default implementations
/// are provided for most properties to allow for minimal configuration when using standard settings.
@preconcurrency public protocol SpeechRecognitionConfiguration: Sendable {
    // MARK: - Core Settings
    
    /// The locale to use for speech recognition
    var locale: Locale { get }
    
    /// The RMS threshold below which audio is considered silence
    /// Values typically range from 0.0 to 1.0, with lower values being more sensitive
    var silenceThreshold: Float { get }
    
    /// The duration of silence required to end recognition
    /// Specified in seconds
    var silenceDuration: TimeInterval { get }
    
    /// A unique identifier for your app, used for custom model management
    var appIdentifier: String { get }
    
    /// Optional custom language model configuration
    var customModel: CustomModel? { get }
    
    // MARK: - Recognition Request Settings
    
    /// Whether recognition must be performed on-device
    /// Note: This is automatically set to true when using a custom model
    var requiresOnDeviceRecognition: Bool { get }
    
    /// Whether to return partial recognition results as they become available
    var shouldReportPartialResults: Bool { get }
    
    /// Optional array of strings that should be recognized even if not in system vocabulary
    /// Useful for domain-specific terms or proper nouns
    var contextualStrings: [String]? { get }
    
    /// The type of speech recognition task being performed
    /// This helps the recognizer optimize for different types of speech
    var taskHint: SFSpeechRecognitionTaskHint { get }
    
    /// Whether to automatically add punctuation to recognition results
    var addsPunctuation: Bool { get }
}

// MARK: - Default Implementations

public extension SpeechRecognitionConfiguration {
    /// Default locale is US English
    var locale: Locale { Locale(identifier: "en-US") }
    
    /// Default silence threshold is very sensitive
    var silenceThreshold: Float { 0.001 }
    
    /// Default silence duration is 1.5 seconds
    var silenceDuration: TimeInterval { 1.5 }
    
    /// Default to allowing server-side recognition
    var requiresOnDeviceRecognition: Bool { false }
    
    /// Default to providing partial results for better user experience
    var shouldReportPartialResults: Bool { true }
    
    /// No contextual strings by default
    var contextualStrings: [String]? { nil }
    
    /// Default to unspecified task hint, letting the recognizer decide
    var taskHint: SFSpeechRecognitionTaskHint { .unspecified }
    
    /// Default to adding punctuation for better readability
    var addsPunctuation: Bool { true }
}

/// A basic configuration implementation for testing purposes
///
/// This configuration provides reasonable defaults for testing speech recognition
/// without requiring extensive customization. It can be used as a starting point
/// for more specific configurations.
public struct DefaultSpeechConfig: SpeechRecognitionConfiguration {
    public let appIdentifier = "com.test.speech"
    public var silenceThreshold: Float = 0.001
    public var silenceDuration: TimeInterval = 2.0
    public var customModel: CustomModel? = nil
    
    // Only override defaults if needed for testing
    public var requiresOnDeviceRecognition: Bool = false
    public var shouldReportPartialResults: Bool = true
    public var contextualStrings: [String]? = nil
    public var taskHint: SFSpeechRecognitionTaskHint = .unspecified
    public var addsPunctuation: Bool = true
    
    public init() {}
}
