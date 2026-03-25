import Cocoa
import WebKit

private enum WebKitShared {
    static let processPool = WKProcessPool()
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate,
                          WKNavigationDelegate, WKScriptMessageHandler {
    var window: NSWindow?
    var placeholderView: NSView?
    var toastView: NSView?
    var webView: WKWebView?

    var didSwapInWebView = false
    var swapFallback: DispatchWorkItem?

    static let messageHandlerName = "native"

    // Toolbar identifiers
    static let refreshItem    = NSToolbarItem.Identifier("chatgpt.refresh")
    static let perfModeItem   = NSToolbarItem.Identifier("chatgpt.perfMode")
    static let archiveItem    = NSToolbarItem.Identifier("chatgpt.archiveMode")
    static let healthItem     = NSToolbarItem.Identifier("chatgpt.health")
    static let continueItem   = NSToolbarItem.Identifier("chatgpt.continue")
    static let jumpBottomItem = NSToolbarItem.Identifier("chatgpt.jumpBottom")

    var webViewCreateCount = 0

    // Input readiness
    var focusTimer: DispatchSourceTimer?
    var focusProbeInFlight = false
    var focusAttemptsRemaining = 0
    var didDetectInputReady = false

    // Performance mode
    var performanceModeEnabled = false
    var archiveModeEnabled = false
    var archiveArmNonce: Int = 0

    // Thread health
    var threadHealth: ThreadHealthLevel = .healthy
    var healthTimer: DispatchSourceTimer?
    var healthCheckInFlight = false
    var healthSelectorFailures = 0  // consecutive health checks with selectorMethod=="none" on a chat page
    var archiveTelemetry = ArchiveTelemetrySnapshot.empty

    // Continuation
    var pendingContinuityBundle: String?
    var lastContinueChatDiagnostics: ContinueChatDiagnostics?
    var pendingProjectContinuation: PendingProjectContinuation?
    var projectContinuationTimer: DispatchSourceTimer?

    // MARK: - App Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        Perf.event("AppWillFinishLaunching")
        performanceModeEnabled = Prefs.performanceModeEnabled
        archiveModeEnabled = false
        buildMainMenu()
        createAndShowWindow(showPlaceholder: true, reason: "LaunchWindow")
        NSApp.activate(ignoringOtherApps: true)
        Perf.event("WindowVisible")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Perf.event("AppDidFinishLaunching")
        DispatchQueue.main.async { [weak self] in
            self?.startWebViewIfNeeded(reason: "LaunchStartWebView")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Perf.event("KeepAliveAfterLastWindowClosed")
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Perf.event("ReopenRequest")
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            Perf.event("ReopenShowExistingWindow")
            window.makeKeyAndOrderFront(nil)
            startInputFocusLoop(reason: "ReopenExistingWindow")
            return true
        }

        let needPlaceholder = (webView == nil) || !didSwapInWebView
        createAndShowWindow(showPlaceholder: needPlaceholder, reason: "ReopenCreateWindow")

        if webView != nil {
            Perf.event("WebViewReused")
            if !needPlaceholder { startInputFocusLoop(reason: "ReopenWarmReattach") }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startWebViewIfNeeded(reason: "ReopenStartWebView")
            }
        }
        return true
    }

    // MARK: - Window Lifecycle

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) == window else { return }
        Perf.event("WindowWillClose")
        stopInputFocusLoop(event: "FocusLoopStopOnClose")
        stopHealthMonitor()
        projectContinuationTimer?.cancel()
        projectContinuationTimer = nil
        pendingProjectContinuation = nil
        webView?.removeFromSuperview()
        placeholderView = nil
        window = nil
        Perf.event("WindowClosedKeptAlive")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) == window else { return }
        Perf.event("WindowDidBecomeKey")
        startInputFocusLoop(reason: "WindowDidBecomeKey")
    }

    private func createAndShowWindow(showPlaceholder: Bool, reason: StaticString) {
        Perf.event(reason)

        let w = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 1280, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = "ChatEnhancer"
        w.minSize = NSSize(width: 900, height: 620)
        w.center()
        w.delegate = self

        let tb = NSToolbar(identifier: "ChatGPTToolbar")
        tb.delegate = self
        tb.displayMode = .iconOnly
        tb.sizeMode = .regular
        tb.allowsUserCustomization = false
        w.toolbar = tb
        w.toolbar?.isVisible = true
        if #available(macOS 11.0, *) { w.toolbarStyle = .unified }

        let cv = NSView(frame: .zero)
        cv.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = cv

        if showPlaceholder {
            let ph = makePlaceholderView()
            ph.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(ph)
            NSLayoutConstraint.activate([
                ph.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                ph.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                ph.topAnchor.constraint(equalTo: cv.topAnchor),
                ph.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
            ])
            placeholderView = ph
        } else {
            placeholderView = nil
        }

        if let wv = webView { attachWebView(wv, to: cv) }

        window = w
        Perf.begin("WindowShow")
        w.makeKeyAndOrderFront(nil)
        Perf.end("WindowShow")
    }

    private func attachWebView(_ wv: WKWebView, to cv: NSView) {
        wv.translatesAutoresizingMaskIntoConstraints = false
        if let ph = placeholderView {
            cv.addSubview(wv, positioned: .below, relativeTo: ph)
            wv.isHidden = true
        } else {
            cv.addSubview(wv)
            wv.isHidden = false
        }
        NSLayoutConstraint.activate([
            wv.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            wv.topAnchor.constraint(equalTo: cv.topAnchor),
            wv.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        ])
    }

    // MARK: - WebView Startup

    private func startWebViewIfNeeded(reason: StaticString) {
        guard webView == nil else { return }
        guard let window, let cv = window.contentView else { return }
        Perf.event(reason)

        webViewCreateCount += 1
        Perf.event(webViewCreateCount == 1 ? "WebViewCreateFirst" : "WebViewRecreated")
        Perf.begin("WebViewCreate")

        let config = WKWebViewConfiguration()
        config.processPool = WebKitShared.processPool
        config.websiteDataStore = .default()
        let ucc = WKUserContentController()
        ucc.add(self, name: Self.messageHandlerName)
        ucc.addUserScript(WKUserScript(source: JS.lifecycle, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: JS.archiveRuntime, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        attachWebView(wv, to: cv)
        webView = wv

        Perf.end("WebViewCreate")
        Perf.event("WebViewCreated")
        Perf.begin("Navigation")

        if let url = URL(string: "https://chatgpt.com") {
            wv.load(URLRequest(url: url))
            Perf.event("NavigationStarted")
        } else {
            Perf.event("NavigationURLInvalid")
        }
    }

    func swapInWebViewIfNeeded(_ reason: StaticString) {
        guard !didSwapInWebView, let wv = webView else { return }
        didSwapInWebView = true
        swapFallback?.cancel()
        swapFallback = nil

        Perf.event("ReadyToSwap")
        Perf.end("Navigation")
        Perf.event(reason)

        wv.isHidden = false
        placeholderView?.removeFromSuperview()
        placeholderView = nil

        startInputFocusLoop(reason: "SwapDidShowWebView")
        startHealthMonitor()
        injectSharedHelpers()
        if performanceModeEnabled { applyPerformanceMode() }
    }

    private func injectSharedHelpers() {
        webView?.evaluateJavaScript(JS.sharedHelpers) { _, _ in }
        webView?.evaluateJavaScript(JS.archiveRuntime) { _, _ in }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Perf.event("DidCommit")
        if swapFallback == nil && !didSwapInWebView {
            let work = DispatchWorkItem { [weak self] in
                self?.swapInWebViewIfNeeded("SwapReasonDidCommitFallback")
            }
            swapFallback = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Perf.event("DidFinish")
        startInputFocusLoop(reason: "DidFinish")
        injectSharedHelpers()

        if performanceModeEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.applyPerformanceMode()
            }
        }

        // Clipboard-first: prefill is silent best-effort bonus only
        if let bundle = pendingContinuityBundle {
            pendingContinuityBundle = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.attemptSilentPrefillIfSafe(bundle)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Perf.event("NavFail")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Perf.event("NavFailProvisional")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName else { return }
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }

        switch type {
        case "domContentLoaded":
            Perf.event("DOMContentLoaded")
            swapInWebViewIfNeeded("SwapReasonDOMContentLoaded")
        case "load":
            Perf.event("WindowLoad")
        case "archiveRuntimeReady":
            Perf.event("ArchiveRuntimeReady")
            if let payload = body["payload"] as? [String: Any] {
                ingestArchiveTelemetry(payload, source: "archiveRuntimeReady")
            }
        case "archiveTelemetry", "archiveCounts":
            if let payload = body["payload"] as? [String: Any] {
                ingestArchiveTelemetry(payload, source: type)
            } else {
                ingestArchiveTelemetry(body, source: type)
            }
        case "archiveSelectorDegraded":
            Perf.event("PerformanceSelectorDegraded")
            if let payload = body["payload"] as? [String: Any] {
                ingestArchiveTelemetry(payload, source: type)
            } else {
                ingestArchiveTelemetry(body, source: type)
            }
        case "archiveDebug":
            Perf.event("ArchiveRuntimeDebug")
        default:
            break
        }
    }
}
