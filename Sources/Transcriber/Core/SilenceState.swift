import Foundation

extension Transcriber {
    fileprivate struct SilenceState {
        var isSilent: Bool = false
        var startTime: CFAbsoluteTime = 0
        var hasEnded: Bool = false
        
        mutating func update(rms: Float, currentTime: CFAbsoluteTime, threshold: Float, duration: TimeInterval) -> Bool {
            if rms < threshold {
                if !isSilent {
                    isSilent = true
                    startTime = currentTime
                } else if !hasEnded && (currentTime - startTime) >= duration {
                    hasEnded = true
                    return true
                }
            } else {
                isSilent = false
            }
            return false
        }
    }
}
