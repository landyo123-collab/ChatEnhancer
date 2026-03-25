import Cocoa
import WebKit

extension AppDelegate {
    @objc func toggleArchiveMode(_ sender: Any?) {
        archiveModeEnabled.toggle()

        if archiveModeEnabled {
            Perf.event("ArchiveModeEnabled")
            enableArchiveMode()
        } else {
            Perf.event("ArchiveModeDisabled")
            archiveArmNonce += 1
            disableArchiveMode()
            restoreArchivedTurnsBestEffort()
            markArchiveOffForSession()
        }

        updateToolbarItem(Self.archiveItem)
        updateArchiveMenuItem()
        updateWindowTitleHealth()
    }

    func archiveModeStateLabel() -> String {
        guard archiveModeEnabled else { return "Off" }
        switch archiveTelemetry.runtimeState {
        case "fallback": return "Fallback"
        case "degraded": return "Degraded"
        default: return "On"
        }
    }

    func updateArchiveMenuItem() {
        guard let item = findMenuItem(withAction: #selector(toggleArchiveMode(_:))) else { return }
        item.title = "Archive Mode: \(archiveModeStateLabel())"
        item.state = archiveModeEnabled ? .on : .off
        item.toolTip = "Archive Mode state: \(archiveModeStateLabel())"
    }

    private func findMenuItem(withAction action: Selector) -> NSMenuItem? {
        func search(_ menu: NSMenu?) -> NSMenuItem? {
            guard let menu else { return nil }
            for item in menu.items {
                if item.action == action { return item }
                if let found = search(item.submenu) { return found }
            }
            return nil
        }
        return search(NSApp.mainMenu)
    }

    private func markArchiveOffForSession() {
        archiveTelemetry.archiveEnabled = false
        archiveTelemetry.runtimeFallback = false
        archiveTelemetry.runtimeDisabled = false
        archiveTelemetry.runtimeState = "waiting"
        archiveTelemetry.reasonCode = "disabled_by_user"
        archiveTelemetry.runtimeDisableReason = "disabled_by_user"
        archiveTelemetry.lastPassAt = 0
        archiveTelemetry.lastArchivedThisPass = 0
        archiveTelemetry.passInFlight = false
        archiveTelemetry.source = "archiveToggleOff"
        archiveTelemetry.updatedAt = Date()
    }

    func restoreArchivedTurnsBestEffort() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.restoreArchivedTurns) { [weak self] result, _ in
            guard let self else { return }
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let telemetry = info["telemetry"] as? [String: Any] {
                self.ingestArchiveTelemetry(telemetry, source: "restoreArchivedTurns")
            }
        }
    }

    func enableArchiveMode() {
        guard let wv = webView else { return }
        archiveArmNonce += 1
        let nonce = archiveArmNonce

        wv.evaluateJavaScript(JS.archiveRuntime) { [weak self] _, _ in
            guard let self else { return }
            guard self.archiveModeEnabled, self.archiveArmNonce == nonce else { return }
            guard let wv = self.webView else { return }

            wv.evaluateJavaScript(JS.enableArchiveMode) { [weak self] result, error in
                guard let self else { return }
                guard self.archiveModeEnabled, self.archiveArmNonce == nonce else { return }
                guard error == nil else {
                    Perf.event("ArchiveModeEnableFailed")
                    self.archiveModeEnabled = false
                    self.updateToolbarItem(Self.archiveItem)
                    self.updateArchiveMenuItem()
                    return
                }
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                if let telemetry = info["telemetry"] as? [String: Any] {
                    self.ingestArchiveTelemetry(telemetry, source: "enableArchiveMode")
                } else {
                    self.ingestArchiveTelemetry(info, source: "enableArchiveMode")
                }
                self.scheduleArchiveArmPasses(nonce: nonce)
                self.updateToolbarItem(Self.archiveItem)
                self.updateArchiveMenuItem()
            }
        }
    }

    func disableArchiveMode() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.disableArchiveMode) { [weak self] result, _ in
            guard let self else { return }
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let telemetry = info["telemetry"] as? [String: Any] {
                self.ingestArchiveTelemetry(telemetry, source: "disableArchiveMode")
            } else {
                self.ingestArchiveTelemetry(info, source: "disableArchiveMode")
            }
            self.updateToolbarItem(Self.archiveItem)
            self.updateArchiveMenuItem()
        }
    }

    func runArchivePassNow() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.runArchivePassNow) { [weak self] result, error in
            guard let self else { return }
            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let telemetry = info["telemetry"] as? [String: Any] {
                self.ingestArchiveTelemetry(telemetry, source: "runArchivePassNow")
            } else {
                self.ingestArchiveTelemetry(info, source: "runArchivePassNow")
            }
            self.updateToolbarItem(Self.archiveItem)
            self.updateArchiveMenuItem()
        }
    }

    private func scheduleArchiveArmPasses(nonce: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            guard self.archiveModeEnabled, self.archiveArmNonce == nonce else { return }
            self.runArchivePassNow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            guard self.archiveModeEnabled, self.archiveArmNonce == nonce else { return }
            if self.archiveTelemetry.totalTurns >= 6, self.archiveTelemetry.archivedTurns == 0, self.archiveTelemetry.runtimeState != "disabled_by_user" {
                self.runArchivePassNow()
            }
        }
    }
}
