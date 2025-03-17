import Foundation

/// Signal types emitted by the Transcriber's unified stream
///
/// This enum represents the two types of data that can be emitted by the Transcriber:
/// - Audio level data (RMS values) for visualizing microphone input
/// - Transcription text from speech recognition
///
/// Use with `startStream()` to receive both types of data in a single stream.
public enum TranscriberSignal: Sendable {
    /// An audio level measurement (Root Mean Square)
    /// - Parameter Float: A value between 0.0 and 1.0 representing the audio level
    case rms(Float)
    
    /// A transcription result from speech recognition
    /// - Parameter String: The transcribed text
    case transcription(String)
}
