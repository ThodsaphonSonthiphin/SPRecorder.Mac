import Foundation
@testable import SPRecorderCore

/// Keeps every Diary entry in memory, so a test can assert the line a failure left behind
/// (sprecorder-mac-0015).
final class RecordingDiarySink: DiarySink, @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [DiaryEntry] = []

    var entries: [DiaryEntry] { lock.withLock { _entries } }

    func write(_ entry: DiaryEntry) { lock.withLock { _entries.append(entry) } }

    func lines(_ level: DiaryLevel) -> [String] {
        entries.filter { $0.level == level }.map(\.message)
    }
}

enum TestTime {
    static let bangkok = TimeZone(identifier: "Asia/Bangkok")!

    /// A wall-clock time in Bangkok.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = bangkok
        return c.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

/// Keeps a lock-protected list of failure messages from a DiaryFile, so a test can assert
/// that specific failures are reported.
final class FailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [String] = []

    var messages: [String] { lock.withLock { _messages } }

    func record(_ message: String) { lock.withLock { _messages.append(message) } }
}

/// A fresh, empty folder under the system temporary directory.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("SPRecorderCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
