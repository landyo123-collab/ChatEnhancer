import Foundation

struct ArchiveTelemetrySnapshot {
    var totalTurns: Int
    var liveTurns: Int
    var archivedTurns: Int
    var archivedShells: Int
    var selectorMethod: String
    var selectorDegraded: Bool
    var lastPassDurationMs: Int
    var lastPassAt: Int
    var lastArchivedThisPass: Int
    var passInFlight: Bool
    var archiveEnabled: Bool
    var runtimeAvailable: Bool
    var runtimeFallback: Bool
    var runtimeDisabled: Bool
    var runtimeState: String
    var reasonCode: String?
    var runtimeDisableReason: String?
    var startupGraceActive: Bool
    var pageReadyConfirmed: Bool
    var hasComposer: Bool
    var scrollHeight: Int
    var hasMain: Bool
    var source: String
    var updatedAt: Date

    static var empty: ArchiveTelemetrySnapshot {
        ArchiveTelemetrySnapshot(
            totalTurns: 0,
            liveTurns: 0,
            archivedTurns: 0,
            archivedShells: 0,
            selectorMethod: "unknown",
            selectorDegraded: false,
            lastPassDurationMs: 0,
            lastPassAt: 0,
            lastArchivedThisPass: 0,
            passInFlight: false,
            archiveEnabled: false,
            runtimeAvailable: false,
            runtimeFallback: false,
            runtimeDisabled: false,
            runtimeState: "waiting",
            reasonCode: nil,
            runtimeDisableReason: nil,
            startupGraceActive: false,
            pageReadyConfirmed: false,
            hasComposer: false,
            scrollHeight: 0,
            hasMain: false,
            source: "none",
            updatedAt: .distantPast
        )
    }

    static func fromDictionary(_ info: [String: Any], source: String, now: Date = Date()) -> ArchiveTelemetrySnapshot {
        let totalTurns = intValue(info["totalTurns"] ?? info["turns"])
        let archivedTurns = intValue(info["archivedTurns"])
        let computedLive = max(totalTurns - archivedTurns, 0)
        var liveTurns = intValue(info["liveTurns"])
        if liveTurns == 0 && totalTurns > 0 && archivedTurns <= totalTurns {
            liveTurns = computedLive
        }

        let enabled = boolValue(info["archiveEnabled"] ?? info["enabled"])
        let runtimeAvailable = boolValue(info["runtimeAvailable"] ?? info["hasRuntime"]) || enabled
        let runtimeDisabled = boolValue(info["runtimeDisabled"])
        let fallbackFlag = boolValue(info["runtimeFallback"])
        let lastPassAt = intValue(info["lastPassAtMs"] ?? info["lastPassAt"])
        let lastArchivedThisPass = intValue(info["lastArchivedThisPass"])
        let passInFlight = boolValue(info["passInFlight"])
        let runtimeState = normalizeState(
            raw: info["runtimeState"],
            enabled: enabled,
            runtimeDisabled: runtimeDisabled,
            fallbackFlag: fallbackFlag
        )
        let runtimeFallback = boolValue(info["runtimeFallback"] ?? (runtimeState == "fallback" || runtimeDisabled))
        let reasonCode = nonEmptyString(info["reasonCode"] as? String ?? info["runtimeDisableReason"] as? String ?? info["disableReason"] as? String)

        return ArchiveTelemetrySnapshot(
            totalTurns: totalTurns,
            liveTurns: max(liveTurns, 0),
            archivedTurns: max(archivedTurns, 0),
            archivedShells: max(intValue(info["archivedShells"] ?? info["shells"]), 0),
            selectorMethod: stringValue(info["selectorMethod"], fallback: "unknown"),
            selectorDegraded: boolValue(info["selectorDegraded"]),
            lastPassDurationMs: max(intValue(info["lastPassDurationMs"] ?? info["passDurationMs"]), 0),
            lastPassAt: max(lastPassAt, 0),
            lastArchivedThisPass: max(lastArchivedThisPass, 0),
            passInFlight: passInFlight,
            archiveEnabled: enabled,
            runtimeAvailable: runtimeAvailable,
            runtimeFallback: runtimeFallback,
            runtimeDisabled: runtimeDisabled,
            runtimeState: runtimeState,
            reasonCode: reasonCode,
            runtimeDisableReason: info["runtimeDisableReason"] as? String ?? info["disableReason"] as? String,
            startupGraceActive: boolValue(info["startupGraceActive"]),
            pageReadyConfirmed: boolValue(info["pageReadyConfirmed"]),
            hasComposer: boolValue(info["hasComposer"]),
            scrollHeight: max(intValue(info["scrollHeight"]), 0),
            hasMain: boolValue(info["hasMain"]),
            source: source,
            updatedAt: now
        )
    }

    private static func intValue(_ raw: Any?) -> Int {
        if let n = raw as? NSNumber { return n.intValue }
        if let i = raw as? Int { return i }
        if let s = raw as? String, let v = Int(s) { return v }
        return 0
    }

    private static func boolValue(_ raw: Any?) -> Bool {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            let v = s.lowercased()
            return v == "1" || v == "true" || v == "yes"
        }
        return false
    }

    private static func stringValue(_ raw: Any?, fallback: String) -> String {
        if let s = raw as? String, !s.isEmpty { return s }
        return fallback
    }

    private static func nonEmptyString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizeState(raw: Any?, enabled: Bool, runtimeDisabled: Bool, fallbackFlag: Bool) -> String {
        let candidate = (raw as? String)?.lowercased() ?? ""
        switch candidate {
        case "waiting", "active", "degraded", "fallback":
            return candidate
        default:
            if runtimeDisabled || fallbackFlag { return "fallback" }
            if enabled { return "active" }
            return "waiting"
        }
    }
}
