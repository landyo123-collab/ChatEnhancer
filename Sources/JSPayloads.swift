import Foundation

// All JavaScript and CSS injected by the native app.
// Each IIFE is self-contained: helpers are inlined with a typeof guard
// so no snippet depends on prior injection order.

enum JS {

    // MARK: - Helper Preamble

    // Inlined at the top of any JS that needs cgptFindTurns / cgptCompactTurn.
    // Defines them on window if absent; no-ops if already present.
    private static let helperPreamble = """
    if (typeof cgptFindTurns !== 'function') {
      window.cgptFindTurns = function() {
        var t = document.querySelectorAll('[data-testid^="conversation-turn"]');
        if (t.length > 0) return Array.from(t);
        t = document.querySelectorAll('main article');
        if (t.length > 0) return Array.from(t);
        var m = document.querySelector('main');
        if (m) {
          var c = m.querySelector('[class*="react-scroll"]') || m.firstElementChild;
          if (c) return Array.from(c.children).filter(function(el) { return el.offsetHeight > 50; });
        }
        return [];
      };
      window.cgptCompactTurn = function(turn) {
        turn.classList.add('cgpt-compacted');
        var bar = document.createElement('div');
        bar.className = 'cgpt-expand-bar';
        bar.innerHTML = '<span>Click to expand</span>';
        bar.addEventListener('click', function(e) {
          e.stopPropagation();
          turn.classList.remove('cgpt-compacted');
          bar.remove();
        });
        turn.appendChild(bar);
      };
    }
    """

    // Standalone injection of helpers (called after swap-in and didFinish).
    static let sharedHelpers = helperPreamble

    // MARK: - Lifecycle

    static let lifecycle = """
    (function() {
      function post(type) {
        try {
          window.webkit.messageHandlers.native.postMessage({
            type: type,
            href: String(location.href || ''),
            readyState: String(document.readyState || '')
          });
        } catch (e) {}
      }
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() { post('domContentLoaded'); }, { once: true });
      } else {
        post('domContentLoaded');
      }
      window.addEventListener('load', function() { post('load'); }, { once: true });
    })();
    """

    // MARK: - Input Focus

    static let inputReadyAndFocus = """
    (function() {
      try {
        function isUsable(el) {
          if (!el) return false;
          if (el.disabled) return false;
          var ad = el.getAttribute && el.getAttribute('aria-disabled');
          if (ad === 'true') return false;
          if (el.getClientRects && el.getClientRects().length === 0) return false;
          var cs = window.getComputedStyle ? window.getComputedStyle(el) : null;
          if (cs && (cs.visibility === 'hidden' || cs.display === 'none')) return false;
          return true;
        }
        var el = document.querySelector('textarea:not([disabled])');
        if (!isUsable(el)) {
          el = document.querySelector('[contenteditable="true"]');
          if (!isUsable(el)) el = null;
        }
        if (!el) return 0;
        try { el.focus(); } catch (e) {}
        var ae = document.activeElement;
        return (ae === el || (el.contains && ae && el.contains(ae))) ? 2 : 1;
      } catch (e) { return 0; }
    })();
    """

    // MARK: - Performance CSS

    static let perfCSS = """
    body[data-cgpt-perf] *,
    body[data-cgpt-perf] *::before,
    body[data-cgpt-perf] *::after {
      transition-duration: 0s !important;
      animation-duration: 0s !important;
      animation-delay: 0s !important;
    }
    body[data-cgpt-perf] [style*="backdrop-filter"],
    body[data-cgpt-perf] [class*="backdrop"] {
      backdrop-filter: none !important;
      -webkit-backdrop-filter: none !important;
    }
    body[data-cgpt-perf] [style*="filter"]:not(svg *) {
      filter: none !important;
    }
    .cgpt-compacted {
      max-height: 120px !important;
      overflow: hidden !important;
      position: relative !important;
      opacity: 0.55 !important;
      border-left: 3px solid rgba(128,128,128,0.25) !important;
      padding-left: 8px !important;
    }
    .cgpt-expand-bar {
      position: absolute !important;
      bottom: 0 !important; left: 0 !important; right: 0 !important;
      height: 38px !important;
      background: linear-gradient(to bottom, transparent, var(--main-surface-primary, #f7f7f8)) !important;
      display: flex !important;
      align-items: flex-end !important;
      justify-content: center !important;
      cursor: pointer !important;
      z-index: 100 !important;
    }
    html.dark .cgpt-expand-bar, .dark .cgpt-expand-bar {
      background: linear-gradient(to bottom, transparent, var(--main-surface-primary, #212121)) !important;
    }
    .cgpt-expand-bar span {
      font-size: 11px !important; color: #888 !important; padding-bottom: 8px !important;
    }
    .cgpt-code-collapsed {
      max-height: 60px !important; overflow: hidden !important;
    }
    .cgpt-code-expand {
      display: block !important; text-align: center !important;
      font-size: 11px !important; color: #888 !important;
      padding: 4px 8px !important; cursor: pointer !important;
      background: rgba(128,128,128,0.1) !important;
      border-radius: 4px !important; margin: 4px 0 !important;
    }
    .cgpt-code-expand:hover {
      background: rgba(128,128,128,0.2) !important;
    }
    """

    private static let archiveCSS = """
    body[data-cgpt-archive-mode='on'] .cgpt-archive-shell {
      border-left: 3px solid rgba(125, 125, 125, 0.30);
      border-radius: 8px;
      margin: 8px 0;
      padding: 8px 12px;
      background: rgba(128, 128, 128, 0.06);
      contain: layout style paint;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-meta {
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.02em;
      text-transform: uppercase;
      color: rgba(120, 120, 120, 0.92);
      margin-bottom: 6px;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-summary {
      white-space: pre-wrap;
      word-break: break-word;
      line-height: 1.4;
      color: inherit;
      opacity: 0.88;
      margin-bottom: 8px;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-toggle {
      border: 0;
      border-radius: 8px;
      padding: 4px 10px;
      font-size: 12px;
      cursor: pointer;
      color: inherit;
      background: rgba(128, 128, 128, 0.18);
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-content {
      margin-top: 10px;
      line-height: 1.45;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-content pre {
      white-space: pre-wrap;
      overflow-x: auto;
      margin: 8px 0;
      padding: 8px;
      border-radius: 8px;
      background: rgba(0, 0, 0, 0.09);
      font-family: ui-monospace, Menlo, Monaco, monospace;
      font-size: 12px;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-content details {
      margin: 8px 0;
      padding: 6px 8px;
      border-radius: 8px;
      background: rgba(128, 128, 128, 0.12);
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-content details > summary {
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
    }
    body[data-cgpt-archive-mode='on'] .cgpt-archive-image {
      font-size: 12px;
      opacity: 0.85;
      margin: 6px 0;
    }
    """

    // Escapes CSS for embedding as a JS string literal inside single quotes.
    private static var cssJSLiteral: String {
        let e = perfCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "'\(e)'"
    }

    private static var archiveCssJSLiteral: String {
        let e = archiveCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "'\(e)'"
    }

    // MARK: - Long-Thread Archive Runtime

