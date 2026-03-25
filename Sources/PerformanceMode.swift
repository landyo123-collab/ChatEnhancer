import Cocoa
import WebKit

extension AppDelegate {
    @objc func togglePerformanceMode(_ sender: Any?) {
        performanceModeEnabled = !performanceModeEnabled
        Prefs.performanceModeEnabled = performanceModeEnabled

        if performanceModeEnabled {
            Perf.event("PerformanceModeEnabled")
            applyPerformanceMode()
        } else {
            Perf.event("PerformanceModeDisabled")
            removePerformanceMode()
        }
        updateToolbarItem(Self.perfModeItem)
    }

    func applyPerformanceMode() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.enablePerfMode) { _, error in
            if error != nil { Perf.event("PerformanceSelectorMiss") }
            else { Perf.event("PerformanceInjectionApplied") }
        }
    }

    private func removePerformanceMode() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(JS.disablePerfMode) { _, error in
            if error != nil { Perf.event("PerformanceFallbackNoop") }
        }
    }

    @objc func compactOldTurns(_ sender: Any?) {
        Perf.event("ManualCompactOldTurns")
        if archiveModeEnabled {
            runArchivePassNow()
        } else if let wv = webView {
            wv.evaluateJavaScript(JS.perfCompactOldTurns) { _, _ in }
        }
    }

    @objc func expandAllTurns(_ sender: Any?) {
        Perf.event("ManualExpandAllTurns")
        if archiveModeEnabled {
            restoreArchivedTurnsBestEffort()
        } else if let wv = webView {
            wv.evaluateJavaScript(JS.perfExpandAll) { _, _ in }
        }
    }
}
