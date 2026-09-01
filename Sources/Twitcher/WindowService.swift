import AppKit
import ApplicationServices
import TwitcherCore

struct ManagedWindow {
    let element: AXUIElement
    let application: NSRunningApplication
    let title: String
    let isMinimized: Bool
}

struct ManagedProgram {
    let application: NSRunningApplication
    let windows: [ManagedWindow]

    var identity: ProgramIdentity {
        ProgramIdentity(
            bundleIdentifier: application.bundleIdentifier ?? "pid:\(application.processIdentifier)",
            name: application.localizedName ?? "Unknown Application"
        )
    }
}

@MainActor
final class WindowService {
    private var cycleOrders: [String: [AXUIElement]] = [:]

    func requestAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func programs() -> [ManagedProgram] {
        guard isAccessibilityGranted() else { return [] }

        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .compactMap { application in
                let windows = windows(for: application)
                return windows.isEmpty ? nil : ManagedProgram(application: application, windows: windows)
            }
            .sorted { $0.identity.name.localizedCaseInsensitiveCompare($1.identity.name) == .orderedAscending }
    }

    func matchingProgram(for identity: ProgramIdentity) -> ManagedProgram? {
        let matches = programs().filter { identity.matches($0.identity) }
        return matches.count == 1 ? matches[0] : nil
    }

    func cycleWindows(in program: ManagedProgram) {
        guard !program.windows.isEmpty else { return }
        let windows = windowsInCycleOrder(for: program)
        let appElement = AXUIElementCreateApplication(program.application.processIdentifier)
        let focusedWindow: AXUIElement? = attribute(kAXFocusedWindowAttribute, from: appElement)
        let focusedIndex = focusedWindow.flatMap { focused in
            windows.firstIndex { CFEqual($0.element, focused) }
        }
        let targetIndex: Int
        if program.application.isActive, let focusedIndex {
            targetIndex = (focusedIndex + 1) % windows.count
        } else {
            targetIndex = focusedIndex ?? 0
        }
        focus(windows[targetIndex])
    }

    private func windowsInCycleOrder(for program: ManagedProgram) -> [ManagedWindow] {
        let key = program.identity.bundleIdentifier
        var order = cycleOrders[key, default: []].filter { saved in
            program.windows.contains { CFEqual($0.element, saved) }
        }
        for window in program.windows where !order.contains(where: { CFEqual($0, window.element) }) {
            order.append(window.element)
        }
        cycleOrders[key] = order
        return order.compactMap { saved in
            program.windows.first { CFEqual($0.element, saved) }
        }
    }

    private func focus(_ window: ManagedWindow) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        window.application.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(
            AXUIElementCreateApplication(window.application.processIdentifier),
            kAXFocusedWindowAttribute as CFString,
            window.element
        )
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    private func windows(for application: NSRunningApplication) -> [ManagedWindow] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let elements: [AXUIElement] = attribute(kAXWindowsAttribute, from: appElement) else { return [] }

        return elements.compactMap { element in
            let role: String? = attribute(kAXRoleAttribute, from: element)
            let subrole: String? = attribute(kAXSubroleAttribute, from: element)
            guard role == kAXWindowRole,
                  subrole == nil || subrole == kAXStandardWindowSubrole
            else { return nil }

            let rawTitle: String = attribute(kAXTitleAttribute, from: element) ?? ""
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Window" : rawTitle
            let minimized: Bool = attribute(kAXMinimizedAttribute, from: element) ?? false
            return ManagedWindow(
                element: element,
                application: application,
                title: title,
                isMinimized: minimized
            )
        }
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
