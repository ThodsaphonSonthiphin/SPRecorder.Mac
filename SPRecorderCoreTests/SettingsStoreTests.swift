import Foundation
import Testing
@testable import SPRecorderCore

struct SettingsStoreTests {
    @Test func aMissingFileIsCreatedWithTheDefaults() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("SPRecorder/settings.json")
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current == AppSettings())
        let onDisk = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
        #expect(onDisk == AppSettings())
        #expect(sink.lines(.notice).contains { $0.contains("created") })
    }

    @Test func theFileIsReadableJSONWithPlainSlashes() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        _ = SettingsStore(fileURL: url, diary: Diary(sinks: []))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains(#""OutputDirectory" : "~/Movies/SPRecorder""#))
        #expect(text.contains("\n"))
    }

    @Test func saveRoundTripsAndReplacesTheFileLeavingNoTemporaryFile() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url, diary: Diary(sinks: []))

        var changed = AppSettings()
        changed.outputDirectory = "/Volumes/Archive"
        changed.splitMode = "Size"
        changed.splitSizeMb = 180
        changed.splitSystemTrack = false
        try store.save(changed)

        #expect(store.current == changed)
        #expect(SettingsStore(fileURL: url, diary: Diary(sinks: [])).current == changed)
        #expect(!FileManager.default.fileExists(atPath: url.path + ".tmp"))
    }

    @Test func saveValidatesFirst() throws {
        let dir = try makeTemporaryDirectory()
        let store = SettingsStore(fileURL: dir.appendingPathComponent("settings.json"), diary: Diary(sinks: []))
        var wild = AppSettings()
        wild.splitTimeMinutes = 0
        try store.save(wild)
        #expect(store.current.splitTimeMinutes == 1)
    }

    @Test func outOfRangeValuesAreCorrectedInMemoryWithAWarning() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        try Data(#"{ "SplitSizeMb": 0 }"#.utf8).write(to: url)
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current.splitSizeMb == 1)
        #expect(sink.lines(.warning).count == 1)
        #expect(try String(contentsOf: url, encoding: .utf8) == #"{ "SplitSizeMb": 0 }"#)   // her file is not rewritten
    }

    @Test func aFileThatIsNotJSONIsLeftAloneAndTheDefaultsAreUsed() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        try Data("{ this is not json".utf8).write(to: url)
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current == AppSettings())
        #expect(try String(contentsOf: url, encoding: .utf8) == "{ this is not json")
        #expect(sink.lines(.warning).first?.contains("using the defaults") == true)
    }
}
