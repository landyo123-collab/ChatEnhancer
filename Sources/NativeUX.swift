import Cocoa
import WebKit

// MARK: - Simple Actions

extension AppDelegate {
    @objc func refreshPage(_ sender: Any?) {
        Perf.event("UserRefresh")
        webView?.reload()
    }

    @objc func jumpToBottom(_ sender: Any?) {
        guard let wv = webView else { return }
        Perf.event("JumpToBottom")
        wv.evaluateJavaScript(JS.jumpToBottom) { _, _ in }
    }

    @objc func focusInput(_ sender: Any?) {
        Perf.event("ManualFocusInput")
        startInputFocusLoop(reason: "ManualFocusInput")
    }
}

// MARK: - Toast

extension AppDelegate {
    func showToast(_ message: String) {
        guard let window, let cv = window.contentView else { return }

        toastView?.removeFromSuperview()

        let container = NSVisualEffectView()
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .withinWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        container.addSubview(label)
        cv.addSubview(container)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            container.topAnchor.constraint(equalTo: cv.topAnchor, constant: 8),
        ])

        toastView = container

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard container == self?.toastView else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                container.animator().alphaValue = 0
            }, completionHandler: {
                container.removeFromSuperview()
                if self?.toastView == container { self?.toastView = nil }
            })
        }
    }
}

// MARK: - Placeholder

extension AppDelegate {
    func makePlaceholderView() -> NSView {
        let container = NSVisualEffectView()
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "Loading ChatGPT…")
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(spinner)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])

        return container
    }
}

// MARK: - Input Readiness Loop

extension AppDelegate {
    func startInputFocusLoop(reason: StaticString) {
        guard focusTimer == nil else { return }
        guard let wv = webView, !wv.isHidden else { return }
        guard window?.isKeyWindow == true else { return }

        didDetectInputReady = false
        focusAttemptsRemaining = 14
        Perf.event("FocusLoopStart")
        Perf.event(reason)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(120))
        timer.setEventHandler { [weak self] in self?.focusLoopTick() }
        focusTimer = timer
        timer.resume()
    }

    func stopInputFocusLoop(event: StaticString) {
        guard let timer = focusTimer else { return }
        Perf.event(event)
        timer.cancel()
        focusTimer = nil
        focusProbeInFlight = false
        focusAttemptsRemaining = 0
    }

    private func focusLoopTick() {
        guard let wv = webView else {
            stopInputFocusLoop(event: "FocusLoopStopNoWebView")
            return
        }
        if focusAttemptsRemaining <= 0 {
            stopInputFocusLoop(event: "FocusLoopTimeout")
            Perf.event("FocusFailureTimeout")
            return
        }
        if focusProbeInFlight { return }
        focusProbeInFlight = true
        focusAttemptsRemaining -= 1

        wv.evaluateJavaScript(JS.inputReadyAndFocus) { [weak self] result, error in
            guard let self else { return }
            self.focusProbeInFlight = false
            if error != nil { return }

            let code: Int
            if let n = result as? NSNumber { code = n.intValue }
            else { code = result as? Int ?? 0 }

            if code >= 1 && !self.didDetectInputReady {
                self.didDetectInputReady = true
                Perf.event("InputReadyDetected")
            }
            if code == 2 {
                Perf.event("FocusSuccess")
                self.stopInputFocusLoop(event: "FocusLoopStopSuccess")
            }
        }
    }
}
