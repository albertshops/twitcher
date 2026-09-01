import AppKit
import ApplicationServices
import TwitcherCore

struct ManagedWindow {
    let element: AXUIElement
    let application: NSRunningApplication
    let title: String
    let documentURL: String?
    let isMinimized: Bool
    let ordinal: Int

    var identity: WindowIdentity {
        WindowIdentity(
            bundleIdentifier: application.bundleIdentifier ?? "pid:\(application.processIdentifier)",
            title: title,
            documentURL: documentURL
        )
    }

    var runtimeID: String {
        "\(application.processIdentifier):\(ordinal):\(title)"
    }
}

@MainActor
final class WindowService {
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

    func windows() -> [ManagedWindow] {
        guard isAccessibilityGranted() else { return [] }

        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap(windows(for:))
            .sorted {
                let left = ($0.application.localizedName ?? "", $0.title)
                let right = ($1.application.localizedName ?? "", $1.title)
                return left < right
            }
    }

    func matchingWindow(for identity: WindowIdentity) -> ManagedWindow? {
        let matches = windows().filter { identity.matches($0.identity) }
        return matches.count == 1 ? matches[0] : nil
    }

    func focus(_ window: ManagedWindow) {
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

        return elements.enumerated().compactMap { ordinal, element in
            let role: String? = attribute(kAXRoleAttribute, from: element)
            let subrole: String? = attribute(kAXSubroleAttribute, from: element)
            guard role == kAXWindowRole,
                  subrole == nil || subrole == kAXStandardWindowSubrole
            else { return nil }

            let rawTitle: String = attribute(kAXTitleAttribute, from: element) ?? ""
            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Window" : rawTitle
            let documentURL: String? = attribute(kAXDocumentAttribute, from: element)
            let minimized: Bool = attribute(kAXMinimizedAttribute, from: element) ?? false
            return ManagedWindow(
                element: element,
                application: application,
                title: title,
                documentURL: documentURL,
                isMinimized: minimized,
                ordinal: ordinal
            )
        }
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
