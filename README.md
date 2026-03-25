# ChatEnhancer

An unofficial macOS desktop wrapper for ChatGPT focused on native UX improvements, better controls, and reliable file downloads.

> **ChatEnhancer is an independent project and is not affiliated with or endorsed by OpenAI.**

---

## What it does

ChatEnhancer wraps `chatgpt.com` in a native macOS window and adds features that the browser tab does not provide:

- **Native macOS window** — standard title bar, toolbar, keyboard shortcuts, and menu bar
- **Reliable file downloads** — downloads save to your Desktop (or Downloads/Documents as fallback) instead of opening inline in the webview
- **Thread health monitor** — tracks conversation length and alerts you when a thread is getting heavy, with a quick-action to continue in a fresh chat
- **Performance mode** — reduces CSS rendering overhead on long threads via a toolbar toggle (⌘⇧P)
- **Archive mode** — collapses older turns in-place to reduce live DOM pressure on very long conversations
- **Continue in Fresh Chat** — extracts a continuity bundle from the current thread and opens a new chat, preserving context via clipboard
- **Project-aware continuation** — detects whether you are inside a ChatGPT Project and routes the new chat to the same project automatically
- **Input focus loop** — on page load, polls until the composer is ready and focuses it automatically
- **Jump to Bottom** — toolbar button and ⌘↓ to scroll to the latest response instantly
- **Feature Diagnostics** — Tools menu panel showing live selector status, archive state, and continuation history

---

## Why it exists

The ChatGPT web interface in a browser tab has a few persistent annoyances:

- File downloads open inside the tab instead of saving to disk
- There is no native macOS menu bar, so standard shortcuts (⌘Q, ⌘H, ⌘M) do not work
- Long threads get slow; there is no built-in way to compact them
- Context is lost when you start a fresh chat without copying it manually

ChatEnhancer addresses all of these with a small, self-contained native app. No Electron, no extra runtimes — just Cocoa and WebKit.

---

## Screenshots

*Coming soon. Add PNGs to a `screenshots/` folder and reference them here.*

---

## Requirements

- macOS 13.0 or later
- Xcode command-line tools (`xcode-select --install`)
- Active internet connection (the app loads `chatgpt.com` via WebKit)

---

## Build

```bash
# Clone the repo
git clone git@github.com:landyo123-collab/ChatEnhancer.git
cd ChatEnhancer

# Build ChatEnhancer.app (output is written to ChatEnhancer.app/ in the repo root)
chmod +x build.sh
./build.sh

# Launch
open ChatEnhancer.app
```

The build script compiles all `.swift` files in `Sources/` using `xcrun swiftc` with Cocoa and WebKit frameworks. No package manager, no dependencies.

The output `ChatEnhancer.app` is created in the repo root.

---

## Project structure

```
ChatEnhancer/
├── Sources/
│   ├── main.swift              — entry point
│   ├── AppDelegate.swift       — app lifecycle, window, WebView setup
│   ├── Diagnostics.swift       — Perf/OSLog instrumentation, Prefs (UserDefaults), ThreadHealthLevel
│   ├── MenuAndToolbar.swift    — main menu and toolbar items
│   ├── NativeUX.swift          — toast notifications, placeholder loading view, input focus loop
│   ├── DownloadSupport.swift   — WKUIDelegate + WKDownloadDelegate: download routing and file destination
│   ├── HealthMonitor.swift     — thread health scoring and window title updates
│   ├── PerformanceMode.swift   — perf mode and turn compaction actions
│   ├── ArchiveMode.swift       — archive mode toggle and runtime communication
│   ├── ArchiveTelemetry.swift  — ArchiveTelemetrySnapshot model and JSON parsing
│   ├── Continuity.swift        — "Continue in Fresh Chat" logic with project-aware routing
│   ├── FeatureProbe.swift      — Feature Diagnostics panel (Tools menu)
│   └── JSPayloads.swift        — JavaScript injected into the WebView
├── Info.plist                  — bundle metadata (CFBundleIdentifier: com.unofficial.chatenhancer)
├── AppIcon.icns                — app icon
├── build.sh                    — build script (outputs ChatEnhancer.app)
├── .gitignore
└── README.md
```

---

## Download behavior

When you click a download link inside the ChatGPT interface, ChatEnhancer intercepts the WebKit navigation policy decision and routes the file to disk instead of opening it in the webview.

**How it works (`DownloadSupport.swift`):**

1. If the link's `shouldPerformDownload` flag is set by WebKit, it is immediately routed as a download
2. If the URL scheme is `blob:` or `data:`, it is forced to download
3. If the URL path extension matches a known downloadable type (`.txt`, `.md`, `.pdf`, `.csv`, `.json`, `.zip`, `.gz`, `.rar`, `.7z`, image formats, Office formats), it is forced to download
4. If the server responds with a `Content-Disposition: attachment` header, it is forced to download
5. If the MIME type cannot be rendered in WebKit, it is forced to download

**Save location (in priority order):**

1. `~/Desktop/`
2. `~/Downloads/`
3. `~/Documents/`
4. Home directory

The destination is always resolved using `FileManager` APIs with no hardcoded paths. Filename collisions are handled by appending a counter (`file 2.pdf`, `file 3.pdf`, etc.). A toast notification confirms the save.

---

## Notes and limitations

- **Unofficial**: ChatEnhancer has no relationship with OpenAI. It uses ChatGPT's public web interface the same way a browser does. Changes to chatgpt.com may affect features.
- **DOM selectors**: Archive mode, health monitoring, and continuation rely on CSS selectors in `JSPayloads.swift`. If OpenAI changes their DOM structure, these may degrade gracefully (selector failure is reported in Feature Diagnostics but does not crash the app).
- **No account access**: The app uses the default WebKit data store. Your session cookie is stored the same way Safari stores it — locally, not transmitted anywhere by this app.
- **No sandbox**: The app is not sandboxed. This is required for direct Desktop writes without a file picker. A sandboxed variant would need `com.apple.security.files.downloads.read-write` and/or a security-scoped bookmark flow.
- **One window**: The app keeps one persistent window and one persistent WebView instance. If you close the window, the app stays alive in the Dock; reopening it reattaches the existing WebView.
- **macOS 13+ only**: Uses `NSToolbar` unified style and SF Symbols which require macOS 11+; `LSMinimumSystemVersion` is set to 13.0 for stability.

---

## Contributing

This is a small personal project. Contributions are welcome — keep changes minimal and focused.

- Open an issue before large changes
- Test the build with `./build.sh` before submitting a PR
- Do not add external dependencies

---

## Security and privacy

- **Your session** stays in the local WebKit data store (same as Safari). ChatEnhancer does not read, copy, or transmit it.
- **Downloads** are written to your local filesystem using standard macOS APIs. No data is sent elsewhere.
- **JavaScript injections** (`JSPayloads.swift`) run inside the WebView to support UI features. They do not exfiltrate data; they return structured telemetry to the Swift layer via `window.webkit.messageHandlers.native.postMessage`.
- **No telemetry** is sent by this app. `Perf.event()` calls write to the local `os_signpost` log (visible in Instruments), not to any server.
- **No license**: No LICENSE file is included in this repository.
