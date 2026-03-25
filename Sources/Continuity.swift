import Cocoa
import WebKit

struct ProjectScopeSignalSummary {
    let name: String
    let weight: Double
    let evidence: String
}

struct ProjectScopeProbeResult {
    let ok: Bool
    let url: String
    let scope: String               // "project" | "non-project" | "unknown"
    let projectId: String?
    let projectBase: String?
    let score: Double
    let confidence: String          // "high" | "medium" | "low"
    let signals: [ProjectScopeSignalSummary]

    var signalsShort: String {
        if signals.isEmpty { return "(none)" }
        return signals.prefix(5).map { s in
            let ev = s.evidence.isEmpty ? "" : "=\(s.evidence.prefix(60))"
            return "\(s.name)(\(String(format: "%.2f", s.weight)))\(ev)"
        }.joined(separator: ", ")
    }
}

struct ProjectNewChatClickResult {
    let ok: Bool
    let clicked: Bool
    let selector: String?
    let href: String?
    let beforeURL: String?
    let error: String?
}

struct PendingProjectContinuation {
    let startedAt: Date
    let expectedProjectId: String
    let originalURL: String
    let scopeProbe: ProjectScopeProbeResult
    let click: ProjectNewChatClickResult
}

struct ContinueChatDiagnostics {
    var timestamp: Date
    var continuityExtractOk: Bool
    var continuitySelectorMethod: String

    var scope: String                   // project | non-project | unknown
    var projectDetectionConfidence: String
    var projectDetectionScore: Double
    var projectId: String?
    var projectBase: String?
    var projectSignals: String

    var sameProjectAttempted: Bool
    var sameProjectSucceeded: Bool
    var fallbackUsed: Bool
    var fallbackReason: String?

    var clickSelector: String?
    var clickHref: String?

    var verifiedAt: Date?
}

extension AppDelegate {

    // MARK: - Clipboard-First Continuation

    @objc func continueInFreshChat(_ sender: Any?) {
        guard let wv = webView else { return }
        Perf.event("FreshContinuationInvoked")

        wv.evaluateJavaScript(JS.continuityExtract) { [weak self] result, error in
            guard let self else { return }

            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = info["ok"] as? Bool, ok,
                  let bundle = info["bundle"] as? String, !bundle.isEmpty else {
                Perf.event("FreshContinuationFailed")
                let method = (try? JSONSerialization.jsonObject(
                    with: (result as? String)?.data(using: .utf8) ?? Data()
                ) as? [String: Any])?["selectorMethod"] as? String

                self.lastContinueChatDiagnostics = ContinueChatDiagnostics(
                    timestamp: Date(),
                    continuityExtractOk: false,
                    continuitySelectorMethod: method ?? "unknown",
                    scope: "unknown",
                    projectDetectionConfidence: "low",
                    projectDetectionScore: 0,
                    projectId: nil,
                    projectBase: nil,
                    projectSignals: "(not probed)",
                    sameProjectAttempted: false,
                    sameProjectSucceeded: false,
                    fallbackUsed: false,
                    fallbackReason: nil,
                    clickSelector: nil,
                    clickHref: nil,
                    verifiedAt: nil
                )

                if method == "none" {
                    self.showToast("Could not find conversation turns — opening fresh chat")
                } else {
                    self.showToast("Could not extract continuity — opening fresh chat")
                }
                self.openFreshChat(using: self.lastContinueChatDiagnostics!)
                return
            }

            Perf.event("ContinuityBundleBuilt")

            // Clipboard is the canonical delivery path
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(bundle, forType: .string)
            Perf.event("ContinuityBundleCopied")

            // Store for silent best-effort prefill (no user-facing promise)
            self.pendingContinuityBundle = bundle

            self.showToast("Continuity copied to clipboard — paste with ⌘V")

            self.threadHealth = .healthy
            self.healthSelectorFailures = 0
            self.updateToolbarItem(Self.healthItem)
            self.updateWindowTitleHealth()

            Perf.event("FreshChatOpened")

            let selectorMethod = info["selectorMethod"] as? String ?? "unknown"
            self.lastContinueChatDiagnostics = ContinueChatDiagnostics(
                timestamp: Date(),
                continuityExtractOk: true,
                continuitySelectorMethod: selectorMethod,
                scope: "unknown",
                projectDetectionConfidence: "low",
                projectDetectionScore: 0,
                projectId: nil,
                projectBase: nil,
                projectSignals: "(not probed)",
                sameProjectAttempted: false,
                sameProjectSucceeded: false,
                fallbackUsed: false,
                fallbackReason: nil,
                clickSelector: nil,
                clickHref: nil,
                verifiedAt: nil
            )

            self.openFreshChat(using: self.lastContinueChatDiagnostics!)
        }
    }

