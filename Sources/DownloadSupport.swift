import Cocoa
import WebKit

extension AppDelegate: WKUIDelegate, WKDownloadDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            Perf.event("DownloadForcedByWebKit")
            decisionHandler(.download)
            return
        }

        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "blob" || scheme == "data" {
            Perf.event("DownloadForcedByScheme")
            decisionHandler(.download)
            return
        }

        if (scheme == "http" || scheme == "https") && shouldTreatAsDownload(url: url) {
            Perf.event("DownloadForcedByHeuristic")
            decisionHandler(.download)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let http = navigationResponse.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
           disposition.contains("attachment") {
            Perf.event("DownloadForcedByDisposition")
            decisionHandler(.download)
            return
        }

        if !navigationResponse.canShowMIMEType {
            Perf.event("DownloadForcedByMIME")
            decisionHandler(.download)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        Perf.event("NavigationActionBecameDownload")
        download.delegate = self
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        Perf.event("NavigationResponseBecameDownload")
        download.delegate = self
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let destination = makeDownloadDestination(for: suggestedFilename)
        Perf.event("DownloadDestinationResolved")
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        Perf.event("DownloadDidFinish")
        showToast("Downloaded to Desktop")
    }

    func download(_ download: WKDownload,
                  didFailWithError error: Error,
                  resumeData: Data?) {
        Perf.event("DownloadDidFail")
        showToast("Download failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        webView.load(navigationAction.request)
        return nil
    }

    private func shouldTreatAsDownload(url: URL) -> Bool {
        let downloadableExts: Set<String> = [
            "txt", "md", "markdown", "pdf", "csv", "tsv", "json",
            "zip", "gz", "rar", "7z",
            "png", "jpg", "jpeg", "webp", "gif",
            "doc", "docx", "xls", "xlsx", "ppt", "pptx"
        ]

        let ext = url.pathExtension.lowercased()
        if downloadableExts.contains(ext) { return true }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                let name = item.name.lowercased()
                let value = (item.value ?? "").lowercased()
                if ["download", "dl", "export", "attachment"].contains(name) { return true }
                if value == "download" || value == "attachment" || value == "1" || value == "true" { return true }
            }
        }

        return false
    }

    private func makeDownloadDestination(for suggestedFilename: String) -> URL? {
        let fileManager = FileManager.default

        // Preferred locations in order: Desktop, Downloads, Documents, Home
        let preferredDirs: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .downloadsDirectory,
            .documentDirectory
        ]

        var targetDir: URL?

        // Try each preferred directory
        for searchDir in preferredDirs {
            if let dir = fileManager.urls(for: searchDir, in: .userDomainMask).first {
                do {
                    try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                    targetDir = dir
                    break
                } catch {
                    continue
                }
            }
        }

        // Fall back to home directory if all else fails
        if targetDir == nil {
            targetDir = fileManager.homeDirectoryForCurrentUser
        }

        guard let dir = targetDir else { return nil }

        let cleanedFilename = sanitizedFilename(from: suggestedFilename)
        let baseName = (cleanedFilename as NSString).deletingPathExtension
        let ext = (cleanedFilename as NSString).pathExtension

        var destination = dir.appendingPathComponent(cleanedFilename)
        var counter = 2

        while fileManager.fileExists(atPath: destination.path) {
            let candidate = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            destination = dir.appendingPathComponent(candidate)
            counter += 1
        }

        return destination
    }

    private func sanitizedFilename(from suggestedFilename: String) -> String {
        let fallback = "download"
        let raw = suggestedFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = raw.isEmpty ? fallback : raw

        let illegal = CharacterSet(charactersIn: "/:\\\n\r\t")
        let pieces = source.components(separatedBy: illegal).filter { !$0.isEmpty }
        let joined = pieces.joined(separator: "-")
        return joined.isEmpty ? fallback : joined
    }
}
