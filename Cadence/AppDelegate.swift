import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var coordinator: AppCoordinator!
    private var reckoningWindowController: ReckoningWindowController?
    private var historyWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator()

        // Status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let root = PopoverRoot()
            .environmentObject(coordinator)
        let hosting = NSHostingController(rootView: root)
        // Let SwiftUI's intrinsic content size drive the popover size — otherwise
        // the popover reserves a fixed-height frame and content sits at the top
        // with empty space below, creating a gap to the menu bar.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        // Notifications
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        NotificationHandler.shared.requestAuthorization()
        NotificationHandler.shared.registerCategories()

        // Connect coordinator callbacks
        coordinator.onMenuBarLabelChanged = { [weak self] in
            self?.refreshMenuBarLabel()
        }
        coordinator.onShowReckoning = { [weak self] in
            self?.showReckoningWindow()
        }
        coordinator.onShowPopover = { [weak self] in
            self?.showPopoverProgrammatically()
        }

        // Initial state
        coordinator.bootstrap()
        refreshMenuBarLabel()

        // Build menu (right-click on status item)
        buildStatusItemMenu()
    }

    private func buildStatusItemMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "History…", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Cadence", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        // We attach the menu only to right-clicks via the action handler below.
        statusItem.menu = nil
        // We'll handle right-click manually:
        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.contextMenu = menu
    }

    private var contextMenu: NSMenu?

    @objc func togglePopover(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            doToggle()
            return
        }
        if event.type == .rightMouseUp, let menu = contextMenu, let button = statusItem.button {
            statusItem.menu = menu
            button.performClick(nil)
            // Reset so left-clicks don't open the menu next time.
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
            return
        }
        doToggle()
    }

    private func doToggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Re-evaluate state when opening (handles day rollover)
            coordinator.refreshState()
            if let button = statusItem.button {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func showPopoverProgrammatically() {
        if !popover.isShown, let button = statusItem.button {
            coordinator.refreshState()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showReckoningWindow() {
        if reckoningWindowController == nil {
            reckoningWindowController = ReckoningWindowController(coordinator: coordinator) { [weak self] in
                self?.reckoningWindowController?.close()
                self?.reckoningWindowController = nil
                self?.refreshMenuBarLabel()
            }
        }
        reckoningWindowController?.showWindow(nil)
    }

    @objc func showHistory() {
        if historyWindowController == nil {
            let vc = NSHostingController(rootView: HistoryView().environmentObject(coordinator))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Cadence — History"
            window.center()
            window.contentViewController = vc
            window.minSize = NSSize(width: 560, height: 480)
            window.isReleasedWhenClosed = false
            historyWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        historyWindowController?.showWindow(nil)
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            let vc = NSHostingController(rootView: SettingsView().environmentObject(coordinator))
            // Let SwiftUI's intrinsic content size drive the window. The view has a fixed
            // width and self-sizing height, so the window will hug the content exactly.
            vc.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: vc)
            window.styleMask = [.titled, .closable]
            window.title = "Cadence — Settings"
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    func refreshMenuBarLabel() {
        guard let button = statusItem.button else { return }

        // Show the progress icon only when there's an active locked plan or all
        // tasks are done. In other states (no plan yet, reckoning, missed) the
        // half-sun has no progress to report, so we fall back to text-only.
        let progress = coordinator.menuBarProgress()
        if let progress = progress {
            button.image = MenuBarIconRenderer.icon(done: progress.done, total: progress.total)
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }

        let (icon, text) = coordinator.menuBarText()
        let attr = NSMutableAttributedString()
        if let icon = icon {
            attr.append(NSAttributedString(string: icon + " "))
        }
        attr.append(NSAttributedString(string: text))
        button.attributedTitle = attr
    }
}
