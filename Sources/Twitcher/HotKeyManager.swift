import Carbon.HIToolbox
import Foundation

private nonisolated(unsafe) let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        manager.handle(id: hotKeyID.id)
    }
    return noErr
}

@MainActor
final class HotKeyManager {
    private static let signature: OSType = 0x5457_4348 // TWCH
    private var references: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(chooser: @escaping () -> Void, letters: [Character], activate: @escaping (Character) -> Void) {
        references.forEach { _ = UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()

        register(id: 1, keyCode: UInt32(kVK_Delete), action: chooser)
        for letter in letters {
            guard let keyCode = Self.keyCodes[letter] else { continue }
            let id = UInt32(letter.asciiValue ?? 0) + 100
            register(id: id, keyCode: keyCode) { activate(letter) }
        }
    }

    fileprivate func handle(id: UInt32) {
        actions[id]?()
    }

    private func register(id: UInt32, keyCode: UInt32, action: @escaping () -> Void) {
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(keyCode, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference {
            references.append(reference)
            actions[id] = action
        }
    }

    private static let keyCodes: [Character: UInt32] = [
        "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
    ]
}
