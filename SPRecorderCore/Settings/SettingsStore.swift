import Foundation

/// Reads and writes `~/Library/Application Support/SPRecorder/settings.json`
/// (sprecorder-mac-0004). A rewrite of the Windows `AppConfigStore` (sprecorder-mac-0003).
public final class SettingsStore: @unchecked Sendable {
    public let fileURL: URL
    private let diary: Diary
    private let lock = NSLock()
    private var _current: AppSettings

    public var current: AppSettings { lock.withLock { _current } }

    /// Loads the file. A missing file is created with the defaults, so there is always a
    /// readable file to attach to a problem report. A file that is not JSON is left untouched
    /// and the defaults are used, with a warning in the Diary.
    public init(fileURL: URL, diary: Diary) {
        self.fileURL = fileURL
        self.diary = diary
        _current = AppSettings()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            do {
                try write(AppSettings())
                diary.notice(.settings, "No settings file; created \(fileURL.path) with the defaults")
            } catch {
                diary.error(.settings, "Could not create \(fileURL.path): \(error.localizedDescription)")
            }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
            let valid = loaded.validated()
            if valid != loaded {
                diary.warning(.settings, "Some settings in \(fileURL.lastPathComponent) were out of range and were corrected in memory")
            }
            _current = valid
        } catch {
            diary.warning(.settings, "Could not read \(fileURL.path), using the defaults: \(error.localizedDescription)")
        }
    }

    /// Validates, then writes atomically: a temporary file beside the real one, then
    /// `FileManager.replaceItemAt` (sprecorder-mac-0004).
    public func save(_ settings: AppSettings) throws {
        let valid = settings.validated()
        try write(valid)
        lock.withLock { _current = valid }
        diary.notice(.settings, "Settings saved")
    }

    private func write(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(settings)
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + ".tmp")
        try data.write(to: temp)
        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: temp)
        } else {
            try fm.moveItem(at: temp, to: fileURL)
        }
    }
}
