import Cocoa

// MARK: - Main Menu

extension AppDelegate {
    func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About ChatEnhancer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide ChatEnhancer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let ho = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        ho.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ChatEnhancer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // Edit menu
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        // View menu
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let pm = viewMenu.addItem(withTitle: "Toggle Performance Mode", action: #selector(togglePerformanceMode(_:)), keyEquivalent: "p")
        pm.keyEquivalentModifierMask = [.command, .shift]
        let am = viewMenu.addItem(withTitle: "Archive Mode: Off", action: #selector(toggleArchiveMode(_:)), keyEquivalent: "a")
        am.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        let ck = viewMenu.addItem(withTitle: "Compact Old Turns", action: #selector(compactOldTurns(_:)), keyEquivalent: "k")
        ck.keyEquivalentModifierMask = [.command, .shift]
        let ea = viewMenu.addItem(withTitle: "Expand All Turns", action: #selector(expandAllTurns(_:)), keyEquivalent: "e")
        ea.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(.separator())
        let jb = NSMenuItem(title: "Jump to Bottom", action: #selector(jumpToBottom(_:)), keyEquivalent: "")
        jb.keyEquivalent = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        jb.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(jb)
        viewMenu.addItem(withTitle: "Focus Input", action: #selector(focusInput(_:)), keyEquivalent: "l")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Refresh", action: #selector(refreshPage(_:)), keyEquivalent: "r")
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        // Tools menu
        let toolsItem = NSMenuItem()
        let toolsMenu = NSMenu(title: "Tools")
        let fc = toolsMenu.addItem(withTitle: "Continue in Fresh Chat", action: #selector(continueInFreshChat(_:)), keyEquivalent: "n")
        fc.keyEquivalentModifierMask = [.command, .shift]
        toolsMenu.addItem(withTitle: "Copy Continuity Bundle", action: #selector(copyContinuityBundle(_:)), keyEquivalent: "b")
        toolsMenu.addItem(.separator())
        toolsMenu.addItem(withTitle: "Thread Health Details", action: #selector(showHealthDetails(_:)), keyEquivalent: "")
        toolsMenu.addItem(withTitle: "Feature Diagnostics…", action: #selector(showDiagnostics(_:)), keyEquivalent: "")
        toolsItem.submenu = toolsMenu
        mainMenu.addItem(toolsItem)

        // Window menu
        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = winMenu
        mainMenu.addItem(winItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = winMenu
    }
}

// MARK: - Toolbar Delegate

extension AppDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            Self.healthItem,
            Self.perfModeItem,
            Self.archiveItem,
            Self.continueItem,
            Self.jumpBottomItem,
            Self.refreshItem,
            .flexibleSpace
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.healthItem, Self.perfModeItem, Self.archiveItem, Self.continueItem, Self.jumpBottomItem, Self.refreshItem]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        switch id {
        case Self.refreshItem:
            item.label = "Refresh"; item.toolTip = "Refresh page (⌘R)"
            if #available(macOS 11.0, *) { item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh") }
            item.target = self; item.action = #selector(refreshPage(_:))
        case Self.perfModeItem:
            item.label = "Performance"
            item.toolTip = performanceModeEnabled ? "Performance Mode ON (⌘⇧P)" : "Performance Mode OFF (⌘⇧P)"
            if #available(macOS 11.0, *) {
                item.image = NSImage(systemSymbolName: performanceModeEnabled ? "bolt.fill" : "bolt", accessibilityDescription: "Performance Mode")
            }
            item.target = self; item.action = #selector(togglePerformanceMode(_:))
        case Self.archiveItem:
            item.label = "Archive"
            item.toolTip = archiveToolbarTooltip()
            if #available(macOS 11.0, *) {
                item.image = NSImage(systemSymbolName: archiveToolbarSymbolName(), accessibilityDescription: "Archive Mode")
            }
            item.target = self; item.action = #selector(toggleArchiveMode(_:))
        case Self.healthItem:
            item.label = "Health"; item.toolTip = "Thread Health: \(threadHealth.label)"
            if #available(macOS 11.0, *) { item.image = NSImage(systemSymbolName: threadHealth.symbolName, accessibilityDescription: threadHealth.label) }
            item.target = self; item.action = #selector(showHealthDetails(_:))
        case Self.continueItem:
            item.label = "Fresh Chat"; item.toolTip = "Continue in Fresh Chat (⌘⇧N)"
            if #available(macOS 11.0, *) { item.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Fresh Chat") }
            item.target = self; item.action = #selector(continueInFreshChat(_:))
        case Self.jumpBottomItem:
            item.label = "Bottom"; item.toolTip = "Jump to bottom (⌘↓)"
            if #available(macOS 11.0, *) { item.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Bottom") }
            item.target = self; item.action = #selector(jumpToBottom(_:))
        default:
            return nil
        }
        return item
    }

    func updateToolbarItem(_ identifier: NSToolbarItem.Identifier) {
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items where item.itemIdentifier == identifier {
            switch identifier {
            case Self.perfModeItem:
                item.toolTip = performanceModeEnabled ? "Performance Mode ON (⌘⇧P)" : "Performance Mode OFF (⌘⇧P)"
                if #available(macOS 11.0, *) {
                    item.image = NSImage(systemSymbolName: performanceModeEnabled ? "bolt.fill" : "bolt", accessibilityDescription: "Performance Mode")
                }
            case Self.archiveItem:
                item.toolTip = archiveToolbarTooltip()
                if #available(macOS 11.0, *) {
                    item.image = NSImage(systemSymbolName: archiveToolbarSymbolName(), accessibilityDescription: "Archive Mode")
                }
            case Self.healthItem:
                item.toolTip = "Thread Health: \(threadHealth.label)"
                if #available(macOS 11.0, *) { item.image = NSImage(systemSymbolName: threadHealth.symbolName, accessibilityDescription: threadHealth.label) }
            default: break
            }
        }
    }

    private func archiveToolbarTooltip() -> String {
        "Archive Mode: \(archiveModeStateLabel())"
    }

    private func archiveToolbarSymbolName() -> String {
        switch archiveModeStateLabel() {
        case "Off": return "archivebox"
        case "On": return "archivebox.fill"
        case "Degraded": return "exclamationmark.triangle"
        case "Fallback": return "exclamationmark.triangle.fill"
        default: return "archivebox"
        }
    }
}
