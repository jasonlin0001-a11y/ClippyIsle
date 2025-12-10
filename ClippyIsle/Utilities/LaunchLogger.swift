//
//  LaunchLogger.swift
//  ClippyIsle
//
//  Created for iOS Performance Launch Audit
//  Helps identify launch bottlenecks by tracking time elapsed since app start
//

import Foundation

/// Helper class to log launch timing for performance debugging.
/// Call `LaunchLogger.log("step name")` at key points during app launch to track timing.
class LaunchLogger {
    /// The timestamp when the app process started (approximated by first LaunchLogger access)
    private static let appStartTime: CFAbsoluteTime = {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🚀 LaunchLogger: App start time initialized at \(startTime)")
        return startTime
    }()
    
    /// Logs a step with the time elapsed since app start in milliseconds
    /// - Parameter step: A descriptive name for the step being logged
    static func log(_ step: String) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedMs = (currentTime - appStartTime) * 1000.0
        print(String(format: "⏱️ [+%.0f ms] %@", elapsedMs, step))
    }
}
