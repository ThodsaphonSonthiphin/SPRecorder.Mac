import os
import SPRecorderCore

/// The live-debugging sink: unified log, subsystem `com.sprecorder.mac`, one category per
/// glossary area (sprecorder-mac-0013). Message text stays private by default; the Diary file
/// is the support record, not this.
struct OSLogSink: DiarySink {
    private let loggers: [DiaryCategory: Logger]

    init(subsystem: String = "com.sprecorder.mac") {
        loggers = Dictionary(uniqueKeysWithValues: DiaryCategory.allCases.map { ($0, Logger(subsystem: subsystem, category: $0.rawValue)) })
    }

    func write(_ entry: DiaryEntry) {
        guard let logger = loggers[entry.category] else { return }
        switch entry.level {
        case .debug: logger.debug("\(entry.message, privacy: .private)")
        case .notice: logger.notice("\(entry.message, privacy: .private)")
        case .warning: logger.warning("\(entry.message, privacy: .private)")
        case .error: logger.error("\(entry.message, privacy: .private)")
        }
    }
}
