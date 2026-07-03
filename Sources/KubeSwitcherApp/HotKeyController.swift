import AppKit
import Carbon
import KubeSwitcherCore

final class HotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void
    private var preference: HotKeyPreference
    private(set) var registrationError: String?

    init(preference: HotKeyPreference, action: @escaping () -> Void) {
        self.preference = preference
        self.action = action
        register()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func update(preference: HotKeyPreference) {
        self.preference = preference
        unregisterHotKey()
        registerHotKey()
    }

    private func register() {
        installEventHandler()
        guard eventHandler != nil else { return }
        registerHotKey()
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                controller.action()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        if handlerStatus != noErr {
            registrationError = "InstallEventHandler failed with OSStatus \(handlerStatus)"
            return
        }
    }

    private func registerHotKey() {
        registrationError = nil
        guard let keyCode = Self.keyCode(for: preference.key) else {
            registrationError = "Unsupported hotkey key: \(preference.key)"
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4b535748), id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            Self.carbonModifiers(for: preference.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if hotKeyStatus != noErr {
            registrationError = "\(preference.displayText) hotkey registration failed with OSStatus \(hotKeyStatus)"
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private static func carbonModifiers(for modifiers: [HotKeyModifier]) -> UInt32 {
        modifiers.reduce(UInt32(0)) { flags, modifier in
            switch modifier {
            case .command:
                return flags | UInt32(cmdKey)
            case .option:
                return flags | UInt32(optionKey)
            case .control:
                return flags | UInt32(controlKey)
            case .shift:
                return flags | UInt32(shiftKey)
            }
        }
    }

    private static func keyCode(for key: String) -> UInt32? {
        keyCodeMap[key.uppercased()]
    }

    private static let keyCodeMap: [String: UInt32] = [
        "A": UInt32(kVK_ANSI_A),
        "B": UInt32(kVK_ANSI_B),
        "C": UInt32(kVK_ANSI_C),
        "D": UInt32(kVK_ANSI_D),
        "E": UInt32(kVK_ANSI_E),
        "F": UInt32(kVK_ANSI_F),
        "G": UInt32(kVK_ANSI_G),
        "H": UInt32(kVK_ANSI_H),
        "I": UInt32(kVK_ANSI_I),
        "J": UInt32(kVK_ANSI_J),
        "K": UInt32(kVK_ANSI_K),
        "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M),
        "N": UInt32(kVK_ANSI_N),
        "O": UInt32(kVK_ANSI_O),
        "P": UInt32(kVK_ANSI_P),
        "Q": UInt32(kVK_ANSI_Q),
        "R": UInt32(kVK_ANSI_R),
        "S": UInt32(kVK_ANSI_S),
        "T": UInt32(kVK_ANSI_T),
        "U": UInt32(kVK_ANSI_U),
        "V": UInt32(kVK_ANSI_V),
        "W": UInt32(kVK_ANSI_W),
        "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y),
        "Z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9)
    ]
}
