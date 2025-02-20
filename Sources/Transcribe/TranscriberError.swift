//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Foundation
import Speech

/// Errors that can occur during speech recognition operations
public enum TranscriberError: LocalizedError {
    /// Speech recognition authorization was denied or restricted
    case notAuthorized
    /// No speech recognizer available for the specified locale
    case noRecognizer
    /// Audio engine encountered an error during operation
    case engineFailure(Error)
    /// Recognition task encountered an error
    case recognitionFailure(Error)
    /// Custom language model failed to load or prepare
    case customModelFailure(Error)
    /// Audio session setup failed (iOS only)
    case audioSessionFailure(Error)
    /// Recognition request could not be created or configured
    case invalidRequest
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .noRecognizer:
            return "Speech recognizer not available for current locale"
        case .engineFailure(let error):
            return "Audio engine error: \(error.localizedDescription)"
        case .recognitionFailure(let error):
            return "Recognition error: \(error.localizedDescription)"
        case .customModelFailure(let error):
            return "Custom model error: \(error.localizedDescription)"
        case .audioSessionFailure(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid recognition request configuration"
        }
    }
} 
