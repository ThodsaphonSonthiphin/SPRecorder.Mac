import AppKit
import SPRecorderCore

/// The minimal menu-bar icon for Plan 1 (sprecorder-mac-0010): a template ring when idle, a red
/// fill while recording, and a menu to start or stop, see a failure, open the recordings
/// folder and quit. Plan 6 replaces it with the full twelve-row menu.
@MainActor
final class StatusItemController: NSObject {
    var onToggle: () -> Void = {}
    var onOpenRecordingsFolder: () -> Void = {}

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Start recording", action: #selector(toggle), keyEquivalent: "")
    private let hotkeyTakenItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let failureItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    static let recordingRed = NSColor(srgbRed: 0xE0 / 255.0, green: 0x36 / 255.0, blue: 0x2C / 255.0, alpha: 1)

    override init() {
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false   // the toggle row is enabled and disabled by hand while starting and stopping
        toggleItem.target = self
        menu.addItem(toggleItem)
        hotkeyTakenItem.isEnabled = false
        hotkeyTakenItem.isHidden = true
        menu.addItem(hotkeyTakenItem)
        failureItem.isEnabled = false
        failureItem.isHidden = true
        menu.addItem(failureItem)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open recordings folder", action: #selector(openFolder), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SPRecorder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        show(.idle)
    }

    func show(_ state: RecordingSession.State) {
        switch state {
        case .idle:
            toggleItem.title = "Start recording"
            toggleItem.isEnabled = true
            setIcon(recording: false)
        case .starting:
            toggleItem.title = "Starting…"
            toggleItem.isEnabled = false
        case .recording:
            toggleItem.title = "Stop recording"
            toggleItem.isEnabled = true
            setIcon(recording: true)
        case .stopping:
            toggleItem.title = "Stopping…"
            toggleItem.isEnabled = false
        }
    }

    /// Shows the start/stop hotkey beside the menu row, or the Inactive hotkey warning.
    func showHotkey(_ spec: HotkeySpec?, registered: Bool) {
        if let spec, registered {
            toggleItem.keyEquivalent = Self.keyEquivalent(for: spec)
            toggleItem.keyEquivalentModifierMask = Self.modifierMask(for: spec)
            hotkeyTakenItem.isHidden = true
        } else {
            toggleItem.keyEquivalent = ""
            hotkeyTakenItem.title = spec.map { "⚠ Hotkey \($0.displayString) taken by another app" } ?? "⚠ Hotkey in settings.json is not valid"
            hotkeyTakenItem.isHidden = false
        }
    }

    /// A plain-words failure, or nil to clear it.
    func showFailure(_ message: String?) {
        failureItem.title = message ?? ""
        failureItem.isHidden = message == nil
    }

    private func setIcon(recording: Bool) {
        let image: NSImage?
        if recording {
            image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "SPRecorder — recording")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [Self.recordingRed]))
            image?.isTemplate = false
        } else {
            image = NSImage(systemSymbolName: "circle", accessibilityDescription: "SPRecorder")
            image?.isTemplate = true
        }
        item.button?.image = image
    }

    @objc private func toggle() { onToggle() }
    @objc private func openFolder() { onOpenRecordingsFolder() }

    private static func keyEquivalent(for spec: HotkeySpec) -> String {
        if spec.key.hasPrefix("F"), let n = Int(spec.key.dropFirst()), let scalar = UnicodeScalar(NSF1FunctionKey + n - 1) {
            return String(Character(scalar))
        }
        return spec.key.lowercased()
    }

    private static func modifierMask(for spec: HotkeySpec) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if spec.modifiers.contains(.control) { mask.insert(.control) }
        if spec.modifiers.contains(.option) { mask.insert(.option) }
        if spec.modifiers.contains(.shift) { mask.insert(.shift) }
        if spec.modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }
}
