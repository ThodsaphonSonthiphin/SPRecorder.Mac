import Foundation
import Testing
@testable import SPRecorderCore

struct AppSettingsTests {
    private func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaultsFollowTheMacADRs() {
        let s = AppSettings()
        #expect(s.outputDirectory == "~/Movies/SPRecorder")                    // sprecorder-mac-0005
        #expect(s.fileNamePattern == "{timestamp:yyyy-MM-dd EEE HH.mm}")         // sprecorder-mac-0019
        #expect(s.hotkey == "Control+Option+R")
        #expect(s.quickMarkHotkey == "Control+Option+M")
        #expect(s.markWithNoteHotkey == "Control+Option+N")
        #expect(s.audioBitrateKbps == 64)                                         // research #6
        #expect(s.markerLogFormat == "Markdown")
        #expect(s.autoOpenMarkerReview == false)
        #expect(s.splitMode == "None")
        #expect(s.splitTimeMinutes == 30)
        #expect(s.splitSizeMb == 195)
        #expect(s.screenRecordingEnabled == false)
        #expect(s.screenFrameRate == 30)
        #expect(s.screenQuality == "Medium")
    }

    @Test func thereAreTwentySixSettingsWithTheWindowsKeyNames() throws {
        let data = try JSONEncoder().encode(AppSettings())
        let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys.sorted()
        #expect(keys.count == 26)
        #expect(keys.contains("OutputDirectory"))
        #expect(keys.contains("SplitTimeMinutes"))
        #expect(keys.contains("AudioBitrateKbps"))
        #expect(!keys.contains("Mp3BitrateKbps"))
        #expect(!keys.contains("ScreenMonitorDeviceName"))                        // sprecorder-mac-0021
    }

    @Test func missingKeysTakeTheirDefaults() throws {
        let s = try decode(#"{ "SplitMode": "Time" }"#)
        var expected = AppSettings()
        expected.splitMode = "Time"
        #expect(s == expected)
    }

    @Test func aValueOfTheWrongTypeFallsBackForThatSettingOnly() throws {
        let s = try decode(#"{ "SplitTimeMinutes": "forty", "SplitSizeMb": 180 }"#)
        #expect(s.splitTimeMinutes == 30)
        #expect(s.splitSizeMb == 180)
    }

    @Test func theKeysOfValuesThatCannotBeReadAreListed() throws {
        let unreadable = AppSettings.UnreadableKeys()
        let decoder = JSONDecoder()
        decoder.userInfo[AppSettings.unreadableKeysInfoKey] = unreadable
        _ = try decoder.decode(AppSettings.self, from: Data(#"{ "AudioBitrateKbps": "96", "SplitSizeMb": 180, "Hotkey": null }"#.utf8))
        #expect(unreadable.names == ["AudioBitrateKbps"])
    }

    @Test func unknownKeysAreIgnored() throws {
        let s = try decode(#"{ "Mp3BitrateKbps": 128, "ScreenMonitorDeviceName": "\\\\.\\DISPLAY2" }"#)
        #expect(s == AppSettings())
    }

    @Test func clampsAndFallsBackInvalidSplitFields() throws {
        let s = try decode(#"{ "SplitMode": "Garbage", "SplitTimeMinutes": 99999, "SplitSizeMb": 0 }"#).validated()
        #expect(s.splitMode == "None")
        #expect(s.splitTimeMinutes == 1440)
        #expect(s.splitSizeMb == 1)
    }

    @Test(arguments: [(99, 30), (0, 15), (20, 15), (24, 25), (28, 30), (25, 25)])
    func snapsTheFrameRateToFifteenTwentyFiveOrThirty(input: Int, expected: Int) {
        var s = AppSettings()
        s.screenFrameRate = input
        #expect(s.validated().screenFrameRate == expected)
    }

    @Test func unknownQualityAndMarkerFormatFallBack() throws {
        let s = try decode(#"{ "ScreenQuality": "ultra", "MarkerLogFormat": "yaml" }"#).validated()
        #expect(s.screenQuality == "Medium")
        #expect(s.markerLogFormat == "Markdown")
    }

    @Test func keepsValidChoices() throws {
        let s = try decode(#"{ "ScreenQuality": "High", "MarkerLogFormat": "Csv", "SplitMode": "Size" }"#).validated()
        #expect(s.screenQuality == "High")
        #expect(s.markerLogFormat == "Csv")
        #expect(s.splitMode == "Size")
    }

    @Test func aPatternWithoutTheTimestampFallsBackToTheDefault() {
        var s = AppSettings()
        s.fileNamePattern = "{timestamp:yyyy-MM-dd_HH-mm-ss}_{track}.mp3"
        #expect(s.validated().fileNamePattern == s.fileNamePattern)   // has {timestamp: keep
        s.fileNamePattern = "meeting"
        #expect(s.validated().fileNamePattern == AppSettings.defaultFileNamePattern)
    }

    @Test func outputDirectoryExpandsATildeAgainstTheGivenHome() {
        let home = URL(fileURLWithPath: "/Users/her", isDirectory: true)
        var s = AppSettings()
        #expect(s.outputDirectoryURL(home: home).path == "/Users/her/Movies/SPRecorder")
        s.outputDirectory = "/Volumes/Archive/Meetings"
        #expect(s.outputDirectoryURL(home: home).path == "/Volumes/Archive/Meetings")
        s.outputDirectory = "   "
        #expect(s.validated().outputDirectoryURL(home: home).path == "/Users/her/Movies/SPRecorder")
    }
}
