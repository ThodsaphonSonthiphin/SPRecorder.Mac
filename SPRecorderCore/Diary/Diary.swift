import Foundation

/// How serious a Diary line is (sprecorder-mac-0014). `notice` and above are always written;
/// `debug` only when switched on.
public enum DiaryLevel: Int, Sendable, Comparable, CaseIterable {
    case debug, notice, warning, error

    public var name: String {
        switch self {
        case .debug: "debug"
        case .notice: "notice"
        case .warning: "warning"
        case .error: "error"
        }
    }

    public static func < (lhs: DiaryLevel, rhs: DiaryLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Diary categories use the glossary's words, not class names (sprecorder-mac-0013).
public enum DiaryCategory: String, Sendable, CaseIterable {
    case app = "App"
    case settings = "Settings"
    case recordingSession = "RecordingSession"
    case systemTrack = "SystemTrack"
    case micTrack = "MicTrack"
    case hotkey = "Hotkey"
    case permissions = "Permissions"
}

public struct DiaryEntry: Sendable, Equatable {
    public let date: Date
    public let level: DiaryLevel
    public let category: DiaryCategory
    public let message: String

    public init(date: Date, level: DiaryLevel, category: DiaryCategory, message: String) {
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}

/// Somewhere Diary lines go: the Diary file, os_log, or a test's recorder.
public protocol DiarySink: Sendable {
    func write(_ entry: DiaryEntry)
}

/// The one logging seam every part of the app writes through (sprecorder-mac-0013).
/// No failure is silent: every catch writes a line here before doing anything else.
/// Never pass a captured keystroke to it, in any form (sprecorder-mac-0014).
public final class Diary: Sendable {
    private let sinks: [any DiarySink]
    private let now: @Sendable () -> Date
    private let debugEnabled: Bool

    public init(sinks: [any DiarySink], debugEnabled: Bool = false, now: @escaping @Sendable () -> Date = { Date() }) {
        self.sinks = sinks
        self.debugEnabled = debugEnabled
        self.now = now
    }

    public func debug(_ category: DiaryCategory, _ message: String) { write(.debug, category, message) }
    public func notice(_ category: DiaryCategory, _ message: String) { write(.notice, category, message) }
    public func warning(_ category: DiaryCategory, _ message: String) { write(.warning, category, message) }
    public func error(_ category: DiaryCategory, _ message: String) { write(.error, category, message) }

    private func write(_ level: DiaryLevel, _ category: DiaryCategory, _ message: String) {
        if level == .debug && !debugEnabled { return }
        let entry = DiaryEntry(date: now(), level: level, category: category, message: message)
        for sink in sinks { sink.write(entry) }
    }
}
