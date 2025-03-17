//  Copyright © 2025 Compiler, Inc. All rights reserved.

import OSLog

extension Logger {
    private static let subsystem = "CompilerSwiftAI"
    
    /// Logs related to speech recognition operations and events
    static let transcriber = Logger(subsystem: subsystem, category: "transcriber")
}

/// A wrapper around Logger that handles debug mode checks
struct DebugLogger {
    private let logger: Logger
    private let isEnabled: Bool
    
    init(_ logger: Logger, isEnabled: Bool) {
        self.logger = logger
        self.isEnabled = isEnabled
    }
    
    func debug(_ message: @escaping @autoclosure () -> String) {
        guard isEnabled else { return }
        logger.debug("\(message())")
    }
    
    func error(_ message: @escaping @autoclosure () -> String) {
        // Always log errors, regardless of debug mode
        logger.error("\(message())")
    }
} 