    static let archiveRuntime = """
    (function() {
      if (window.cgptArchiveRuntime && window.cgptArchiveRuntime.__version >= 2) { return; }

      var NATIVE = 'native';
      var STYLE_ID = 'cgpt-archive-css';
      var ALLOWED_TAGS = {
        a:1,p:1,div:1,span:1,strong:1,em:1,b:1,i:1,u:1,s:1,code:1,pre:1,
        ul:1,ol:1,li:1,blockquote:1,h1:1,h2:1,h3:1,h4:1,h5:1,h6:1,
        table:1,thead:1,tbody:1,tr:1,th:1,td:1,hr:1,br:1,kbd:1,sup:1,sub:1
      };
      var DROP_TAGS = {script:1,style:1,noscript:1,template:1,svg:1,canvas:1,video:1,audio:1,iframe:1,form:1,input:1,textarea:1,button:1,select:1,option:1};

      function post(type, payload) {
        try {
          if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers[NATIVE]) return;
          window.webkit.messageHandlers[NATIVE].postMessage({ type: type, payload: payload || {} });
        } catch (_) {}
      }
      function now() { return Date.now ? Date.now() : (new Date()).getTime(); }
      function toArray(nl) { return Array.prototype.slice.call(nl || []); }
      function toInt(v, fallback) {
        if (typeof v === 'number' && isFinite(v)) return v | 0;
        if (typeof v === 'string') { var n = parseInt(v, 10); if (!isNaN(n)) return n; }
        return fallback;
      }
      function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
      function nonEmptyStr(v) {
        var s = (v == null) ? '' : String(v);
        return s ? s : '';
      }

      var bootNow = now();
      var state = {
        enabled: false,
        passInFlight: false,
        timer: 0,
        observer: null,
        archiveStore: Object.create(null),
        selectorMethod: 'none',
        selectorDegraded: false,
        selectorFailureCount: 0,
        errorCount: 0,
        restoreFailures: 0,
        lastMutationAt: 0,
        lastPassDurationMs: 0,
        lastPassAt: 0,
        disabledReason: null,
        runtimeState: 'waiting',
        reasonCode: 'startup_grace',
        bootAt: bootNow,
        graceUntil: bootNow + 12000,
        pageReadyConfirmed: false,
        pageReadyAt: 0,
        runtimeFailureTimestamps: [],
        restoreFailureTimestamps: [],
        lastArchivedThisPass: 0,
        options: {
          liveWindow: 5,
          settleMs: 1400,
          recentMutationMs: 2400,
          startupGraceMs: 12000,
          failureWindowMs: 90000,
          degradedRuntimeErrorCount: 2,
          fallbackRuntimeErrorCount: 4,
          degradedRestoreFailureCount: 2,
          fallbackRestoreFailureCount: 4,
          maxCodeInlineLines: 24,
          sanitizeNodeBudget: 5000
        }
      };

      function setRuntimeState(next, reasonCode) {
        state.runtimeState = next;
        state.reasonCode = reasonCode || null;
      }

      function inStartupGrace(ts) {
        var t = ts || now();
        return t < state.graceUntil;
      }

      function detectPageStatus() {
        var main = document.querySelector('main');
        var composer = document.querySelector('textarea:not([disabled]), [data-testid="prompt-textarea"], [contenteditable="true"]');
        var hasMain = !!main;
        var hasComposer = !!composer;
        var hasChatRegion = false;
        if (main) {
          hasChatRegion = !!main.querySelector('[data-testid^="conversation-turn"], article, [class*="react-scroll"], [role="log"], [aria-live]');
        }
        return {
          hasMain: hasMain,
          hasComposer: hasComposer,
          hasChatRegion: hasChatRegion,
          pageReady: hasMain && (hasComposer || hasChatRegion)
        };
      }

      function refreshPageReady(ts) {
        var p = detectPageStatus();
        if (p.pageReady && !state.pageReadyConfirmed) {
          state.pageReadyConfirmed = true;
          state.pageReadyAt = ts || now();
        }
        return p;
      }

      function trimFailureWindow(arr, ts) {
        var windowMs = clamp(toInt(state.options.failureWindowMs, 90000), 10000, 300000);
        var cutoff = (ts || now()) - windowMs;
        while (arr.length && arr[0] < cutoff) arr.shift();
      }

      function noteFailure(arr, ts) {
        var t = ts || now();
        arr.push(t);
        trimFailureWindow(arr, t);
        return arr.length;
      }

      function countFailures(arr, ts) {
        trimFailureWindow(arr, ts || now());
        return arr.length;
      }

      function ensureStyle() {
        try {
          if (document.getElementById(STYLE_ID)) return;
          var s = document.createElement('style');
          s.id = STYLE_ID;
          s.textContent = \(archiveCssJSLiteral);
          (document.head || document.documentElement || document.body).appendChild(s);
        } catch (_) {}
      }

      function findTurnsRaw() {
        var turns = document.querySelectorAll('[data-testid^="conversation-turn"]');
        if (turns.length > 0) return { turns: toArray(turns), method: 'primary' };

        turns = document.querySelectorAll('main article');
        if (turns.length > 0) return { turns: toArray(turns), method: 'article-fallback' };

        var main = document.querySelector('main');
        if (main) {
          var container = main.querySelector('[class*="react-scroll"]') || main.firstElementChild;
          if (container && container.children && container.children.length > 0) {
            var kids = toArray(container.children).filter(function(el) {
              return !!el && el.nodeType === 1 && (!el.getBoundingClientRect || el.getBoundingClientRect().height > 40);
            });
            if (kids.length > 0) return { turns: kids, method: 'container-children' };
          }
        }
        return { turns: [], method: 'none' };
      }

      function isLikelyStreaming() {
        try {
          return !!document.querySelector('[data-testid="stop-button"], button[aria-label*="Stop generating" i], button[aria-label*="Stop" i]');
        } catch (_) { return false; }
      }

      function detectRole(turn, index) {
        try {
          var shellRole = turn.querySelector('.cgpt-archive-shell[data-cgpt-role]');
          if (shellRole) {
            var sr = shellRole.getAttribute('data-cgpt-role') || '';
            if (sr === 'user' || sr === 'assistant') return sr;
          }
          var node = turn.querySelector('[data-message-author-role]');
          if (node) {
            var role = String(node.getAttribute('data-message-author-role') || '').toLowerCase();
            if (role === 'user' || role === 'assistant') return role;
          }
          var testId = String(turn.getAttribute('data-testid') || '');
          var n = parseInt(testId.replace('conversation-turn-', ''), 10);
          if (!isNaN(n)) return (n % 2 === 1) ? 'user' : 'assistant';
        } catch (_) {}
        return (index % 2 === 0) ? 'assistant' : 'user';
      }

      function ensureTurnId(turn, index) {
        var existing = turn.getAttribute('data-cgpt-archive-id');
        if (existing) return existing;
        var testId = turn.getAttribute('data-testid');
        var id = testId ? ('t:' + testId) : ('idx:' + String(index) + ':' + String(Math.random()).slice(2, 8));
        turn.setAttribute('data-cgpt-archive-id', id);
        return id;
      }

      function sanitizeNode(node, budgetRef) {
        if (!node || budgetRef.value <= 0) return null;
        budgetRef.value -= 1;
        if (node.nodeType === 3) return document.createTextNode(node.textContent || '');
        if (node.nodeType !== 1) return null;

        var tag = String(node.tagName || '').toLowerCase();
        if (!tag) return null;
        if (DROP_TAGS[tag]) return null;

        if (tag === 'img') {
          var src = node.getAttribute('src') || '';
          var alt = node.getAttribute('alt') || 'image';
          var box = document.createElement('div');
          box.className = 'cgpt-archive-image';
          if (src) {
            var a = document.createElement('a');
            a.href = src;
            a.target = '_blank';
            a.rel = 'noopener noreferrer';
            a.textContent = alt + ' (open image)';
            box.appendChild(a);
          } else {
            box.textContent = alt;
          }
          return box;
        }

        var outTag = ALLOWED_TAGS[tag] ? tag : 'div';
        var out = document.createElement(outTag);
        if (outTag === 'a') {
          var href = node.getAttribute('href') || '';
          if (href) out.setAttribute('href', href);
          out.setAttribute('target', '_blank');
          out.setAttribute('rel', 'noopener noreferrer');
        }

        var children = node.childNodes;
        for (var i = 0; i < children.length; i++) {
          var clean = sanitizeNode(children[i], budgetRef);
          if (clean) out.appendChild(clean);
          if (budgetRef.value <= 0) break;
        }
        return out;
      }

      function collapseLargeCodeBlocks(container) {
        var maxInline = clamp(toInt(state.options.maxCodeInlineLines, 24), 8, 120);
        var pres = container.querySelectorAll('pre');
        for (var i = 0; i < pres.length; i++) {
          var pre = pres[i];
          var text = pre.textContent || '';
          var lines = text ? text.split('\\n').length : 0;
          if (lines <= maxInline) continue;
          var details = document.createElement('details');
          var summary = document.createElement('summary');
          summary.textContent = 'Show code (' + String(lines) + ' lines)';
          var freshPre = document.createElement('pre');
          var freshCode = document.createElement('code');
          freshCode.textContent = text;
          freshPre.appendChild(freshCode);
          details.appendChild(summary);
          details.appendChild(freshPre);
          pre.parentNode.replaceChild(details, pre);
        }
      }

      function buildSnapshot(turn, role) {
        var source = turn.querySelector('[data-message-author-role]') || turn;
        var budgetRef = { value: clamp(toInt(state.options.sanitizeNodeBudget, 5000), 1000, 20000) };
        var root = document.createElement('div');
        var nodes = source.childNodes && source.childNodes.length > 0 ? source.childNodes : turn.childNodes;
        for (var i = 0; i < nodes.length; i++) {
          var clean = sanitizeNode(nodes[i], budgetRef);
          if (clean) root.appendChild(clean);
          if (budgetRef.value <= 0) break;
        }
        if (!root.childNodes.length) {
          var fallbackText = (turn.innerText || turn.textContent || '').trim();
          if (!fallbackText) return null;
          var p = document.createElement('p');
          p.textContent = fallbackText;
          root.appendChild(p);
        }
        collapseLargeCodeBlocks(root);

        var plain = (root.textContent || '').replace(/\\s+/g, ' ').trim();
        if (!plain && !root.querySelector('a, pre, code')) return null;

        var preview = plain;
        if (preview.length > 220) preview = preview.slice(0, 220) + '…';
        return {
          role: role,
          html: root.innerHTML,
          text: plain,
          preview: preview
        };
      }

      function renderArchivedContent(shell) {
        var turnId = shell.getAttribute('data-cgpt-turn-id') || '';
        if (!turnId) return false;
        var entry = state.archiveStore[turnId];
        if (!entry || !entry.html) return false;

        var content = shell.querySelector('.cgpt-archive-content');
        if (!content) {
          content = document.createElement('div');
          content.className = 'cgpt-archive-content';
          shell.appendChild(content);
        }
        content.innerHTML = entry.html;
        return true;
      }

      function toggleShell(shell, forceExpand) {
        if (!shell) return;
        var expanded = shell.getAttribute('data-cgpt-expanded') === '1';
        if (typeof forceExpand === 'boolean') expanded = !forceExpand;

        var btn = shell.querySelector('.cgpt-archive-toggle');
        if (!expanded) {
          if (!renderArchivedContent(shell)) {
            state.restoreFailures += 1;
            post('archiveDebug', { kind: 'restore_failed', restoreFailures: state.restoreFailures });
            var ts = now();
            if (state.pageReadyConfirmed && !inStartupGrace(ts)) {
              var restoreFailCount = noteFailure(state.restoreFailureTimestamps, ts);
              if (restoreFailCount >= state.options.fallbackRestoreFailureCount) {
                applyDisable('restore_failures');
              } else if (restoreFailCount >= state.options.degradedRestoreFailureCount) {
                setRuntimeState('degraded', 'restore_failures');
              }
            }
            return;
          }
          shell.setAttribute('data-cgpt-expanded', '1');
          if (btn) btn.textContent = 'Collapse archived';
        } else {
          var content = shell.querySelector('.cgpt-archive-content');
          if (content) content.remove();
          shell.setAttribute('data-cgpt-expanded', '0');
          if (btn) btn.textContent = 'Expand archived';
        }
      }

      function buildShell(turnId, snapshot, approxHeight) {
        var shell = document.createElement('div');
        shell.className = 'cgpt-archive-shell';
        shell.setAttribute('data-cgpt-turn-id', turnId);
        shell.setAttribute('data-cgpt-role', snapshot.role || 'assistant');
        shell.setAttribute('data-cgpt-expanded', '0');

        if (approxHeight > 100) {
          shell.style.minHeight = String(Math.min(approxHeight, 220)) + 'px';
        }

        var meta = document.createElement('div');
        meta.className = 'cgpt-archive-meta';
        meta.textContent = 'Archived ' + (snapshot.role || 'turn') + ' turn • static lightweight snapshot';
        shell.appendChild(meta);

        if (snapshot.preview) {
          var summary = document.createElement('div');
          summary.className = 'cgpt-archive-summary';
          summary.textContent = snapshot.preview;
          shell.appendChild(summary);
        }

        var btn = document.createElement('button');
        btn.className = 'cgpt-archive-toggle';
        btn.type = 'button';
        btn.textContent = 'Expand archived';
        btn.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();
          toggleShell(shell);
        });
        shell.appendChild(btn);
        return shell;
      }

      function archiveTurn(turn, index) {
        if (!turn || turn.getAttribute('data-cgpt-archived') === '1') return false;
        var role = detectRole(turn, index);
        var turnId = ensureTurnId(turn, index);
        var snapshot = buildSnapshot(turn, role);
        if (!snapshot) return false;
        state.archiveStore[turnId] = snapshot;

        var h = 0;
        try { h = Math.round(turn.getBoundingClientRect().height || 0); } catch (_) {}
        while (turn.firstChild) turn.removeChild(turn.firstChild);
        turn.setAttribute('data-cgpt-archived', '1');
        turn.setAttribute('data-cgpt-archive-role', role);
        turn.appendChild(buildShell(turnId, snapshot, h));
        return true;
      }

      function collectTelemetry(reason) {
        var page = detectPageStatus();
        var found = findTurnsRaw();
        state.selectorMethod = found.method;
        var turns = found.turns;
        var archived = 0;
        for (var i = 0; i < turns.length; i++) {
          if (turns[i].getAttribute && turns[i].getAttribute('data-cgpt-archived') === '1') archived += 1;
        }
        var live = turns.length - archived;
        if (live < 0) live = 0;
        var shells = document.querySelectorAll('.cgpt-archive-shell').length;
        var main = document.querySelector('main');
        var scrollEl = main;
        if (main) {
          var inner = main.querySelector('[class*="react-scroll"]');
          if (inner) scrollEl = inner;
        }
        if (!scrollEl) scrollEl = document.documentElement;
        var disableReason = nonEmptyStr(state.disabledReason);
        var runtimeDisabled = state.runtimeState === 'fallback' || (!!disableReason && disableReason !== 'native_disable' && disableReason !== 'disabled_by_user' && !state.enabled);

        return {
          totalTurns: turns.length,
          turns: turns.length,
          liveTurns: live,
          archivedTurns: archived,
          archivedShells: shells,
          selectorMethod: state.selectorMethod,
          selectorDegraded: !!state.selectorDegraded,
          selectorFailureCount: state.selectorFailureCount,
          lastPassDurationMs: state.lastPassDurationMs,
          lastPassAt: state.lastPassAt || 0,
          lastArchivedThisPass: state.lastArchivedThisPass || 0,
          passInFlight: !!state.passInFlight,
          archiveEnabled: !!state.enabled,
          enabled: !!state.enabled,
          runtimeAvailable: true,
          runtimeFallback: state.runtimeState === 'fallback',
          runtimeDisabled: runtimeDisabled,
          runtimeDisableReason: disableReason || null,
          runtimeState: state.runtimeState,
          reasonCode: state.reasonCode || null,
          startupGraceActive: inStartupGrace(),
          pageReadyConfirmed: !!state.pageReadyConfirmed,
          pageReadyNow: !!page.pageReady,
          hasComposer: !!page.hasComposer,
          hasChatRegion: !!page.hasChatRegion,
          scrollHeight: scrollEl ? (scrollEl.scrollHeight || 0) : 0,
          hasMain: !!main,
          reason: String(reason || ''),
          errorCount: state.errorCount,
          restoreFailures: state.restoreFailures,
          runtimeErrorBursts: countFailures(state.runtimeFailureTimestamps),
          restoreFailureBursts: countFailures(state.restoreFailureTimestamps)
        };
      }

      function postTelemetry(reason, selectorEvent) {
        var t = collectTelemetry(reason);
        post('archiveTelemetry', t);
        post('archiveCounts', {
          totalTurns: t.totalTurns,
          liveTurns: t.liveTurns,
            archivedTurns: t.archivedTurns,
            archivedShells: t.archivedShells,
            archiveEnabled: t.archiveEnabled,
            runtimeState: t.runtimeState,
            reasonCode: t.reasonCode
          });
        if (selectorEvent) post('archiveSelectorDegraded', t);
        return t;
      }

      function applyDisable(reason) {
        state.enabled = false;
        state.disabledReason = String(reason || 'disabled');
        if (state.disabledReason === 'native_disable' || state.disabledReason === 'disabled_by_user') {
          setRuntimeState('waiting', state.disabledReason);
        } else {
          setRuntimeState('fallback', state.disabledReason);
        }
        if (state.timer) { clearTimeout(state.timer); state.timer = 0; }
        if (state.observer) {
          try { state.observer.disconnect(); } catch (_) {}
          state.observer = null;
        }
        if (document.body) document.body.setAttribute('data-cgpt-archive-mode', 'off');
      }

      function recordError(kind, error, ts) {
        state.errorCount += 1;
        post('archiveDebug', { kind: kind, error: String(error || ''), errorCount: state.errorCount });
        var t = ts || now();
        if (!state.pageReadyConfirmed || inStartupGrace(t)) {
          setRuntimeState('waiting', inStartupGrace(t) ? 'startup_grace' : 'page_not_ready');
          return;
        }
        var runtimeFailCount = noteFailure(state.runtimeFailureTimestamps, t);
        if (runtimeFailCount >= state.options.fallbackRuntimeErrorCount) {
          applyDisable('repeated_runtime_errors');
        } else if (runtimeFailCount >= state.options.degradedRuntimeErrorCount) {
          setRuntimeState('degraded', 'repeated_runtime_errors');
        }
      }

      function runArchivePass(reason) {
        if (!state.enabled) return postTelemetry(reason || 'disabled', false);
        if (state.passInFlight) return collectTelemetry('busy');

        state.passInFlight = true;
        var started = now();
        var selectorEvent = false;
        state.lastArchivedThisPass = 0;

        try {
          var page = refreshPageReady(started);
          var graceActive = inStartupGrace(started);
          if (!state.pageReadyConfirmed) {
            state.selectorDegraded = false;
            state.selectorFailureCount = 0;
            setRuntimeState('waiting', graceActive ? 'startup_grace' : 'page_not_ready');
            schedulePass('grace_retry', 2000);
            return postTelemetry(graceActive ? 'startup_grace' : 'page_not_ready', false);
          }

          if (isLikelyStreaming()) {
            if (graceActive) setRuntimeState('waiting', 'startup_grace');
            schedulePass('streaming_retry', 2000);
            return postTelemetry('streaming', false);
          }

          var found = findTurnsRaw();
          state.selectorMethod = found.method;
          var hasMain = !!page.hasMain;
          var turns = found.turns;
          var emptyChat = turns.length === 0 && page.hasComposer;

          if (emptyChat) {
            state.selectorDegraded = false;
            state.selectorFailureCount = 0;
            setRuntimeState(graceActive ? 'waiting' : 'active', graceActive ? 'startup_grace' : 'empty_chat');
            return postTelemetry('empty_chat', false);
          }

          state.selectorDegraded = (found.method === 'none' && hasMain);
          if (state.selectorDegraded) {
            if (graceActive) {
              state.selectorFailureCount = 0;
              state.selectorDegraded = false;
              setRuntimeState('waiting', 'startup_grace');
              return postTelemetry('startup_grace', false);
            }
            state.selectorFailureCount += 1;
            selectorEvent = true;
            setRuntimeState('degraded', 'selector_degraded');
            return postTelemetry('selector_degraded', true);
          }

          state.selectorFailureCount = 0;
          state.selectorDegraded = false;
          var keep = clamp(toInt(state.options.liveWindow, 5), 4, 6);
          var cutoff = turns.length - keep;
          if (cutoff > 0) {
            for (var i = 0; i < cutoff; i++) {
              if (now() - state.lastMutationAt < state.options.recentMutationMs && i >= cutoff - 1) continue;
              if (archiveTurn(turns[i], i)) state.lastArchivedThisPass += 1;
            }
          }

          if (countFailures(state.runtimeFailureTimestamps, started) >= state.options.degradedRuntimeErrorCount) {
            setRuntimeState('degraded', 'repeated_runtime_errors');
          } else if (countFailures(state.restoreFailureTimestamps, started) >= state.options.degradedRestoreFailureCount) {
            setRuntimeState('degraded', 'restore_failures');
          } else if (graceActive && turns.length === 0) {
            setRuntimeState('waiting', 'startup_grace');
          } else {
            setRuntimeState('active', null);
          }
        } catch (e) {
          recordError('run_pass', e, now());
        } finally {
          state.lastPassDurationMs = Math.max(0, now() - started);
          state.lastPassAt = now();
          state.passInFlight = false;
        }
        return postTelemetry('pass:' + String(reason || 'scheduled'), selectorEvent);
      }

      function schedulePass(reason, delay) {
        if (!state.enabled) return;
        if (state.timer) clearTimeout(state.timer);
        var wait = toInt(delay, state.options.settleMs);
        if (wait < 80) wait = 80;
        state.timer = setTimeout(function() {
          state.timer = 0;
          runArchivePass(reason || 'scheduled');
        }, wait);
      }

      function ensureObserver() {
        if (state.observer) return;
        var target = document.querySelector('main') || document.body || document.documentElement;
        if (!target) return;
        state.observer = new MutationObserver(function(records) {
          state.lastMutationAt = now();
          if (!state.enabled) return;
          if (records && records.length > 0) schedulePass('mutation', state.options.settleMs);
        });
        state.observer.observe(target, { childList: true, subtree: true, characterData: true });
      }

      function mergeOptions(opts) {
        if (!opts || typeof opts !== 'object') return;
        if (opts.liveWindow != null) state.options.liveWindow = clamp(toInt(opts.liveWindow, state.options.liveWindow), 4, 6);
        if (opts.settleMs != null) state.options.settleMs = clamp(toInt(opts.settleMs, state.options.settleMs), 200, 8000);
        if (opts.recentMutationMs != null) state.options.recentMutationMs = clamp(toInt(opts.recentMutationMs, state.options.recentMutationMs), 300, 15000);
        if (opts.startupGraceMs != null) state.options.startupGraceMs = clamp(toInt(opts.startupGraceMs, state.options.startupGraceMs), 8000, 15000);
      }

      var api = {
        __version: 2,
        enable: function(opts) {
          try {
            mergeOptions(opts || {});
            state.errorCount = 0;
            state.restoreFailures = 0;
            state.selectorFailureCount = 0;
            state.disabledReason = null;
            state.runtimeFailureTimestamps = [];
            state.restoreFailureTimestamps = [];
            state.pageReadyConfirmed = false;
            state.pageReadyAt = 0;
            state.bootAt = now();
            state.graceUntil = state.bootAt + clamp(toInt(state.options.startupGraceMs, 12000), 8000, 15000);
            setRuntimeState('waiting', 'startup_grace');
            state.enabled = true;
            if (document.body) document.body.setAttribute('data-cgpt-archive-mode', 'on');
            ensureStyle();
            ensureObserver();
            schedulePass('enable', 180);
            return postTelemetry('startup_grace', false);
          } catch (e) {
            recordError('enable', e, now());
            return postTelemetry('repeated_runtime_errors', false);
          }
        },
        disable: function(reason) {
          applyDisable(reason || 'disabled_by_user');
          return postTelemetry('disabled', false);
        },
        runPassNow: function(reason) {
          return runArchivePass(reason || 'manual');
        },
        expandAll: function() {
          var shells = document.querySelectorAll('.cgpt-archive-shell');
          for (var i = 0; i < shells.length; i++) toggleShell(shells[i], true);
          return postTelemetry('expand_all', false);
        },
        getTelemetry: function(reason) {
          return collectTelemetry(reason || 'query');
        },
        getArchivedText: function(turnId, maxChars) {
          var key = String(turnId || '');
          if (!key) return '';
          var entry = state.archiveStore[key];
          if (!entry) return '';
          var text = String(entry.text || '').trim();
          var lim = toInt(maxChars, 0);
          if (lim > 0 && text.length > lim) text = text.slice(0, lim) + '... [truncated archived]';
          return text;
        }
      };

      window.cgptArchiveRuntime = api;
      ensureStyle();
      post('archiveRuntimeReady', {
        version: 2,
        runtimeAvailable: true,
        runtimeState: 'waiting',
        reasonCode: 'startup_grace',
        runtimeFallback: false,
        runtimeDisabled: false,
        startupGraceActive: true,
        pageReadyConfirmed: false
      });
    })();
    """

