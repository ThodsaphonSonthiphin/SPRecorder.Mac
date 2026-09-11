import Foundation

/// The Diary on disk: one readable file per day, `2026-09-10.log`, in a directory the caller
/// chooses — `~/Library/Logs/SPRecorder` in the app, a temporary folder in tests
/// (sprecorder-mac-0018 needs the directory injected). Files older than seven days are
/// deleted when the Diary opens and whenever the day changes (sprecorder-mac-0014).
/// The file sink's own failures are reported through the optional `onFailure` callback;
/// if the file cannot be written, the file sink cannot record that fact itself.
public final class DiaryFile: DiarySink, @unchecked Sendable {
    public static let keptDays = 7

    private let directory: URL
    private let calendar: Calendar
    private let lock = NSLock()
    private var openDay: String?
    private var handle: FileHandle?
    private var writeFailureReported = false
    private let onFailure: (@Sendable (String) -> Void)?

    private let dayFormatter: DateFormatter
    private let lineFormatter: DateFormatter

    public init(directory: URL, timeZone: TimeZone = .current, now: Date = Date(), onFailure: (@Sendable (String) -> Void)? = nil) {
        self.directory = directory
        self.onFailure = onFailure
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        dayFormatter = DiaryFile.formatter("yyyy-MM-dd", calendar)
        lineFormatter = DiaryFile.formatter("yyyy-MM-dd HH:mm:ss.SSS", calendar)

        var messages: [String] = []
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            messages.append("Could not create the Diary folder \(directory.path): \(error.localizedDescription)")
        }

        lock.withLock {
            let deleteMessages = deleteOldFiles(today: now)
            messages.append(contentsOf: deleteMessages)
        }

        for message in messages {
            onFailure?(message)
        }
    }

    deinit {
        // Nothing can be told at deinit time; stay silent on close failures here.
        try? handle?.close()
    }

    public func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent(dayFormatter.string(from: date) + ".log")
    }

    public func write(_ entry: DiaryEntry) {
        let line = "\(lineFormatter.string(from: entry.date)) [\(entry.level.name)] \(entry.category.rawValue): \(entry.message)\n"
        var messages: [String] = []

        lock.withLock {
            let day = dayFormatter.string(from: entry.date)
            if day != openDay {
                do {
                    try handle?.close()
                } catch {
                    let closePath = openDay.map { dayFormatter.string(from: dayFormatter.date(from: $0) ?? Date()) } ?? "unknown"
                    messages.append("Could not close the Diary file \(directory.appendingPathComponent(closePath + ".log").path): \(error.localizedDescription)")
                }
                handle = nil
                openDay = day
                writeFailureReported = false
                let deleteMessages = deleteOldFiles(today: entry.date)
                messages.append(contentsOf: deleteMessages)
                let url = fileURL(for: entry.date)
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                do {
                    // O_APPEND: every write lands at the end of the file, even when another process
                    // writes the same day's file (first-demo results, Step 12).
                    let descriptor = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
                    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                    handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                } catch {
                    messages.append("Could not open the Diary file \(url.path): \(error.localizedDescription)")
                    handle = nil
                }
            }
            if let handle = handle {
                do {
                    try handle.write(contentsOf: Data(line.utf8))
                } catch {
                    if !writeFailureReported {
                        messages.append("Could not write to the Diary file \(fileURL(for: entry.date).path): \(error.localizedDescription)")
                        writeFailureReported = true
                    }
                }
            }
        }

        for message in messages {
            onFailure?(message)
        }
    }

    /// Keeps today and the six days before it; deletes every older `yyyy-MM-dd.log`.
    /// Returns an array of error messages for any deletion failures.
    private func deleteOldFiles(today: Date) -> [String] {
        var messages: [String] = []
        let startOfToday = calendar.startOfDay(for: today)
        guard let oldestKept = calendar.date(byAdding: .day, value: -(DiaryFile.keptDays - 1), to: startOfToday),
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return messages }
        for name in names where name.hasSuffix(".log") {
            guard let day = dayFormatter.date(from: String(name.dropLast(4))) else { continue }
            if day < oldestKept {
                do {
                    try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
                } catch {
                    messages.append("Could not delete the old Diary file \(directory.appendingPathComponent(name).path): \(error.localizedDescription)")
                }
            }
        }
        return messages
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
