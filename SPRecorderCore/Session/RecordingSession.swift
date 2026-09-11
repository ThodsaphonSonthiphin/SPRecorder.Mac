import Foundation

/// One start-to-stop capture (glossary: Recording Session). Plan 1 records the System track
/// and the Mic track into a Session folder; later plans add the Mixed file, Markers and the
/// Screen recording. It builds nothing itself: capture is injected (sprecorder-mac-0002), so
/// the whole flow runs against a fake (sprecorder-mac-0015).
@MainActor
public final class RecordingSession {
    public enum State: Equatable, Sendable {
        case idle
        case starting
        case recording(folder: URL, startedAt: Date)
        case stopping
    }

    public private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    /// Called on every state change.
    public var onStateChange: ((State) -> Void)?
    /// Called with a plain-words sentence when a session fails to start, stops by itself,
    /// or does not finish cleanly. The Diary already has the line when this is called.
    public var onFailure: ((String) -> Void)?

    private let settings: () -> AppSettings
    private let capture: any AudioCapturing
    private let diary: Diary
    private let home: URL
    private let now: () -> Date
    private let timeZone: TimeZone
    private var pendingInterruption: CaptureError?

    public init(settings: @escaping () -> AppSettings, capture: any AudioCapturing, diary: Diary, home: URL,
                now: @escaping () -> Date = { Date() }, timeZone: TimeZone = .current) {
        self.settings = settings
        self.capture = capture
        self.diary = diary
        self.home = home
        self.now = now
        self.timeZone = timeZone
    }

    /// What the start/stop hotkey does. A press while starting or stopping is ignored.
    public func toggle() async {
        switch state {
        case .idle: await start()
        case .recording: await stop()
        case .starting, .stopping:
            diary.notice(.recordingSession, "Start/stop pressed while \(state == .starting ? "starting" : "stopping"); ignored")
        }
    }

    public func start() async {
        guard state == .idle else { return }
        state = .starting
        let current = settings()
        let startedAt = now()
        let parent = current.outputDirectoryURL(home: home)
        let fm = FileManager.default

        let folder: URL
        do {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let name = SessionFolderName.make(pattern: current.fileNamePattern, startedAt: startedAt, timeZone: timeZone)
            folder = SessionFolderName.uniqueFolderURL(in: parent, name: name, fileManager: fm)
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        } catch {
            diary.error(.recordingSession, "Could not create a Session folder in \(parent.path): \(error.localizedDescription)")
            state = .idle
            onFailure?("Not recording. Could not create a folder in \(parent.path).")
            return
        }

        do {
            pendingInterruption = nil
            try await capture.start(systemTrack: TrackFile.systemTrack.url(in: folder),
                                    micTrack: TrackFile.micTrack.url(in: folder),
                                    onInterrupted: { [weak self] reason in
                                        Task { @MainActor in await self?.captureInterrupted(reason) }
                                    })
        } catch {
            let reason = CaptureError(error)
            pendingInterruption = nil
            diary.error(.recordingSession, "Recording Session could not start (\(folder.lastPathComponent)): \(reason.plainWords)")
            removeIfEmpty(folder)
            state = .idle
            onFailure?("Not recording. \(reason.plainWords)")
            return
        }

        diary.notice(.recordingSession, "Recording Session started: \(folder.path)")
        state = .recording(folder: folder, startedAt: startedAt)
        if let reason = pendingInterruption {
            pendingInterruption = nil
            await captureInterrupted(reason)
        }
    }

    public func stop() async {
        guard case let .recording(folder, startedAt) = state else { return }
        state = .stopping
        do {
            try await capture.stop()
            diary.notice(.recordingSession, "Recording Session stopped after \(Self.duration(from: startedAt, to: now())): \(folder.path)")
        } catch {
            let reason = CaptureError(error)
            diary.error(.recordingSession, "Recording Session did not finish cleanly (\(folder.lastPathComponent)): \(reason.plainWords)")
            onFailure?("The recording did not finish cleanly. \(reason.plainWords)")
        }
        state = .idle
    }

    private func captureInterrupted(_ reason: CaptureError) async {
        switch state {
        case .starting:
            pendingInterruption = reason  // handled as soon as `start()` finishes starting
        case let .recording(folder, _):
            diary.error(.recordingSession, "Capture stopped by itself during the Recording Session (\(folder.lastPathComponent)): \(reason.plainWords)")
            onFailure?("Recording stopped by itself. \(reason.plainWords)")
            await stop()
        case .stopping, .idle:
            diary.warning(.recordingSession, "Capture reported a problem after the Recording Session ended: \(reason.plainWords)")
        }
    }

    private func removeIfEmpty(_ folder: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: folder.path), contents.isEmpty else {
            diary.warning(.recordingSession, "Left \(folder.path) in place because it is not empty")
            return
        }
        do {
            try fm.removeItem(at: folder)
        } catch {
            diary.warning(.recordingSession, "Could not remove the empty folder \(folder.path): \(error.localizedDescription)")
        }
    }

    /// `h:mm:ss`
    static func duration(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start).rounded()))
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
