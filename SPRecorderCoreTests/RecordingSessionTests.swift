import Foundation
import Testing
@testable import SPRecorderCore

@MainActor
struct RecordingSessionTests {
    let home: URL
    let sink = RecordingDiarySink()
    let capture = FakeAudioCapture()
    var clock = TestTime.date(2026, 9, 10, 14, 30, 5)

    init() throws {
        home = try makeTemporaryDirectory()
    }

    func makeSession(settings: AppSettings = AppSettings(), clock: @escaping () -> Date) -> RecordingSession {
        RecordingSession(settings: { settings }, capture: capture, diary: Diary(sinks: [sink]), home: home,
                         now: clock, timeZone: TestTime.bangkok)
    }

    var recordings: URL { home.appendingPathComponent("Movies/SPRecorder", isDirectory: true) }

    @Test func startCreatesTheSessionFolderAndRecordsBothTracksIntoIt() async throws {
        let session = makeSession { clock }
        await session.start()

        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30", isDirectory: true)
        #expect(session.state == .recording(folder: folder, startedAt: clock))
        #expect(capture.startCalls.count == 1)
        #expect(capture.startCalls.first?.systemTrack == folder.appendingPathComponent("Computer audio.m4a"))
        #expect(capture.startCalls.first?.micTrack == folder.appendingPathComponent("My microphone.m4a"))
        #expect(sink.lines(.notice) == ["Recording Session started: \(folder.path)"])
    }

    @Test func stopFinishesCaptureAndReturnsToIdle() async throws {
        var now = clock
        let session = makeSession { now }
        await session.start()
        now = now.addingTimeInterval(95)
        await session.stop()

        #expect(session.state == .idle)
        #expect(capture.stopCalls == 1)
        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30")
        #expect(sink.lines(.notice).last == "Recording Session stopped after 0:01:35: \(folder.path)")
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Computer audio.m4a").path))
    }

    @Test func toggleStartsThenStops() async {
        let session = makeSession { clock }
        await session.toggle()
        #expect(capture.startCalls.count == 1)
        await session.toggle()
        #expect(capture.stopCalls == 1)
        #expect(session.state == .idle)
    }

    @Test func aSecondSessionInTheSameMinuteGetsItsOwnFolder() async {
        let session = makeSession { clock }
        await session.start()
        await session.stop()
        await session.start()

        guard case let .recording(folder, _) = session.state else {
            Issue.record("not recording")
            return
        }
        #expect(folder.lastPathComponent == "2026-09-10 Thu 14.30 (2)")
    }

    @Test func theRecordingsFolderComesFromSettings() async {
        var settings = AppSettings()
        settings.outputDirectory = home.appendingPathComponent("Elsewhere").path
        settings.fileNamePattern = "Call {timestamp:yyyy-MM-dd HH.mm}"
        let session = makeSession(settings: settings) { clock }
        await session.start()

        #expect(capture.startCalls.first?.micTrack.path == home.appendingPathComponent("Elsewhere/Call 2026-09-10 14.30/My microphone.m4a").path)
    }

    @Test func aRefusedPermissionLeavesNoFolderALineInTheDiaryAndPlainWords() async throws {
        capture.startError = .computerAudioNotAllowed
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }

        await session.start()

        #expect(session.state == .idle)
        #expect(try FileManager.default.contentsOfDirectory(atPath: recordings.path).isEmpty)
        #expect(sink.lines(.error) == ["Recording Session could not start (2026-09-10 Thu 14.30): SPRecorder is not allowed to record computer audio."])
        #expect(failures == ["Not recording. SPRecorder is not allowed to record computer audio."])
    }

    @Test func aFolderThatCannotBeCreatedIsReported() async throws {
        let blocker = home.appendingPathComponent("Movies")
        FileManager.default.createFile(atPath: blocker.path, contents: nil)   // a file where the folder should be
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }

        await session.start()

        #expect(session.state == .idle)
        #expect(capture.startCalls.isEmpty)
        #expect(sink.lines(.error).count == 1)
        #expect(failures.first?.hasPrefix("Not recording. Could not create a folder in") == true)
    }

    @Test func aStopThatFailsIsLoggedAndStillEndsTheSession() async {
        capture.stopError = .failed("The Mic track could not be finished.")
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }
        await session.start()
        await session.stop()

        #expect(session.state == .idle)
        #expect(sink.lines(.error) == ["Recording Session did not finish cleanly (2026-09-10 Thu 14.30): The Mic track could not be finished."])
        #expect(failures == ["The recording did not finish cleanly. The Mic track could not be finished."])
    }

    @Test func captureThatStopsByItselfEndsTheSessionWithADiaryLine() async {
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }
        await session.start()

        capture.interrupt(.failed("The audio stream stopped."))
        for _ in 0..<50 where session.state != .idle { await Task.yield() }

        #expect(session.state == .idle)
        #expect(capture.stopCalls == 1)
        #expect(sink.lines(.error) == ["Capture stopped by itself during the Recording Session (2026-09-10 Thu 14.30): The audio stream stopped."])
        #expect(failures == ["Recording stopped by itself. The audio stream stopped."])
    }

    @Test func aSecondPressWhileStartingIsIgnored() async {
        capture.holdStart = true
        let session = makeSession { clock }
        let first = Task { await session.toggle() }
        for _ in 0..<50 where !capture.isHoldingStart { await Task.yield() }
        #expect(session.state == .starting)

        await session.toggle()          // pressed again while macOS is still asking
        #expect(capture.startCalls.count == 1)
        #expect(capture.stopCalls == 0)

        capture.releaseStart()
        await first.value
        #expect(capture.startCalls.count == 1)
        guard case .recording = session.state else {
            Issue.record("expected recording, got \(session.state)")
            return
        }
    }

    @Test func everyStateChangeIsReported() async {
        var seen: [RecordingSession.State] = []
        let session = makeSession { clock }
        session.onStateChange = { seen.append($0) }
        await session.start()
        await session.stop()
        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30", isDirectory: true)
        #expect(seen == [.starting, .recording(folder: folder, startedAt: clock), .stopping, .idle])
    }
}
