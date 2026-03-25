import Cocoa
import WebKit

extension AppDelegate {
    @objc func showDiagnostics(_ sender: Any?) {
        guard let wv = webView else {
            let a = NSAlert()
            a.messageText = "Feature Diagnostics"
            a.informativeText = "No WebView loaded."
            a.runModal()
            return
        }

        wv.evaluateJavaScript(JS.featureProbe) { [weak self] result, error in
            guard let self else { return }

            var text = "Feature Probe Results\n"
            text += String(repeating: "─", count: 30) + "\n\n"

            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let r = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let turnMethod = r["turnMethod"] as? String ?? "unknown"
                let editorMethod = r["editorMethod"] as? String ?? "unknown"
                let turnsPrimary = r["turnsPrimary"] as? Int ?? 0
                let turnsFallback = r["turnsFallback"] as? Int ?? 0

                text += "Turn Selectors\n"
                text += "  Method: \(turnMethod)\n"
                text += "  Primary ([data-testid]): \(turnsPrimary)\n"
                text += "  Fallback (main article): \(turnsFallback)\n"
                if turnMethod == "none" {
                    text += "  ⚠ No turn selectors matched — compact/health/continuity degraded\n"
                }
                text += "\n"

                text += "Editor Detection\n"
                text += "  Method: \(editorMethod)\n"
                text += "  textarea: \(r["hasTextarea"] as? Bool ?? false)\n"
                text += "  contenteditable: \(r["hasContentEditable"] as? Bool ?? false)\n"
                if editorMethod == "none" {
                    text += "  ⚠ No editor found — input focus will timeout (normal on non-chat pages)\n"
                }
                text += "\n"

                text += "Page Structure\n"
                text += "  <main>: \(r["hasMain"] as? Bool ?? false)\n"
                text += "  Scroll container: \(r["hasScrollContainer"] as? Bool ?? false)\n"
                text += "  Code blocks: \(r["codeBlocks"] as? Int ?? 0)\n"
                text += "\n"

                text += "Injections\n"
                text += "  Perf CSS injected: \(r["hasPerfCSS"] as? Bool ?? false)\n"
                text += "  Perf mode active: \(r["hasPerfAttr"] as? Bool ?? false)\n"
                text += "  JS helpers loaded: \(r["hasHelpers"] as? Bool ?? false)\n"
                text += "  Archive runtime: \(r["archiveRuntime"] as? Bool ?? false)\n"
                text += "  Archive mode attr: \(r["archiveModeAttr"] as? String ?? "")\n"
                text += "  Archive enabled: \(r["archiveEnabled"] as? Bool ?? false)\n"
                text += "  Archive state: \(r["archiveRuntimeState"] as? String ?? "unknown")\n"
                if let reason = r["archiveReasonCode"] as? String, !reason.isEmpty {
                    text += "  Archive reason code: \(reason)\n"
                }
                text += "  Archive startup grace: \(r["archiveStartupGrace"] as? Bool ?? false)\n"
                text += "  Archive page ready: \(r["archivePageReady"] as? Bool ?? false)\n"
                text += "  Archive selector: \(r["archiveSelectorMethod"] as? String ?? "unknown")\n"
                text += "  Archive degraded: \(r["archiveSelectorDegraded"] as? Bool ?? false)\n"
                text += "  Archived turns/shells: \(r["archivedTurns"] as? Int ?? 0)/\(r["archivedShells"] as? Int ?? 0)\n"
                if let reason = r["archiveRuntimeReason"] as? String, !reason.isEmpty {
                    text += "  Archive disable reason: \(reason)\n"
                }
                text += "\n"

                text += "Context\n"
                text += "  ChatGPT page: \(r["isChatPage"] as? Bool ?? false)\n"
                let url = r["url"] as? String ?? "unknown"
                text += "  URL: \(url.prefix(80))\n"

            } else if let error {
                text += "Probe failed: \(error.localizedDescription)\n"
            } else {
                text += "Probe returned unexpected result.\n"
            }

            text += "\nHealth Monitor\n"
            text += "  Status: \(self.threadHealth.label)\n"
            text += "  Selector failures: \(self.healthSelectorFailures) consecutive\n"
            if self.healthSelectorFailures >= 3 {
                text += "  ⚠ Selector drift detected — health metrics unreliable\n"
            }
            text += "  Performance mode: \(self.performanceModeEnabled ? "ON" : "OFF")\n"

            text += "\nContinue in Fresh Chat\n"
            if let d = self.lastContinueChatDiagnostics {
                let df = DateFormatter()
                df.dateStyle = .none
                df.timeStyle = .medium
                text += "  Last run: \(df.string(from: d.timestamp))\n"
                text += "  Continuity extracted: \(d.continuityExtractOk)\n"
                text += "  Continuity selector: \(d.continuitySelectorMethod)\n"
                text += "  Scope: \(d.scope)\n"
                text += "  Project confidence: \(d.projectDetectionConfidence) (score \(String(format: "%.2f", d.projectDetectionScore)))\n"
                if let pid = d.projectId { text += "  Project id: \(pid.prefix(48))\n" }
                if let pb = d.projectBase { text += "  Project base: \(pb.prefix(80))\n" }
                text += "  Signals: \(d.projectSignals)\n"
                text += "  Attempted same-project: \(d.sameProjectAttempted)\n"
                text += "  Same-project succeeded: \(d.sameProjectSucceeded)\n"
                text += "  Fallback used: \(d.fallbackUsed)\n"
                if let r = d.fallbackReason { text += "  Fallback reason: \(r)\n" }
                if let s = d.clickSelector { text += "  Click selector: \(s)\n" }
                if let h = d.clickHref, !h.isEmpty { text += "  Click href: \(h.prefix(80))\n" }
                if let v = d.verifiedAt { text += "  Verified at: \(df.string(from: v))\n" }
            } else {
                text += "  No recent runs.\n"
            }

            if let p = self.pendingProjectContinuation {
                text += "\nPending Project Continuation\n"
                text += "  Expected project id: \(p.expectedProjectId.prefix(48))\n"
                text += "  Original URL: \(p.originalURL.prefix(80))\n"
                text += "  Clicked: \(p.click.clicked)\n"
                if let sel = p.click.selector { text += "  Selector: \(sel)\n" }
            }

            let alert = NSAlert()
            alert.messageText = "Feature Diagnostics"
            alert.informativeText = text
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