    @objc func copyContinuityBundle(_ sender: Any?) {
        guard let wv = webView else { return }

        wv.evaluateJavaScript(JS.continuityExtract) { [weak self] result, error in
            guard let self else { return }

            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = info["ok"] as? Bool, ok,
                  let bundle = info["bundle"] as? String, !bundle.isEmpty else {
                Perf.event("ContinuityExtractionFallback")
                self.showToast("Could not extract continuity bundle")
                return
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(bundle, forType: .string)
            Perf.event("ContinuityBundleCopied")
            self.showToast("Continuity bundle copied to clipboard")
        }
    }

    private func openFreshChat(using base: ContinueChatDiagnostics) {
        guard let wv = webView else { return }

        // Clear any in-flight attempt (new invocation wins).
        projectContinuationTimer?.cancel()
        projectContinuationTimer = nil
        pendingProjectContinuation = nil

        // Default: existing behavior (normal new chat).
        func openNormal(_ diag: ContinueChatDiagnostics, toast: String? = nil) {
            var d = diag
            d.scope = d.scope.isEmpty ? "unknown" : d.scope
            d.sameProjectSucceeded = false
            d.verifiedAt = Date()
            lastContinueChatDiagnostics = d
            if let toast { self.showToast(toast) }
            guard let url = URL(string: "https://chatgpt.com/") else { return }
            wv.load(URLRequest(url: url))
        }

        // Kill switch / debug override.
        if Prefs.projectAwareContinuationEnabled == false {
            Perf.event("ProjectContinuationDisabled")
            var d = base
            d.scope = "unknown"
            d.projectSignals = "(disabled)"
            d.fallbackUsed = true
            d.fallbackReason = "disabled"
            openNormal(d)
            return
        }
        if Prefs.projectAwareContinuationForceFallback {
            Perf.event("ProjectContinuationForcedFallback")
            var d = base
            d.scope = "unknown"
            d.projectSignals = "(forced fallback)"
            d.fallbackUsed = true
            d.fallbackReason = "forced_fallback"
            openNormal(d, toast: "Project continuation forced off — opened normal fresh chat")
            return
        }

        Perf.event("ProjectScopeProbeStart")
        wv.evaluateJavaScript(JS.projectScopeProbe) { [weak self] result, error in
            guard let self else { return }

            var d = base

            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = info["ok"] as? Bool, ok else {
                Perf.event("ProjectScopeProbeFailed")
                d.scope = "unknown"
                d.projectSignals = "(probe failed)"
                d.fallbackUsed = true
                d.fallbackReason = "probe_failed"
                openNormal(d, toast: "Project context unknown — opened normal fresh chat")
                return
            }

            let scope = info["scope"] as? String ?? "unknown"
            let confidence = info["confidence"] as? String ?? "low"
            let score = (info["score"] as? NSNumber)?.doubleValue ?? (info["score"] as? Double ?? 0)
            let projectId = info["projectId"] as? String
            let projectBase = info["projectBase"] as? String

            var signals: [ProjectScopeSignalSummary] = []
            if let sig = info["signals"] as? [[String: Any]] {
                for s in sig {
                    let name = s["name"] as? String ?? "unknown"
                    let w = (s["weight"] as? NSNumber)?.doubleValue ?? (s["weight"] as? Double ?? 0)
                    let ev = s["evidence"] as? String ?? ""
                    signals.append(ProjectScopeSignalSummary(name: name, weight: w, evidence: ev))
                }
            }

            let probe = ProjectScopeProbeResult(
                ok: true,
                url: info["url"] as? String ?? "",
                scope: scope,
                projectId: projectId,
                projectBase: projectBase,
                score: score,
                confidence: confidence,
                signals: signals
            )

            d.scope = probe.scope
            d.projectDetectionConfidence = probe.confidence
            d.projectDetectionScore = probe.score
            d.projectId = probe.projectId
            d.projectBase = probe.projectBase
            d.projectSignals = probe.signalsShort

            let minScore = Prefs.projectAwareContinuationMinScore
            let isConfidentProject = (probe.scope == "project") && (probe.projectId != nil) && (probe.score >= minScore)

            if !isConfidentProject {
                // Safe fallback: use normal new-chat behavior.
                Perf.event("ProjectContinuationNotAttempted")
                if probe.scope == "project" {
                    d.fallbackUsed = true
                    d.fallbackReason = "low_confidence"
                } else {
                    d.fallbackUsed = false
                }
                openNormal(d)
                return
            }

            if Prefs.projectAwareContinuationAttemptEnabled == false {
                Perf.event("ProjectContinuationAttemptDisabled")
                d.fallbackUsed = true
                d.fallbackReason = "attempt_disabled"
                openNormal(d, toast: "Project continuation disabled — opened normal fresh chat")
                return
            }

            // Same-project continuation attempt: click the in-scope New Chat control, then validate.
            d.sameProjectAttempted = true
            Perf.event("ProjectContinuationAttempt")

            wv.evaluateJavaScript(JS.projectNewChatClick) { [weak self] clickResult, clickError in
                guard let self else { return }

                guard clickError == nil,
                      let jsonStr = clickResult as? String,
                      let data = jsonStr.data(using: .utf8),
                      let ci = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ok = ci["ok"] as? Bool, ok else {
                    Perf.event("ProjectNewChatClickFailed")
                    var dd = d
                    dd.fallbackUsed = true
                    dd.fallbackReason = "new_chat_click_failed"
                    openNormal(dd, toast: "Project continuation failed — opened normal fresh chat")
                    return
                }

                let clicked = ci["clicked"] as? Bool ?? false
                let selector = ci["selector"] as? String
                let href = ci["href"] as? String
                let beforeURL = ci["before"] as? String

                let click = ProjectNewChatClickResult(
                    ok: true,
                    clicked: clicked,
                    selector: selector,
                    href: href,
                    beforeURL: beforeURL,
                    error: nil
                )

                var dd = d
                dd.clickSelector = selector
                dd.clickHref = href

                if !clicked {
                    Perf.event("ProjectNewChatControlMissing")
                    dd.fallbackUsed = true
                    dd.fallbackReason = "new_chat_control_missing"
                    openNormal(dd, toast: "Project continuation unavailable — opened normal fresh chat")
                    return
                }

                guard let expectedProjectId = probe.projectId else {
                    dd.fallbackUsed = true
                    dd.fallbackReason = "missing_project_id"
                    openNormal(dd)
                    return
                }

                pendingProjectContinuation = PendingProjectContinuation(
                    startedAt: Date(),
                    expectedProjectId: expectedProjectId,
                    originalURL: probe.url,
                    scopeProbe: probe,
                    click: click
                )

                // Validation loop: wait for URL change, then re-probe and compare.
                Perf.event("ProjectContinuationValidateStart")
                let maxTicks = 16
                var ticks = 0
                let timer = DispatchSource.makeTimerSource(queue: .main)
                timer.schedule(deadline: .now() + 0.2, repeating: .milliseconds(250))
                timer.setEventHandler { [weak self] in
                    guard let self else { return }
                    ticks += 1

                    let currentURL = self.webView?.url?.absoluteString ?? ""
                    let before = beforeURL ?? probe.url

                    if !currentURL.isEmpty && currentURL != before {
                        timer.cancel()
                        self.projectContinuationTimer = nil
                        self.validateSameProjectContinuation(expectedProjectId: expectedProjectId, baseDiag: dd, urlAfter: currentURL)
                        return
                    }

                    if ticks >= maxTicks {
                        timer.cancel()
                        self.projectContinuationTimer = nil
                        Perf.event("ProjectContinuationValidateTimeout")
                        var dx = dd
                        dx.fallbackUsed = true
                        dx.fallbackReason = "timeout_no_navigation"
                        self.pendingProjectContinuation = nil
                        openNormal(dx, toast: "Project continuation timed out — opened normal fresh chat")
                    }
                }
                projectContinuationTimer = timer
                timer.resume()
            }
        }
    }

    private func validateSameProjectContinuation(expectedProjectId: String, baseDiag: ContinueChatDiagnostics, urlAfter: String) {
        guard let wv = webView else { return }

        if Prefs.projectAwareContinuationValidationEnabled == false {
            Perf.event("ProjectContinuationValidationDisabled")
            var d = baseDiag
            d.sameProjectSucceeded = false
            d.fallbackUsed = true
            d.fallbackReason = "validation_disabled"
            d.verifiedAt = Date()
            lastContinueChatDiagnostics = d
            showToast("Project continuation unverified — opened normal fresh chat")
            if let url = URL(string: "https://chatgpt.com/") { wv.load(URLRequest(url: url)) }
            return
        }

        Perf.event("ProjectContinuationValidateProbe")
        wv.evaluateJavaScript(JS.projectScopeProbe) { [weak self] result, error in
            guard let self else { return }

            guard error == nil,
                  let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = info["ok"] as? Bool, ok else {
                Perf.event("ProjectContinuationValidateProbeFail")
                var d = baseDiag
                d.fallbackUsed = true
                d.fallbackReason = "validation_probe_failed"
                d.verifiedAt = Date()
                self.lastContinueChatDiagnostics = d
                self.pendingProjectContinuation = nil
                if let url = URL(string: "https://chatgpt.com/") { wv.load(URLRequest(url: url)) }
                self.showToast("Project continuation failed — opened normal fresh chat")
                return
            }

            let scope = info["scope"] as? String ?? "unknown"
            let pid = info["projectId"] as? String

            var d = baseDiag
            d.verifiedAt = Date()

            if scope == "project", pid == expectedProjectId {
                // Extra safety: only claim success if the surface looks like an empty/fresh chat.
                wv.evaluateJavaScript(JS.continuityPrefillGuard) { [weak self] guardResult, _ in
                    guard let self else { return }
                    var dd = d

                    guard let jsonStr = guardResult as? String,
                          let data = jsonStr.data(using: .utf8),
                          let gi = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let gok = gi["ok"] as? Bool, gok else {
                        Perf.event("ProjectContinuationGuardFail")
                        dd.fallbackUsed = true
                        dd.fallbackReason = "post_nav_guard_failed"
                        dd.sameProjectSucceeded = false
                        self.lastContinueChatDiagnostics = dd
                        self.pendingProjectContinuation = nil
                        if let url = URL(string: "https://chatgpt.com/") { wv.load(URLRequest(url: url)) }
                        self.showToast("Project continuation uncertain — opened normal fresh chat")
                        return
                    }

                    let turns = gi["turns"] as? Int ?? (gi["turns"] as? NSNumber)?.intValue ?? 0
                    let hasEditor = gi["hasEditor"] as? Bool ?? false
                    if turns == 0 && hasEditor {
                        Perf.event("ProjectContinuationSucceeded")
                        dd.sameProjectSucceeded = true
                        dd.fallbackUsed = false
                        dd.fallbackReason = nil
                        self.lastContinueChatDiagnostics = dd
                        self.pendingProjectContinuation = nil
                        self.showToast("Opened fresh chat in project")
                    } else {
                        Perf.event("ProjectContinuationNotFreshSurface")
                        dd.fallbackUsed = true
                        dd.fallbackReason = "project_target_not_fresh"
                        dd.sameProjectSucceeded = false
                        self.lastContinueChatDiagnostics = dd
                        self.pendingProjectContinuation = nil
                        if let url = URL(string: "https://chatgpt.com/") { wv.load(URLRequest(url: url)) }
                        self.showToast("Project continuation not fresh — opened normal fresh chat")
                    }
                }
            } else {
                Perf.event("ProjectContinuationValidationMismatch")
                d.fallbackUsed = true
                d.fallbackReason = "post_nav_validation_failed"
                d.sameProjectSucceeded = false
                self.lastContinueChatDiagnostics = d
                self.pendingProjectContinuation = nil
                if let url = URL(string: "https://chatgpt.com/") { wv.load(URLRequest(url: url)) }
                self.showToast("Project continuation unavailable — opened normal fresh chat")
            }
        }
    }

    // Silent best-effort prefill. Does NOT toast on success or failure.
    // The clipboard always has the bundle as the reliable path.
    func attemptSilentPrefill(_ bundle: String) {
        guard let wv = webView else { return }

        let escaped = bundle
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let js = """
        (function() {
            try {
                var el = document.querySelector('[contenteditable="true"]') || document.querySelector('textarea');
                if (!el) return false;
                el.focus();
                document.execCommand('insertText', false, '\(escaped)');
                return true;
            } catch(e) { return false; }
        })();
        """

        wv.evaluateJavaScript(js) { result, _ in
            let ok = (result as? Bool) == true || (result as? NSNumber)?.boolValue == true
            if ok { Perf.event("ContinuityBundlePrefilled") }
            // No error handling — clipboard is the real path
        }
    }

    // Prefill is optional; only attempt it when the surface appears to be a fresh/empty chat.
    func attemptSilentPrefillIfSafe(_ bundle: String) {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.continuityPrefillGuard) { [weak self] result, _ in
            guard let self else { return }
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = info["ok"] as? Bool, ok else {
                Perf.event("ContinuityPrefillGuardFail")
                return
            }

            let turns = info["turns"] as? Int ?? (info["turns"] as? NSNumber)?.intValue ?? 0
            let hasEditor = info["hasEditor"] as? Bool ?? false
            if turns == 0 && hasEditor {
                self.attemptSilentPrefill(bundle)
            } else {
                Perf.event("ContinuityPrefillSkippedNonEmpty")
            }
        }
    }
}
