//  Copyright © 2025 Compiler, Inc. All rights reserved.

import Accelerate
import AVFoundation

extension AVAudioPCMBuffer {
    /// Calculates the Root Mean Square (RMS) of the audio buffer's samples
    ///
    /// This method efficiently computes the RMS value using Apple's Accelerate framework,
    /// which provides high-performance vector-based calculations. The implementation:
    /// 1. Squares all samples using vDSP_vsq
    /// 2. Sums the squared values using vDSP_sve
    /// 3. Averages across all channels
    /// 4. Takes the square root for final RMS value
    ///
    /// Performance considerations:
    /// - Uses Accelerate's SIMD operations for vectorized math
    /// - Processes all channels in parallel
    /// - Minimizes memory allocation by reusing a temporary buffer
    /// - Significantly faster than manual loop-based calculation
    ///
    /// - Returns: A Float value between 0 and 1 representing the RMS power of the audio
    ///           Returns 0 if the buffer has no valid channel data
    func calculateRMS() -> Float {
        guard let channelData = self.floatChannelData else { return 0 }
        let channelCount = Int(self.format.channelCount)
        let frameLength = Int(self.frameLength)
        var squareSum: Float = 0
        
        // Create temporary buffer for vectorized calculations
        var tempBuffer = [Float](repeating: 0, count: frameLength)
        
        for channel in 0..<channelCount {
            var localSum: Float = 0
            // vDSP_vsq: Vector square - squares each sample in place
            vDSP_vsq(channelData[channel], 1, &tempBuffer, 1, vDSP_Length(frameLength))
            // vDSP_sve: Vector sum - sums all squared values
            vDSP_sve(&tempBuffer, 1, &localSum, vDSP_Length(frameLength))
            squareSum += localSum
        }
        
        // Average across all samples and channels, then take square root
        let avgSquare = squareSum / Float(frameLength * channelCount)
        return sqrt(avgSquare)
    }
}
