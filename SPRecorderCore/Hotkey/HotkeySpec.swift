import Foundation

/// A global hotkey as written in `settings.json`, e.g. `Control+Option+R`, shown as `⌃⌥R`.
/// Replaces the dropped Windows `HotkeyParser` (sprecorder-mac-0003). The numbers it produces
/// are the values Carbon's `RegisterEventHotKey` takes (research #5); they are plain numbers
/// here so the Core never imports Carbon (sprecorder-mac-0002).
public struct HotkeySpec: Equatable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case empty
        case unknownToken(String)
        case noKey
        case moreThanOneKey
        case needsControlOrCommand

        public var description: String {
            switch self {
            case .empty: "The hotkey is empty."
            case .unknownToken(let t): "“\(t)” is not a key SPRecorder knows."
            case .noKey: "The hotkey has no key, only modifiers."
            case .moreThanOneKey: "The hotkey has more than one key."
            case .needsControlOrCommand: "The hotkey must include Control or Command."
            }
        }
    }

    public let modifiers: Modifiers
    /// One of `HotkeySpec.keyCodes`' keys: `A`–`Z`, `0`–`9`, `F1`–`F12`.
    public let key: String

    public init(modifiers: Modifiers, key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    /// Case-insensitive, `+`-separated. Accepts `Control`/`Ctrl`, `Option`/`Opt`/`Alt`,
    /// `Shift`, `Command`/`Cmd`. Carbon refuses combinations of only Option and Shift
    /// (research #5), so Control or Command is required.
    public static func parse(_ text: String) throws -> HotkeySpec {
        let tokens = text.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !tokens.isEmpty else { throw ParseError.empty }
        var modifiers: Modifiers = []
        var key: String?
        for token in tokens {
            switch token.lowercased() {
            case "control", "ctrl": modifiers.insert(.control)
            case "option", "opt", "alt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "command", "cmd": modifiers.insert(.command)
            default:
                let upper = token.uppercased()
                guard keyCodes[upper] != nil else { throw ParseError.unknownToken(token) }
                guard key == nil else { throw ParseError.moreThanOneKey }
                key = upper
            }
        }
        guard let key else { throw ParseError.noKey }
        guard modifiers.contains(.control) || modifiers.contains(.command) else { throw ParseError.needsControlOrCommand }
        return HotkeySpec(modifiers: modifiers, key: key)
    }

    /// `⌃⌥⇧⌘` order, as macOS menus show it.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + key
    }

    /// Carbon virtual key code (`kVK_ANSI_R` is 0x0F).
    public var macVirtualKeyCode: UInt32 { HotkeySpec.keyCodes[key]! }

    /// Carbon modifier flags: `cmdKey` 0x0100, `shiftKey` 0x0200, `optionKey` 0x0800, `controlKey` 0x1000.
    public var macModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= 0x0100 }
        if modifiers.contains(.shift) { flags |= 0x0200 }
        if modifiers.contains(.option) { flags |= 0x0800 }
        if modifiers.contains(.control) { flags |= 0x1000 }
        return flags
    }

    /// The keys a hotkey may use, with their Carbon `kVK_*` codes (Events.h, HIToolbox).
    public static let keyCodes: [String: UInt32] = [
        "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "H": 0x04, "G": 0x05, "Z": 0x06, "X": 0x07,
        "C": 0x08, "V": 0x09, "B": 0x0B, "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F, "Y": 0x10,
        "T": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
        "7": 0x1A, "8": 0x1C, "0": 0x1D, "O": 0x1F, "U": 0x20, "I": 0x22, "P": 0x23, "L": 0x25,
        "J": 0x26, "K": 0x28, "N": 0x2D, "M": 0x2E,
        "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76, "F5": 0x60, "F6": 0x61, "F7": 0x62, "F8": 0x64,
        "F9": 0x65, "F10": 0x6D, "F11": 0x67, "F12": 0x6F,
    ]
}
