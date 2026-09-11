import AppKit
import Carbon
import SPRecorderCore

/// The entry point: a menu-bar app with no Dock icon (`LSUIElement`, sprecorder-mac-0010). It
/// wires the Core's Recording Session to the real adapters, and the start/stop hotkey and menu
/// to the session.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var diary: Diary!
    private var settings: SettingsStore!
    private var session: RecordingSession!
    private var statusItem: StatusItemController!
    private let hotkeys = CarbonHotkeyCenter()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let osLog = OSLogSink()
        let diaryFile = DiaryFile(directory: library.appendingPathComponent("Logs/SPRecorder", isDirectory: true), onFailure: { message in
            // The Diary file cannot write about its own failure; the unified log still can.
            osLog.write(DiaryEntry(date: Date(), level: .error, category: .app, message: message))
        })
        diary = Diary(sinks: [diaryFile, osLog])

        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        diary.notice(.app, "SPRecorder \(version) (\(build)) started on \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let settingsURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SPRecorder/settings.json", isDirectory: false)
        let store = SettingsStore(fileURL: settingsURL, diary: diary)
        settings = store

        let recorder = ScreenCaptureAudioRecorder(diary: diary, bitrateKbps: { store.current.audioBitrateKbps })
        session = RecordingSession(settings: { store.current }, capture: recorder, diary: diary, home: fm.homeDirectoryForCurrentUser)

        statusItem = StatusItemController()
        statusItem.onToggle = { [weak self] in self?.toggleRecording() }
        statusItem.onOpenRecordingsFolder = { [weak self] in self?.openRecordingsFolder() }
        session.onStateChange = { [weak self] state in self?.statusItem.show(state) }
        session.onFailure = { [weak self] message in self?.statusItem.showFailure(message) }

        registerStartStopHotkey()
    }

    /// Quitting mid-recording finishes both files first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard case .recording = session?.state else { return .terminateNow }
        diary.notice(.app, "Quit while recording; stopping the Recording Session first")
        Task {
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.unregisterAll()
        diary?.notice(.app, "SPRecorder quit")
    }

    private func toggleRecording() {
        statusItem.showFailure(nil)
        Task { await session.toggle() }
    }

    private func registerStartStopHotkey() {
        let text = settings.current.hotkey
        let spec: HotkeySpec
        do {
            spec = try HotkeySpec.parse(text)
        } catch {
            let reason = (error as? HotkeySpec.ParseError)?.description ?? error.localizedDescription
            diary.warning(.hotkey, "Start/stop hotkey “\(text)” in settings.json is not valid: \(reason)")
            statusItem.showHotkey(nil, registered: false)
            return
        }
        let status = hotkeys.register(spec) { [weak self] in self?.toggleRecording() }
        if status == noErr {
            diary.notice(.hotkey, "Start/stop hotkey \(spec.displayString) registered")
            statusItem.showHotkey(spec, registered: true)
        } else {
            diary.warning(.hotkey, "Start/stop hotkey \(spec.displayString) is inactive: RegisterEventHotKey returned \(status); another app may own it")
            statusItem.showHotkey(spec, registered: false)
        }
    }

    private func openRecordingsFolder() {
        let folder = settings.current.outputDirectoryURL(home: FileManager.default.homeDirectoryForCurrentUser)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        } catch {
            diary.error(.app, "Could not open the recordings folder \(folder.path): \(error.localizedDescription)")
            statusItem.showFailure("Could not open \(folder.path).")
        }
    }
}
