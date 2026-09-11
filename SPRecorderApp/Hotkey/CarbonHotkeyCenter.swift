import Carbon
import SPRecorderCore

/// Global hotkeys through Carbon's `RegisterEventHotKey`: needs no permission and works with no
/// window (research #5). It is not exclusive: on macOS 26.6.2 a second process registered the
/// same combination with `noErr`, and every press reached both (first-demo results, Steps 11–12).
/// So `noErr` does not prove the combination is free; detecting an Inactive hotkey is left to Plans 3 and 6.
@MainActor
final class CarbonHotkeyCenter {
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Returns `noErr` when registered, which does not prove no other app holds the combination;
    /// any other status means the hotkey is inactive.
    func register(_ spec: HotkeySpec, action: @escaping () -> Void) -> OSStatus {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5350_5263), id: id)   // 'SPRc'
        let status = RegisterEventHotKey(spec.macVirtualKeyCode, spec.macModifierFlags, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = action
        }
        return status
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs = [:]
        actions = [:]
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<CarbonHotkeyCenter>.fromOpaque(context).takeUnretainedValue()
            // The application event target delivers on the main thread.
            MainActor.assumeIsolated { center.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &pressed, context, &handler)
    }
}
