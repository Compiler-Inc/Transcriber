import SwiftUI
import Combine

/// State of the speech button UI
///
/// The button can be in one of three states:
/// - `idle`: Initial state, ready to start recording
/// - `listening`: Actively recording and showing audio waveform visualization
/// - `thinking`: Optional state for when audio is being processed (e.g., by an LLM)
public enum SpeechButtonState {
    case idle
    case listening
    case thinking
}

/// Color configuration for the different states of the speech button
public struct SpeechButtonColors {
    /// Color when the button is in idle state (default: blue)
    public let idle: Color
    /// Color when the button is actively listening (default: red)
    public let listening: Color
    /// Color when the button is in thinking state (default: green)
    public let thinking: Color
    
    /// Initialize with custom colors for each state
    /// - Parameters:
    ///   - idle: Color for idle state
    ///   - listening: Color for listening state
    ///   - thinking: Color for thinking state
    public init(
        idle: Color = Color.blue,
        listening: Color = Color.red,
        thinking: Color = Color.green
    ) {
        self.idle = idle
        self.listening = listening
        self.thinking = thinking
    }
}

/// A customizable button that provides visual feedback for speech recognition states
///
/// This button provides three distinct visual states:
/// 1. Idle: Shows a microphone icon, ready to start recording
/// 2. Listening: Displays an animated waveform visualization of the audio input
/// 3. Thinking: Shows a progress spinner for async processing (optional)
///
/// Example usage:
/// ```swift
/// SpeechButton(
///     isRecording: $isRecording,
///     rmsValue: rmsValue,
///     isProcessing: isProcessingByLLM,
///     supportsThinkingState: true,
///     colors: SpeechButtonColors(
///         idle: .blue,
///         listening: .red,
///         thinking: .green
///     )
/// ) {
///     // Handle tap
///     toggleRecording()
/// }
/// ```
public struct SpeechButton: View {
    // MARK: - Public Properties
    
    /// Whether the button is currently recording
    public var isRecording: Bool
    /// Current RMS (Root Mean Square) value for audio visualization
    public var rmsValue: Float
    /// Whether an async operation is processing the audio
    public var isProcessing: Bool
    /// Whether to show the thinking state (spinner) during processing
    public var supportsThinkingState: Bool = false
    /// Color configuration for the different button states
    public var colors: SpeechButtonColors = SpeechButtonColors()
    /// Callback when the button is tapped
    public var onTap: () -> Void
    
    // MARK: - Private State
    @State private var state: SpeechButtonState = .idle
    @State private var amplitudes: [CGFloat] = Array(repeating: 0, count: 10)
    @State private var animationTimer: AnyCancellable?
    
    public init(isRecording: Bool, rmsValue: Float, isProcessing: Bool, supportsThinkingState: Bool = false, colors: SpeechButtonColors = SpeechButtonColors(), onTap: @escaping () -> Void) {
        self.isRecording = isRecording
        self.rmsValue = rmsValue
        self.isProcessing = isProcessing
        self.supportsThinkingState = supportsThinkingState
        self.colors = colors
        self.onTap = onTap
    }
    
    // MARK: - View Body
    public var body: some View {
        ZStack {
            // Base Circle Button
            Circle()
                .fill(buttonColor)
                .frame(width: 50, height: 50)
                .shadow(radius: 5)
            
            // Different content based on state
            switch state {
            case .idle:
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            
            case .listening:
                // Waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<amplitudes.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 2, height: 6 + amplitudes[index] * 30)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: amplitudes[index])
                    }
                }
                
            case .thinking:
                // Thinking animation
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.0)
            }
        }
        .onTapGesture {
            onTap()
        }
        .onChange(of: isRecording) { newIsRecording in
            updateState(isRecording: newIsRecording, isProcessing: isProcessing)
        }
        .onChange(of: isProcessing) { newIsProcessing in
            updateState(isRecording: isRecording, isProcessing: newIsProcessing)
        }
        .onChange(of: rmsValue) { newRMS in
            updateAmplitudes(with: newRMS)
        }
        .onAppear {
            // Start a timer to add small jitter to the waveform when listening
            animationTimer = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    guard state == .listening else { return }
                    addJitter()
                }
            
            // Initialize state based on current props
            updateState(isRecording: isRecording, isProcessing: isProcessing)
        }
        .onDisappear {
            animationTimer?.cancel()
            animationTimer = nil
        }
    }
    
    private var buttonColor: Color {
        switch state {
        case .idle:
            return colors.idle
        case .listening:
            return colors.listening
        case .thinking:
            return colors.thinking
        }
    }
    
    // MARK: - Private Methods
    
    /// Updates the button's state based on recording and processing status
    /// - Parameters:
    ///   - isRecording: Whether audio is being recorded
    ///   - isProcessing: Whether audio is being processed
    private func updateState(isRecording: Bool, isProcessing: Bool) {
        if isRecording {
            state = .listening
        } else if isProcessing && supportsThinkingState {
            state = .thinking
        } else {
            state = .idle
        }
    }
    
    /// Updates the waveform visualization with new audio level data
    /// - Parameter rms: Root Mean Square value of the audio input (0.0-1.0)
    private func updateAmplitudes(with rms: Float) {
        // Only update amplitudes when in listening state
        guard state == .listening else { return }
        
        // Shift amplitudes to the left
        for i in 0..<(amplitudes.count - 1) {
            amplitudes[i] = amplitudes[i + 1]
        }
        
        // Add new amplitude at the end with more dramatic normalization
        // Apply a power function to exaggerate differences
        // First scale the RMS value to a reasonable base range
        let scaledRMS = min(max(rms * 10, 0.01), 1.0)
        
        // Apply a power function to exaggerate differences (values^0.4 will enhance smaller values)
        let exaggeratedRMS = pow(scaledRMS, 0.4)
        
        // Add some randomness to make it more lively (±15% variation)
        let randomFactor = Float.random(in: 0.85...1.15)
        let finalRMS = min(exaggeratedRMS * randomFactor, 1.0)
        
        amplitudes[amplitudes.count - 1] = CGFloat(finalRMS)
    }
    
    /// Adds small random variations to the waveform to make it look more dynamic
    private func addJitter() {
        // Add small random variations to make the waveform look more alive
        for i in 0..<amplitudes.count {
            // Add a small jitter (±5%) to each amplitude
            let jitter = CGFloat.random(in: 0.95...1.05)
            amplitudes[i] = min(max(amplitudes[i] * jitter, 0.05), 1.0)
        }
    }
}

// MARK: - Preview Provider
struct SpeechButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Idle state
            SpeechButton(
                isRecording: false,
                rmsValue: 0,
                isProcessing: false,
                onTap: {}
            )
            
            // Recording state
            SpeechButton(
                isRecording: true,
                rmsValue: 0.5,
                isProcessing: false,
                onTap: {}
            )
            
            // Thinking state
            SpeechButton(
                isRecording: false,
                rmsValue: 0,
                isProcessing: true,
                supportsThinkingState: true,
                onTap: {}
            )
        }
        .padding()
    }
}
