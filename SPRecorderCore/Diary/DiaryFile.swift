import Foundation

/// The Diary on disk: one readable file per day, `2026-09-10.log`, in a directory the caller
/// chooses — `~/Library/Logs/SPRecorder` in the app, a temporary folder in tests
/// (sprecorder-mac-0018 needs the directory injected). Files older than seven days are
/// deleted when the Diary opens and whenever the day changes (sprecorder-mac-0014).
public final class DiaryFile: DiarySink, @unchecked Sendable {
    public static let keptDays = 7

    private let directory: URL
    private let calendar: Calendar
    private let lock = NSLock()
    private var openDay: String?
    private var handle: FileHandle?

    private let dayFormatter: DateFormatter
    private let lineFormatter: DateFormatter

    public init(directory: URL, timeZone: TimeZone = .current, now: Date = Date()) {
        self.directory = directory
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        dayFormatter = DiaryFile.formatter("yyyy-MM-dd", calendar)
        lineFormatter = DiaryFile.formatter("yyyy-MM-dd HH:mm:ss.SSS", calendar)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lock.withLock { deleteOldFiles(today: now) }
    }

    deinit { try? handle?.close() }

    public func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent(dayFormatter.string(from: date) + ".log")
    }

    public func write(_ entry: DiaryEntry) {
        let line = "\(lineFormatter.string(from: entry.date)) [\(entry.level.name)] \(entry.category.rawValue): \(entry.message)\n"
        lock.withLock {
            let day = dayFormatter.string(from: entry.date)
            if day != openDay {
                try? handle?.close()
                handle = nil
                openDay = day
                deleteOldFiles(today: entry.date)
                let url = fileURL(for: entry.date)
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                handle = try? FileHandle(forWritingTo: url)
                _ = try? handle?.seekToEnd()
            }
            try? handle?.write(contentsOf: Data(line.utf8))
        }
    }

    /// Keeps today and the six days before it; deletes every older `yyyy-MM-dd.log`.
    private func deleteOldFiles(today: Date) {
        let startOfToday = calendar.startOfDay(for: today)
        guard let oldestKept = calendar.date(byAdding: .day, value: -(DiaryFile.keptDays - 1), to: startOfToday),
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasSuffix(".log") {
            guard let day = dayFormatter.date(from: String(name.dropLast(4))) else { continue }
            if day < oldestKept {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
