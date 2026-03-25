import Cocoa
import WebKit

extension AppDelegate {
    func startHealthMonitor() {
        guard healthTimer == nil else { return }
        Perf.event("HealthMonitorStarted")

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 4.0, repeating: .seconds(12))
        timer.setEventHandler { [weak self] in self?.healthCheckTick() }
        healthTimer = timer
        timer.resume()
    }

    func stopHealthMonitor() {
        guard let timer = healthTimer else { return }
        timer.cancel()
        healthTimer = nil
        healthCheckInFlight = false
        Perf.event("HealthMonitorStopped")
    }

    func ingestArchiveTelemetry(_ payload: [String: Any], source: String) {
        var merged: [String: Any] = [
            "totalTurns": archiveTelemetry.totalTurns,
            "liveTurns": archiveTelemetry.liveTurns,
            "archivedTurns": archiveTelemetry.archivedTurns,
            "archivedShells": archiveTelemetry.archivedShells,
            "selectorMethod": archiveTelemetry.selectorMethod,
            "selectorDegraded": archiveTelemetry.selectorDegraded,
            "lastPassDurationMs": archiveTelemetry.lastPassDurationMs,
            "lastPassAt": archiveTelemetry.lastPassAt,
            "lastArchivedThisPass": archiveTelemetry.lastArchivedThisPass,
            "passInFlight": archiveTelemetry.passInFlight,
            "archiveEnabled": archiveTelemetry.archiveEnabled,
            "runtimeAvailable": archiveTelemetry.runtimeAvailable,
            "runtimeFallback": archiveTelemetry.runtimeFallback,
            "runtimeDisabled": archiveTelemetry.runtimeDisabled,
            "runtimeState": archiveTelemetry.runtimeState,
            "reasonCode": archiveTelemetry.reasonCode as Any,
            "runtimeDisableReason": archiveTelemetry.runtimeDisableReason as Any,
            "startupGraceActive": archiveTelemetry.startupGraceActive,
            "pageReadyConfirmed": archiveTelemetry.pageReadyConfirmed,
            "hasComposer": archiveTelemetry.hasComposer,
            "scrollHeight": archiveTelemetry.scrollHeight,
            "hasMain": archiveTelemetry.hasMain
        ]
        for (k, v) in payload { merged[k] = v }

        archiveTelemetry = ArchiveTelemetrySnapshot.fromDictionary(merged, source: source)
        if archiveModeEnabled == false {
            archiveTelemetry.archiveEnabled = false
            archiveTelemetry.runtimeFallback = false
            archiveTelemetry.runtimeDisabled = false
            archiveTelemetry.runtimeState = "waiting"
            archiveTelemetry.reasonCode = "archive_off"
            archiveTelemetry.runtimeDisableReason = nil
            archiveTelemetry.lastArchivedThisPass = 0
            archiveTelemetry.passInFlight = false
            archiveTelemetry.lastPassAt = 0
        }
        updateHealthSelectorFailures(from: archiveTelemetry)
        updateHealthState(from: archiveTelemetry, allowHeavyToast: false)
        updateToolbarItem(Self.archiveItem)
        updateArchiveMenuItem()
    }

    private func healthCheckTick() {
        if archiveTelemetry.runtimeAvailable, Date().timeIntervalSince(archiveTelemetry.updatedAt) < 18 {
            updateHealthSelectorFailures(from: archiveTelemetry)
            updateHealthState(from: archiveTelemetry, allowHeavyToast: true)
            return
        }
        guard let wv = webView, !healthCheckInFlight else { return }
        healthCheckInFlight = true

        wv.evaluateJavaScript(JS.healthCheck) { [weak self] result, error in
            guard let self else { return }
            self.healthCheckInFlight = false

            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            self.archiveTelemetry = ArchiveTelemetrySnapshot.fromDictionary(info, source: "healthCheckFallback")
            self.updateHealthSelectorFailures(from: self.archiveTelemetry)
            self.updateHealthState(from: self.archiveTelemetry, allowHeavyToast: true)
        }
    }

    private func updateHealthSelectorFailures(from snapshot: ArchiveTelemetrySnapshot) {
        if snapshot.reasonCode == "selector_degraded", snapshot.selectorDegraded, snapshot.hasMain {
            healthSelectorFailures += 1
        } else if snapshot.reasonCode == "startup_grace" || snapshot.reasonCode == "page_not_ready" || snapshot.reasonCode == "empty_chat" {
            healthSelectorFailures = 0
        } else if snapshot.selectorMethod != "unknown" {
            healthSelectorFailures = 0
        }
    }

    private func updateHealthState(from snapshot: ArchiveTelemetrySnapshot, allowHeavyToast: Bool) {
        var score = 0
        if snapshot.totalTurns > 24 { score += 1 }
        if snapshot.totalTurns > 48 { score += 1 }
        if snapshot.totalTurns > 96 { score += 1 }
        if snapshot.liveTurns > 8 { score += 1 }
        if snapshot.liveTurns > 14 { score += 2 }
        if snapshot.runtimeState == "degraded" { score += 1 }
        if snapshot.runtimeState == "fallback" { score += 3 }
        if snapshot.reasonCode == "selector_degraded" { score += 2 }
        if snapshot.runtimeFallback { score += 2 }
        if snapshot.runtimeDisabled { score += 2 }
        if !snapshot.runtimeAvailable && snapshot.runtimeState == "fallback" { score += 1 }
        if snapshot.scrollHeight > 140000 { score += 1 }
        if snapshot.scrollHeight > 260000 { score += 1 }
        if snapshot.lastPassDurationMs > 140 { score += 1 }
        if snapshot.lastPassDurationMs > 280 { score += 1 }
        if snapshot.archiveEnabled && snapshot.totalTurns > 36 && snapshot.archivedTurns == 0 { score += 1 }

        let newHealth: ThreadHealthLevel
        if score >= 6 { newHealth = .heavy }
        else if score >= 3 { newHealth = .gettingHeavy }
        else { newHealth = .healthy }

        let oldHealth = threadHealth
        if newHealth != threadHealth {
            threadHealth = newHealth
            switch newHealth {
            case .healthy: Perf.event("ThreadHealthHealthy")
            case .gettingHeavy: Perf.event("ThreadHealthGettingHeavy")
            case .heavy: Perf.event("ThreadHealthHeavy")
            }
        }

        updateToolbarItem(Self.healthItem)
        updateWindowTitleHealth()

        if allowHeavyToast, newHealth == .heavy, oldHealth < .heavy {
            if snapshot.runtimeState == "fallback" || snapshot.runtimeDisabled {
                showToast("Thread is heavy — archive runtime disabled itself for safety")
            } else if snapshot.archiveEnabled {
                showToast("Thread is heavy — archive mode is active, consider fresh continuation if needed")
            } else {
                showToast("Thread is heavy — consider continuing in a fresh chat (⌘⇧N)")
            }
        }
        if allowHeavyToast, newHealth == .heavy, snapshot.archiveEnabled,
           !snapshot.runtimeDisabled, snapshot.runtimeState != "fallback" {
            runArchivePassNow()
        }
    }

    func updateWindowTitleHealth() {
        guard let window else { return }
        var title = "ChatEnhancer"
        switch threadHealth {
        case .gettingHeavy: title += " — Getting Heavy"
        case .heavy: title += " — Heavy Thread"
        case .healthy: break
        }

        if archiveModeEnabled, archiveTelemetry.source != "none" {
            switch archiveTelemetry.runtimeState {
            case "waiting":
                title += " [archiver starting]"
            case "degraded":
                title += " [archiver degraded]"
            case "fallback":
                title += " [fallback]"
            case "active":
                if archiveTelemetry.archiveEnabled, archiveTelemetry.archivedTurns > 0 {
                    title += " [archived \(archiveTelemetry.archivedTurns)]"
                }
            default:
                break
            }
        } else if archiveTelemetry.source != "none", archiveTelemetry.archiveEnabled, archiveTelemetry.archivedTurns > 0 {
            title += " [archived \(archiveTelemetry.archivedTurns)]"
        }

        if healthSelectorFailures >= 3 { title += " [selectors degraded]" }
        window.title = title
    }

    @objc func showHealthDetails(_ sender: Any?) {
        func renderDialog(using snapshot: ArchiveTelemetrySnapshot) {
            var details = "Thread Health: \(threadHealth.label)\n\n"
            details += "Archive toggle: \(archiveModeEnabled ? "ON" : "OFF")\n"
            details += "Archive mode: \(snapshot.archiveEnabled ? "active" : "inactive")\n"
            details += "Archiver state: \(snapshot.runtimeState)\n"
            if let reason = snapshot.reasonCode, !reason.isEmpty {
                details += "Reason code: \(reason)\n"
            }
            details += "Turns: total \(snapshot.totalTurns), live \(snapshot.liveTurns), archived \(snapshot.archivedTurns)\n"
            details += "Archived shells: \(snapshot.archivedShells)\n"
            details += "Selector method: \(snapshot.selectorMethod)\n"
            details += "Selector degraded: \(snapshot.selectorDegraded)\n"
            details += "Runtime available: \(snapshot.runtimeAvailable)\n"
            details += "Runtime fallback: \(snapshot.runtimeFallback)\n"
            details += "Startup grace active: \(snapshot.startupGraceActive)\n"
            details += "Page ready confirmed: \(snapshot.pageReadyConfirmed)\n"
            details += "Composer detected: \(snapshot.hasComposer)\n"
            if snapshot.runtimeDisabled {
                details += "Runtime disabled: true"
                if let reason = snapshot.runtimeDisableReason, !reason.isEmpty {
                    details += " (\(reason))"
                }
                details += "\n"
            }
            details += "Last archive pass: \(snapshot.lastPassDurationMs) ms\n"
            details += "Archived this pass: \(snapshot.lastArchivedThisPass)\n"
            details += "Pass in flight: \(snapshot.passInFlight)\n"
            if snapshot.lastPassAt > 0 {
                let nowMs = Int(Date().timeIntervalSince1970 * 1000.0)
                let ageS = max(0, (nowMs - snapshot.lastPassAt) / 1000)
                details += "Last pass age: \(ageS)s\n"
            }
            details += "Scroll height: \(snapshot.scrollHeight)px\n"
            if healthSelectorFailures >= 3 {
                details += "⚠ Turn selectors degraded repeatedly — archiving may have backed off\n"
            }
            details += "\nThresholds (approximate):\n"
            details += "  Healthy: low live-turn pressure + stable selectors\n"
            details += "  Heavy: high live turns, degraded selectors, or fallback runtime\n"

            let alert = NSAlert()
            alert.messageText = "Thread Health"
            alert.informativeText = details
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            if threadHealth >= .gettingHeavy {
                alert.addButton(withTitle: "Continue in Fresh Chat")
            }
            if alert.runModal() == .alertSecondButtonReturn {
                continueInFreshChat(nil)
            }
        }

        if archiveTelemetry.source != "none", Date().timeIntervalSince(archiveTelemetry.updatedAt) < 8 {
            renderDialog(using: archiveTelemetry)
            return
        }

        guard let wv = webView else {
            renderDialog(using: archiveTelemetry)
            return
        }
        wv.evaluateJavaScript(JS.healthCheck) { [weak self] result, _ in
            guard let self else { return }
            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.archiveTelemetry = ArchiveTelemetrySnapshot.fromDictionary(info, source: "healthDetailsProbe")
            }
            renderDialog(using: self.archiveTelemetry)
        }
    }
}