    // MARK: - Performance Mode (Cosmetic)

    static let enablePerfMode = """
    (function() {
      try {
        var STYLE_ID = 'cgpt-perf-css';
        if (!document.getElementById(STYLE_ID)) {
          var s = document.createElement('style');
          s.id = STYLE_ID;
          s.textContent = \(cssJSLiteral);
          document.head.appendChild(s);
        }
        if (document.body) document.body.setAttribute('data-cgpt-perf', 'true');
        return JSON.stringify({
          ok: true,
          perfEnabled: true
        });
      } catch(e) {
        return JSON.stringify({
          ok:false,
          error:String(e),
          perfEnabled:false
        });
      }
    })();
    """

    static let disablePerfMode = """
    (function() {
      try {
        var s = document.getElementById('cgpt-perf-css');
        if (s) s.remove();
        if (document.body) document.body.removeAttribute('data-cgpt-perf');

        // Cleanup cosmetic compact helpers (no archiver involvement).
        document.querySelectorAll('.cgpt-compacted').forEach(function(t) { t.classList.remove('cgpt-compacted'); });
        document.querySelectorAll('.cgpt-expand-bar').forEach(function(b) { b.remove(); });
        document.querySelectorAll('.cgpt-code-collapsed').forEach(function(p) { p.classList.remove('cgpt-code-collapsed'); });
        document.querySelectorAll('.cgpt-code-expand').forEach(function(b) { b.remove(); });
        return JSON.stringify({ok:true, perfEnabled:false});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    static let perfCompactOldTurns = """
    (function() {
      try {
        \(helperPreamble)
        var STYLE_ID = 'cgpt-perf-css';
        if (!document.getElementById(STYLE_ID)) {
          var s = document.createElement('style');
          s.id = STYLE_ID;
          s.textContent = \(cssJSLiteral);
          document.head.appendChild(s);
        }
        if (document.body) document.body.setAttribute('data-cgpt-perf', 'true');

        var KEEP = 6;
        var CODE_LINES = 12;
        var turns = cgptFindTurns();
        var compacted = 0;
        if (turns.length > KEEP) {
          for (var i = 0; i < turns.length - KEEP; i++) {
            if (!turns[i].classList.contains('cgpt-compacted')) {
              cgptCompactTurn(turns[i]);
              compacted++;
            }
          }
        }
        var codeCol = 0;
        var pres = document.querySelectorAll('pre');
        for (var j = 0; j < pres.length; j++) {
          var pre = pres[j];
          if (pre.closest('.cgpt-compacted')) continue;
          var lines = (pre.textContent || '').split('\\n').length;
          if (lines > CODE_LINES && !pre.classList.contains('cgpt-code-collapsed')) {
            pre.classList.add('cgpt-code-collapsed');
            var btn = document.createElement('div');
            btn.className = 'cgpt-code-expand';
            btn.textContent = 'Show ' + lines + ' lines';
            btn.onclick = (function(p, b) {
              return function() { p.classList.remove('cgpt-code-collapsed'); b.remove(); };
            })(pre, btn);
            pre.parentNode.insertBefore(btn, pre.nextSibling);
            codeCol++;
          }
        }
        return JSON.stringify({ok:true, compacted:compacted, codeCollapsed:codeCol, totalTurns:turns.length});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    static let perfExpandAll = """
    (function() {
      try {
        document.querySelectorAll('.cgpt-compacted').forEach(function(t) { t.classList.remove('cgpt-compacted'); });
        document.querySelectorAll('.cgpt-expand-bar').forEach(function(b) { b.remove(); });
        document.querySelectorAll('.cgpt-code-collapsed').forEach(function(p) { p.classList.remove('cgpt-code-collapsed'); });
        document.querySelectorAll('.cgpt-code-expand').forEach(function(b) { b.remove(); });
        return JSON.stringify({ok:true});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // MARK: - Archive Mode (Same-Chat Archiver)

    static let enableArchiveMode = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.enable === 'function') {
          window.__cgptArchiveRuntimeMissingCount = 0;
          var telemetry = runtime.enable({liveWindow: 5, settleMs: 1400, recentMutationMs: 2400, startupGraceMs: 12000});
          return JSON.stringify({ok:true, runtimeAvailable:true, telemetry:telemetry});
        }

        var mainReady = !!document.querySelector('main');
        var composerReady = !!document.querySelector('textarea:not([disabled]), [data-testid="prompt-textarea"], [contenteditable="true"]');
        var pageReady = mainReady && composerReady;
        var miss = parseInt(window.__cgptArchiveRuntimeMissingCount || 0, 10);
        if (isNaN(miss) || miss < 0) miss = 0;
        miss += 1;
        window.__cgptArchiveRuntimeMissingCount = miss;
        if (!pageReady || miss < 3) {
          return JSON.stringify({
            ok:true,
            runtimeAvailable:false,
            runtimeFallback:false,
            runtimeDisabled:false,
            runtimeState:'waiting',
            reasonCode: pageReady ? 'startup_grace' : 'page_not_ready'
          });
        }

        return JSON.stringify({
          ok:true,
          runtimeAvailable:false,
          runtimeFallback:true,
          runtimeDisabled:true,
          runtimeState:'fallback',
          reasonCode:'repeated_runtime_errors'
        });
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // MARK: - Disable Archive Mode

    static let disableArchiveMode = """
    (function() {
      try {
        if (document.body) {
          document.body.setAttribute('data-cgpt-archive-mode', 'off');
        }
        window.__cgptArchiveRuntimeMissingCount = 0;
        var runtime = window.cgptArchiveRuntime;
        var telemetry = null;
        if (runtime && typeof runtime.disable === 'function') {
          telemetry = runtime.disable('disabled_by_user');
        }
        return JSON.stringify({ok:true, runtimeAvailable:!!runtime, telemetry:telemetry});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    static let restoreArchivedTurns = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.expandAll === 'function') {
          var telemetry = runtime.expandAll();
          return JSON.stringify({ok:true, runtimeAvailable:true, telemetry:telemetry});
        }
        return JSON.stringify({
          ok:true,
          runtimeAvailable:false,
          runtimeFallback:false,
          runtimeDisabled:false,
          runtimeState:'waiting',
          reasonCode:'page_not_ready'
        });
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    static let getArchiveState = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.getTelemetry === 'function') {
          var telemetry = runtime.getTelemetry('getArchiveState');
          return JSON.stringify({ok:true, runtimeAvailable:true, telemetry:telemetry});
        }
        return JSON.stringify({ok:true, runtimeAvailable:false});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // MARK: - Manual Archive Pass

    static let runArchivePassNow = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.runPassNow === 'function') {
          var telemetry = runtime.runPassNow('native_manual');
          return JSON.stringify({ok:true, runtimeAvailable:true, telemetry:telemetry});
        }
        \(helperPreamble)
        var turns = cgptFindTurns();
        return JSON.stringify({
          ok:true,
          runtimeAvailable:false,
          runtimeFallback:false,
          runtimeDisabled:false,
          runtimeState:'waiting',
          reasonCode:'page_not_ready',
          totalTurns:turns.length
        });
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // MARK: - Expand Archived Turns

    static let expandArchivedTurns = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.expandAll === 'function') {
          var telemetry = runtime.expandAll();
          return JSON.stringify({ok:true, runtimeAvailable:true, telemetry:telemetry});
        }
        return JSON.stringify({
          ok:true,
          runtimeAvailable:false,
          runtimeFallback:false,
          runtimeDisabled:false,
          runtimeState:'waiting',
          reasonCode:'page_not_ready'
        });
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // Backward-compatible names (older callsites expected compact/expand helpers).
    static let compactOldTurns = perfCompactOldTurns
    static let expandAll = perfExpandAll

    // MARK: - Health Check

    static let healthCheck = """
    (function() {
      try {
        var runtime = window.cgptArchiveRuntime;
        if (runtime && typeof runtime.getTelemetry === 'function') {
          var rt = runtime.getTelemetry('healthProbe');
          if (rt && typeof rt === 'object') {
            var mainRt = document.querySelector('main');
            var scrollElRt = mainRt;
            if (mainRt) {
              var innerRt = mainRt.querySelector('[class*="react-scroll"]');
              if (innerRt) scrollElRt = innerRt;
            }
            if (!scrollElRt) scrollElRt = document.documentElement;
            rt.scrollHeight = scrollElRt ? (scrollElRt.scrollHeight || 0) : 0;
            rt.hasMain = !!mainRt;
            return JSON.stringify(rt);
          }
        }

        var primary = document.querySelectorAll('[data-testid^="conversation-turn"]');
        var method = 'none';
        var turns;
        if (primary.length > 0) { turns = primary; method = 'primary'; }
        else {
          var fb = document.querySelectorAll('main article');
          if (fb.length > 0) { turns = fb; method = 'article-fallback'; }
          else { turns = []; }
        }
        var pres = document.querySelectorAll('pre');
        var main = document.querySelector('main');
        var composer = document.querySelector('textarea:not([disabled]), [data-testid="prompt-textarea"], [contenteditable="true"]');
        var archAttr = document.body ? (document.body.getAttribute('data-cgpt-archive-mode') || '') : '';
        var archOn = (archAttr === 'on');
        var fallbackOn = archOn && !runtime;
        var hasComposer = !!composer;
        var pageReady = !!main && (hasComposer || turns.length > 0);
        var reasonCode = pageReady ? (turns.length === 0 && hasComposer ? 'empty_chat' : 'startup_grace') : 'page_not_ready';
        var scrollEl = main;
        if (main) { var inner = main.querySelector('[class*="react-scroll"]'); if (inner) scrollEl = inner; }
        if (!scrollEl) scrollEl = document.documentElement;
        return JSON.stringify({
          totalTurns: turns.length,
          turns: turns.length,
          liveTurns: turns.length,
          archivedTurns: document.querySelectorAll('[data-cgpt-archived="1"]').length,
          archivedShells: document.querySelectorAll('.cgpt-archive-shell').length,
          scrollHeight: scrollEl ? scrollEl.scrollHeight : 0,
          lastPassDurationMs: 0,
          archiveEnabled: false,
          runtimeAvailable: !!runtime,
          runtimeFallback: fallbackOn,
          runtimeDisabled: fallbackOn,
          runtimeState: fallbackOn ? 'fallback' : 'waiting',
          reasonCode: fallbackOn ? 'repeated_runtime_errors' : reasonCode,
          startupGraceActive: archOn && !fallbackOn,
          pageReadyConfirmed: pageReady,
          hasComposer: hasComposer,
          runtimeDisableReason: null,
          selectorDegraded: (!fallbackOn && method === 'none' && !!main && !hasComposer),
          selectorMethod: method,
          hasMain: !!main,
          codeBlocks: pres.length
        });
      } catch(e) {
        return JSON.stringify({
          totalTurns:0,
          turns:0,
          liveTurns:0,
          archivedTurns:0,
          archivedShells:0,
          scrollHeight:0,
          lastPassDurationMs:0,
          archiveEnabled:false,
          runtimeAvailable:false,
          runtimeFallback:false,
          runtimeDisabled:false,
          runtimeState:'waiting',
          reasonCode:'page_not_ready',
          selectorMethod:'error',
          selectorDegraded:false,
          hasMain:false,
          hasComposer:false,
          startupGraceActive:true,
          pageReadyConfirmed:false,
          error:String(e)
        });
      }
    })();
    """

    // MARK: - Continuity Extraction

    static let continuityExtract = """
    (function() {
      try {
        var MAX_T = 8, MAX_C = 1500;
        var title = document.title || '';
        title = title.replace(/^ChatGPT\\s*[-\\u2014|]\\s*/, '').replace(/\\s*[-\\u2014|]\\s*ChatGPT$/, '').trim();
        if (!title || title === 'ChatGPT') title = 'Ongoing conversation';
        var turnEls = document.querySelectorAll('[data-testid^="conversation-turn"]');
        var sm = 'primary';
        if (turnEls.length === 0) {
          turnEls = document.querySelectorAll('main article');
          sm = turnEls.length > 0 ? 'article-fallback' : 'none';
        }
        var turns = Array.from(turnEls);
        var recent = turns.slice(-MAX_T);

        function detectRole(turn, index) {
          var shell = turn.querySelector('.cgpt-archive-shell[data-cgpt-role]');
          if (shell) {
            var sr = String(shell.getAttribute('data-cgpt-role') || '').toLowerCase();
            if (sr === 'user' || sr === 'assistant') return sr;
          }
          var roleNode = turn.querySelector('[data-message-author-role]');
          if (roleNode) {
            var rr = String(roleNode.getAttribute('data-message-author-role') || '').toLowerCase();
            if (rr === 'user' || rr === 'assistant') return rr;
          }
          var tid = turn.getAttribute('data-testid') || '';
          var num = parseInt(tid.replace('conversation-turn-', ''), 10);
          if (!isNaN(num)) return (num % 2 === 1) ? 'user' : 'assistant';
          return (index % 2 === 0) ? 'assistant' : 'user';
        }

        function turnText(turn) {
          var shell = turn.querySelector('.cgpt-archive-shell[data-cgpt-turn-id]');
          if (shell && window.cgptArchiveRuntime && typeof window.cgptArchiveRuntime.getArchivedText === 'function') {
            var key = shell.getAttribute('data-cgpt-turn-id') || '';
            if (key) {
              try {
                var archivedText = window.cgptArchiveRuntime.getArchivedText(key, MAX_C);
                if (archivedText && String(archivedText).trim().length > 0) return String(archivedText).trim();
              } catch (_) {}
            }
          }
          var expanded = shell ? shell.querySelector('.cgpt-archive-content') : null;
          var text = expanded ? (expanded.innerText || expanded.textContent || '') : (turn.innerText || turn.textContent || '');
          text = (text || '').trim();
          if (text.length > MAX_C) text = text.substring(0, MAX_C) + '... [truncated]';
          return text;
        }

        var extracted = recent.map(function(t, idx) {
          var text = turnText(t);
          var role = detectRole(t, idx);
          return (role === 'user' ? 'USER' : 'ASSISTANT') + ':\\n' + text;
        });
        var total = turns.length;
        var b = "I'm continuing a conversation from a previous chat (" + total + " turns). Here's the recent context:\\n\\n";
        b += "Topic: " + title + "\\n\\n";
        b += "Recent conversation (last " + recent.length + " of " + total + " turns):\\n\\n";
        b += extracted.join('\\n\\n---\\n\\n');
        b += "\\n\\nPlease continue helping me with this. Pick up where we left off.";
        return JSON.stringify({ok:true, bundle:b, topic:title, totalTurns:total, extractedTurns:recent.length, selectorMethod:sm});
      } catch(e) {
        return JSON.stringify({ok:false, error:String(e), bundle:''});
      }
    })();
    """

    // MARK: - Project Scope Probe (Best-Effort)

    // Detect whether the current page is a chat inside a Project.
    // Multi-signal, confidence-scored, and diagnosable. Low-confidence results should be treated as "unknown".
    static let projectScopeProbe = """
    (function() {
      try {
        var url = String(location.href || '');
        var signals = [];
        var score = 0.0;

        function add(name, weight, evidence) {
          score += weight;
          signals.push({name: name, weight: weight, evidence: String(evidence || '')});
        }

        var u;
        try { u = new URL(url); } catch (e) { u = { origin: '', pathname: '' , searchParams: { get: function(){ return null; } } }; }
        var origin = String(u.origin || '');
        var path = String(u.pathname || '');

        var projectId = null;
        var projectBase = null;

        var m = path.match(/\\/(?:p)\\/([^\\/?#]+)/);
        if (m && m[1]) {
          projectId = String(m[1]);
          projectBase = origin + '/p/' + projectId;
          add('url:/p/:id', 0.85, projectBase);
        } else {
          m = path.match(/\\/(?:project)\\/([^\\/?#]+)/);
          if (m && m[1]) {
            projectId = String(m[1]);
            projectBase = origin + '/project/' + projectId;
            add('url:/project/:id', 0.85, projectBase);
          }
        }

        var qp = null;
        try { qp = u.searchParams && u.searchParams.get ? u.searchParams.get('project') : null; } catch (e) { qp = null; }
        if (!projectId && qp) {
          projectId = String(qp);
          projectBase = origin + '/p/' + projectId;
          add('url:?project=', 0.60, projectBase);
        }

        // Weak DOM signals (kept low weight to avoid false positives).
        if (projectBase) {
          var link = document.querySelector('a[href^=\"' + projectBase + '\"]');
          if (link) add('dom:link_to_projectBase', 0.10, link.getAttribute('href') || '');
        } else {
          var aP = document.querySelector('a[href*=\"/p/\"]');
          if (aP) add('dom:any_/p/_link', 0.12, aP.getAttribute('href') || '');
          var ariaProj = document.querySelector('[aria-label*=\"Project\" i], [aria-label*=\"Projects\" i]');
          if (ariaProj) add('dom:aria_project', 0.10, ariaProj.getAttribute('aria-label') || '');
        }

        var confidence = score >= 0.85 ? 'high' : (score >= 0.55 ? 'medium' : 'low');
        var scope = projectId ? 'project' : 'non-project';

        return JSON.stringify({
          ok: true,
          url: url,
          origin: origin,
          path: path,
          scope: scope,
          projectId: projectId,
          projectBase: projectBase,
          score: score,
          confidence: confidence,
          signals: signals
        });
      } catch (e) {
        return JSON.stringify({ok:false, error:String(e)});
      }
    })();
    """

    // MARK: - Project New Chat Attempt (Best-Effort)

    // Attempts to click an in-scope "New chat" control.
    // This is intentionally generic and low-impact; native code must validate and fallback if needed.
    static let projectNewChatClick = """
    (function() {
      try {
        function isUsable(el) {
          if (!el) return false;
          if (el.disabled) return false;
          var ad = el.getAttribute && el.getAttribute('aria-disabled');
          if (ad === 'true') return false;
          if (el.getClientRects && el.getClientRects().length === 0) return false;
          var cs = window.getComputedStyle ? window.getComputedStyle(el) : null;
          if (cs && (cs.visibility === 'hidden' || cs.display === 'none')) return false;
          return true;
        }

        var before = String(location.href || '');
        var tried = [];

        var candidates = [
          'a[aria-label*=\"New chat\" i]',
          'button[aria-label*=\"New chat\" i]',
          'a[aria-label*=\"New conversation\" i]',
          'button[aria-label*=\"New conversation\" i]',
          'a[href][data-testid*=\"new\" i]',
          'button[data-testid*=\"new\" i]'
        ];

        var el = null;
        var sel = '';
        for (var i = 0; i < candidates.length; i++) {
          sel = candidates[i];
          tried.push(sel);
          var c = document.querySelector(sel);
          if (isUsable(c)) { el = c; break; }
        }

        if (!el) {
          return JSON.stringify({ok:true, clicked:false, before:before, tried:tried});
        }

        var tag = (el.tagName || '').toLowerCase();
        var href = (tag === 'a' && el.getAttribute) ? (el.getAttribute('href') || '') : '';
        var aria = (el.getAttribute && (el.getAttribute('aria-label') || '')) || '';

        el.click();
        return JSON.stringify({ok:true, clicked:true, before:before, selector:sel, tag:tag, href:href, ariaLabel:aria});
      } catch (e) {
        return JSON.stringify({ok:false, error:String(e)});
      }
    })();
    """

    // MARK: - Continuity Prefill Guard

    // Determines if the current page looks like an empty/fresh chat surface (safe for silent prefill).
    static let continuityPrefillGuard = """
    (function() {
      try {
        var primary = document.querySelectorAll('[data-testid^=\"conversation-turn\"]');
        var method = 'none';
        var turns = 0;
        if (primary.length > 0) { turns = primary.length; method = 'primary'; }
        else {
          var fb = document.querySelectorAll('main article');
          if (fb.length > 0) { turns = fb.length; method = 'article-fallback'; }
        }
        var hasEditor = !!document.querySelector('textarea:not([disabled])') || !!document.querySelector('[contenteditable=\"true\"]');
        return JSON.stringify({ok:true, turns:turns, selectorMethod:method, hasEditor:hasEditor, url:String(location.href||'')});
      } catch(e) { return JSON.stringify({ok:false, error:String(e)}); }
    })();
    """

    // MARK: - Jump to Bottom

    static let jumpToBottom = """
    (function() {
      try {
        var main = document.querySelector('main');
        if (main) {
          var inner = main.querySelector('[class*="react-scroll"]');
          (inner || main).scrollTop = (inner || main).scrollHeight;
        }
        window.scrollTo(0, document.body.scrollHeight);
        return true;
      } catch(e) { return false; }
    })();
    """

    // MARK: - Feature Probe

    static let featureProbe = """
    (function() {
      try {
        var r = {};
        var p = document.querySelectorAll('[data-testid^="conversation-turn"]');
        r.turnsPrimary = p.length;
        var fb = document.querySelectorAll('main article');
        r.turnsFallback = fb.length;
        r.turnMethod = p.length > 0 ? 'primary' : (fb.length > 0 ? 'article-fallback' : 'none');
        r.hasMain = !!document.querySelector('main');
        var main = document.querySelector('main');
        r.hasScrollContainer = main ? !!main.querySelector('[class*="react-scroll"]') : false;
        r.hasTextarea = !!document.querySelector('textarea:not([disabled])');
        r.hasContentEditable = !!document.querySelector('[contenteditable="true"]');
        r.editorMethod = r.hasTextarea ? 'textarea' : (r.hasContentEditable ? 'contenteditable' : 'none');
        r.codeBlocks = document.querySelectorAll('pre').length;
        r.hasPerfCSS = !!document.getElementById('cgpt-perf-css');
        r.hasPerfAttr = document.body ? document.body.hasAttribute('data-cgpt-perf') : false;
        r.hasHelpers = typeof window.cgptFindTurns === 'function';
        r.archiveRuntime = !!(window.cgptArchiveRuntime && typeof window.cgptArchiveRuntime.getTelemetry === 'function');
        r.archiveModeAttr = document.body ? (document.body.getAttribute('data-cgpt-archive-mode') || '') : '';
        r.archivedTurns = document.querySelectorAll('[data-cgpt-archived="1"]').length;
        r.archivedShells = document.querySelectorAll('.cgpt-archive-shell').length;
        if (r.archiveRuntime) {
          try {
            var t = window.cgptArchiveRuntime.getTelemetry('featureProbe');
            r.archiveEnabled = !!(t && t.archiveEnabled);
            r.archiveSelectorMethod = t && t.selectorMethod ? t.selectorMethod : 'unknown';
            r.archiveSelectorDegraded = !!(t && t.selectorDegraded);
            r.archiveRuntimeState = t && t.runtimeState ? String(t.runtimeState) : 'unknown';
            r.archiveReasonCode = t && t.reasonCode ? String(t.reasonCode) : '';
            r.archiveStartupGrace = !!(t && t.startupGraceActive);
            r.archivePageReady = !!(t && t.pageReadyConfirmed);
            r.archiveRuntimeDisabled = !!(t && t.runtimeDisabled);
            r.archiveRuntimeReason = t && t.runtimeDisableReason ? String(t.runtimeDisableReason) : '';
          } catch (e) {
            r.archiveProbeError = String(e);
          }
        } else {
          r.archiveEnabled = false;
          r.archiveSelectorMethod = 'none';
          r.archiveSelectorDegraded = false;
          r.archiveRuntimeState = 'waiting';
          r.archiveReasonCode = '';
          r.archiveStartupGrace = false;
          r.archivePageReady = false;
          r.archiveRuntimeDisabled = false;
          r.archiveRuntimeReason = '';
        }
        r.url = location.href;
        r.isChatPage = /chatgpt\\.com/.test(location.href);
        return JSON.stringify(r);
      } catch(e) { return JSON.stringify({error: String(e)}); }
    })();
    """
}
