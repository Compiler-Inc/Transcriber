//  Copyright 2025 Compiler, Inc. All rights reserved.

#if os(iOS)
import AVFoundation

/// Utilities for managing iOS audio input selection
public enum AudioInputs {
    /// Get all available audio inputs
    public static func getAvailableInputs() -> [AVAudioSessionPortDescription] {
        return AVAudioSession.sharedInstance().availableInputs ?? []
    }
    
    /// Select a specific audio input
    /// - Parameters:
    ///   - input: The audio input to select
    ///   - reactivateSession: Whether to reactivate the audio session after selection (default: true)
    /// - Throws: AVAudioSession errors if selection fails
    /// - Note: Caller is responsible for proper audio session configuration
    public static func selectInput(
        _ input: AVAudioSessionPortDescription,
        reactivateSession: Bool = true
    ) throws {
        try AVAudioSession.sharedInstance().setPreferredInput(input)
        
        // Configure data source if available
        if let dataSources = input.dataSources,
           let firstSource = dataSources.first {
            try input.setPreferredDataSource(firstSource)
        }
        
        // Optionally reactivate session
        if reactivateSession {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
            try session.setActive(true)
        }
    }
    
    /// Get details about an audio input
    /// - Parameter input: The audio input to inspect
    /// - Returns: Dictionary of input properties including name, port type, and data sources
    public static func getInputDetails(_ input: AVAudioSessionPortDescription) -> [String: Any] {
        var details: [String: Any] = [
            "name": input.portName,
            "type": input.portType.rawValue
        ]
        
        if let dataSources = input.dataSources {
            details["dataSources"] = dataSources.map { ["name": $0.dataSourceName] }
        }
        
        return details
    }
}
#endif

