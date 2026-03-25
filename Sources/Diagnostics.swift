import Foundation
import os.log
import os.signpost

enum Perf {
    static let log = OSLog(subsystem: "com.webapps.chatgpt", category: "Perf")
    static let signpostID = OSSignpostID(log: log)

    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name, signpostID: signpostID)
    }
    static func begin(_ name: StaticString) {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
    }
    static func end(_ name: StaticString) {
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
}

enum ThreadHealthLevel: Int, Comparable {
    case healthy = 0
    case gettingHeavy = 1
    case heavy = 2

    static func < (lhs: ThreadHealthLevel, rhs: ThreadHealthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .gettingHeavy: return "Getting Heavy"
        case .heavy: return "Heavy"
        }
    }

    var symbolName: String {
        switch self {
        case .healthy: return "heart"
        case .gettingHeavy: return "exclamationmark.triangle"
        case .heavy: return "exclamationmark.triangle.fill"
        }
    }
}

enum Prefs {
    private static let perfKey = "ChatGPT_PerformanceMode"
    private static let projectContinueKey = "ChatGPT_ProjectAwareContinuationEnabled"
    private static let projectContinueAttemptKey = "ChatGPT_ProjectAwareContinuationAttempt"
    private static let projectContinueValidateKey = "ChatGPT_ProjectAwareContinuationValidate"
    private static let projectContinueForceFallbackKey = "ChatGPT_ProjectAwareContinuationForceFallback"
    private static let projectContinueMinScoreKey = "ChatGPT_ProjectAwareContinuationMinScore"

    static var performanceModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: perfKey) }
        set { UserDefaults.standard.set(newValue, forKey: perfKey) }
    }

    // Project-aware continuation is on by default; can be killed via defaults.
    static var projectAwareContinuationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: projectContinueKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: projectContinueKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: projectContinueKey) }
    }

    static var projectAwareContinuationValidationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: projectContinueValidateKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: projectContinueValidateKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: projectContinueValidateKey) }
    }

    static var projectAwareContinuationAttemptEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: projectContinueAttemptKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: projectContinueAttemptKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: projectContinueAttemptKey) }
    }

    // Debug / test hook to force the non-project fallback path.
    static var projectAwareContinuationForceFallback: Bool {
        get { UserDefaults.standard.bool(forKey: projectContinueForceFallbackKey) }
        set { UserDefaults.standard.set(newValue, forKey: projectContinueForceFallbackKey) }
    }

    // Minimum score required to attempt same-project continuation.
    // Default aligns with a strong URL-derived project identifier signal.
    static var projectAwareContinuationMinScore: Double {
        get {
            let v = UserDefaults.standard.double(forKey: projectContinueMinScoreKey)
            return v > 0 ? v : 0.85
        }
        set { UserDefaults.standard.set(newValue, forKey: projectContinueMinScoreKey) }
    }
}
