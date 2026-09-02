import AppKit
import TwitcherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service = WindowService()
    private let store = AssignmentStore()
    private let hotKeys = HotKeyManager()
    private var chooser: ChooserWindowController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        chooser = ChooserWindowController(service: service, store: store) { [weak self] in
            self?.registerHotKeys()
        }
        configureStatusItem()
        registerHotKeys()
        if !service.isAccessibilityGranted() {
            _ = service.requestAccessibilityPermission()
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Twitcher")

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Programs", action: #selector(showChooser), keyEquivalent: "")
        menu.addItem(withTitle: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear Assignments", action: #selector(clearAssignments), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Twitcher", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func registerHotKeys() {
        let letters = store.load().assignments.keys.compactMap(\.first)
        hotKeys.register(
            chooser: { [weak self] in self?.toggleChooser() },
            letters: letters,
            activate: { [weak self] letter in self?.activate(letter: letter) }
        )
    }

    private func toggleChooser() {
        if chooser.window?.isVisible == true, NSApp.isActive {
            chooser.close()
        } else {
            showChooser()
        }
    }

    @objc private func showChooser() {
        guard service.isAccessibilityGranted() else {
            showPermissionAlert()
            return
        }
        chooser.show()
    }

    @objc private func openAccessibilitySettings() {
        service.openAccessibilitySettings()
    }

    @objc private func clearAssignments() {
        store.save(AssignmentBook())
        registerHotKeys()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func activate(letter: Character) {
        let book = store.load()
        guard let target = book.target(for: letter) else {
            NSSound.beep()
            return
        }

        switch target {
        case let .program(identity):
            guard let program = service.matchingProgram(for: identity) else {
                NSSound.beep()
                return
            }
            let assignedWindows = book.windowIdentities(for: identity)
            if !service.cycleWindows(in: program, excluding: assignedWindows) {
                NSSound.beep()
            }
        case let .window(identity):
            guard let window = service.matchingWindow(for: identity) else {
                NSSound.beep()
                return
            }
            service.focus(window)
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Twitcher needs Accessibility access"
        alert.informativeText = "Enable Twitcher in Privacy & Security > Accessibility. If it is already enabled, remove the existing Twitcher entry, add this copy again, then relaunch Twitcher."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            service.openAccessibilitySettings()
        }
    }
}
