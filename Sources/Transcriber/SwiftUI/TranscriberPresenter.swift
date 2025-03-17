//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Speech
import Foundation

/// Protocol defining the requirements for a speech recognition view model
///
/// This protocol provides a standard interface for view models that manage speech recognition state
/// and operations. It defines the minimum set of properties and methods needed to integrate
/// speech recognition into a SwiftUI view. See demo for example usage
///
@preconcurrency
@MainActor
public protocol TranscriberPresenter {
    // MARK: - Required State Properties
    
    /// Indicates whether speech recognition is currently active
    var isRecording: Bool { get set }
    
    /// The current transcribed text from speech recognition
    /// This may be partial results if configured in the service
    var transcribedText: String { get set }
    
    /// The current authorization status for speech recognition
    /// Should be updated after calling requestAuthorization()
    var authStatus: SFSpeechRecognizerAuthorizationStatus { get set }
    
    /// Any error that occurred during speech recognition
    /// Should be displayed to the user in the view
    var error: Error? { get set }
    
    /// Audio level for visualization (0.0 - 1.0)
    var rmsLevel: Float { get set }
    
    // MARK: - Required Methods
    
    /// Start/stop recording with optional completion handler
    /// - Parameter onComplete: Handler called when recording stops (silence or manual)
    /// This method should:
    /// 1. Handle the case where transcriber is nil
    /// 2. Cancel any existing recording if isRecording is true
    /// 3. Start a new recording if isRecording is false
    /// 4. Update isRecording status appropriately
    /// 5. Handle any errors by setting the error property
    func toggleRecording(onComplete: ((String) -> Void)?)

    
    /// Request authorization for speech recognition
    /// - Throws: TranscriberError if authorization fails or transcriber is nil
    ///
    /// Recommended implementation:
    /// ```swift
    /// func requestAuthorization() async throws {
    ///     guard let transcriber else {
    ///         throw TranscribernError.noRecognizer
    ///     }
    ///     authStatus = await transcriber.requestAuthorization()
    ///     guard authStatus == .authorized else {
    ///         throw TranscriberError.notAuthorized
    ///     }
    /// }
    /// ```
    func requestAuthorization() async throws
} 
