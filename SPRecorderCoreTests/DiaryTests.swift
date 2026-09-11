import Foundation
import Testing
@testable import SPRecorderCore

struct DiaryTests {
    @Test func noticeWarningAndErrorAreAlwaysWritten() {
        let sink = RecordingDiarySink()
        let diary = Diary(sinks: [sink])
        diary.notice(.app, "a")
        diary.warning(.settings, "b")
        diary.error(.recordingSession, "c")
        #expect(sink.entries.map(\.level) == [.notice, .warning, .error])
        #expect(sink.entries.map(\.category) == [.app, .settings, .recordingSession])
        #expect(sink.entries.map(\.message) == ["a", "b", "c"])
    }

    @Test func debugIsOffByDefault() {
        let sink = RecordingDiarySink()
        Diary(sinks: [sink]).debug(.app, "hidden")
        #expect(sink.entries.isEmpty)

        let loud = RecordingDiarySink()
        Diary(sinks: [loud], debugEnabled: true).debug(.app, "shown")
        #expect(loud.lines(.debug) == ["shown"])
    }

    @Test func everySinkGetsEveryEntry() {
        let first = RecordingDiarySink(), second = RecordingDiarySink()
        Diary(sinks: [first, second]).notice(.hotkey, "both")
        #expect(first.entries == second.entries)
        #expect(first.entries.count == 1)
    }
}

struct DiaryFileTests {
    @Test func writesOneReadableLinePerEntryIntoTheDaysFile() throws {
        let dir = try makeTemporaryDirectory()
        let when = TestTime.date(2026, 9, 10, 14, 30, 5)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)
        file.write(DiaryEntry(date: when, level: .notice, category: .recordingSession, message: "Recording Session started"))
        file.write(DiaryEntry(date: when, level: .error, category: .micTrack, message: "no sound"))

        let text = try String(contentsOf: dir.appendingPathComponent("2026-09-10.log"), encoding: .utf8)
        #expect(text == """
        2026-09-10 14:30:05.000 [notice] RecordingSession: Recording Session started
        2026-09-10 14:30:05.000 [error] MicTrack: no sound

        """)
    }

    @Test func aNewDayStartsANewFile() throws {
        let dir = try makeTemporaryDirectory()
        let evening = TestTime.date(2026, 9, 10, 23, 59, 59)
        let morning = TestTime.date(2026, 9, 11, 0, 0, 1)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: evening)
        file.write(DiaryEntry(date: evening, level: .notice, category: .app, message: "late"))
        file.write(DiaryEntry(date: morning, level: .notice, category: .app, message: "early"))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-10.log").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-11.log").path))
    }

    @Test func keepsSevenDaysAndDeletesOlderFilesOnOpen() throws {
        let dir = try makeTemporaryDirectory()
        for day in 1...10 {
            let name = String(format: "2026-09-%02d.log", day)
            FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data("x\n".utf8))
        }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("notes.txt").path, contents: nil)

        _ = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: TestTime.date(2026, 9, 10, 9, 0))

        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(left == ["2026-09-04.log", "2026-09-05.log", "2026-09-06.log", "2026-09-07.log",
                         "2026-09-08.log", "2026-09-09.log", "2026-09-10.log", "notes.txt"])
    }

    @Test func deletesTheOldestFileWhenTheDayChanges() throws {
        let dir = try makeTemporaryDirectory()
        let opened = TestTime.date(2026, 9, 10, 23, 0)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: opened)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("2026-09-04.log").path, contents: nil)

        file.write(DiaryEntry(date: TestTime.date(2026, 9, 11, 0, 5), level: .notice, category: .app, message: "midnight"))

        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-04.log").path))
    }

    @Test func appendsToAnExistingFileForToday() throws {
        let dir = try makeTemporaryDirectory()
        let when = TestTime.date(2026, 9, 10, 8, 0)
        let url = dir.appendingPathComponent("2026-09-10.log")
        try Data("earlier line\n".utf8).write(to: url)

        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)
        file.write(DiaryEntry(date: when, level: .notice, category: .app, message: "after relaunch"))

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("earlier line\n"))
        #expect(text.hasSuffix("[notice] App: after relaunch\n"))
    }

    @Test func twoDiaryFilesOnTheSameDayKeepEachOthersLines() throws {
        // Two running copies of the app once overwrote each other's lines (first-demo results, Step 12).
        let dir = try makeTemporaryDirectory()
        let when = TestTime.date(2026, 9, 10, 8, 0)
        let first = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)
        let second = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)

        first.write(DiaryEntry(date: when, level: .notice, category: .app, message: "first one"))
        second.write(DiaryEntry(date: when, level: .notice, category: .app, message: "second one"))
        first.write(DiaryEntry(date: when, level: .notice, category: .app, message: "first two"))

        let text = try String(contentsOf: dir.appendingPathComponent("2026-09-10.log"), encoding: .utf8)
        let messages = text.split(separator: "\n").map { $0.components(separatedBy: "App: ").last ?? "" }
        #expect(messages == ["first one", "second one", "first two"])
    }

    @Test func failuresToCreateTheFolderOrOpenTheFileAreEachReportedOnce() throws {
        let dir = try makeTemporaryDirectory()
        let blockedPath = dir.appendingPathComponent("Logs", isDirectory: true)
        // Create a file at the path where the directory should be created
        FileManager.default.createFile(atPath: blockedPath.path, contents: nil)

        let recorder = FailureRecorder()
        let when = TestTime.date(2026, 9, 10, 9, 0)
        let file = DiaryFile(directory: blockedPath, timeZone: TestTime.bangkok, now: when, onFailure: recorder.record)

        // Write two entries on the same day
        file.write(DiaryEntry(date: when, level: .notice, category: .app, message: "first"))
        file.write(DiaryEntry(date: when, level: .notice, category: .app, message: "second"))

        let messages = recorder.messages
        // Expect exactly one "create folder" error and one "open file" error
        let createErrors = messages.filter { $0.hasPrefix("Could not create the Diary folder") }
        let openErrors = messages.filter { $0.hasPrefix("Could not open the Diary file") }

        #expect(createErrors.count == 1)
        #expect(openErrors.count == 1)
        #expect(messages.count == 2)
    }
}
