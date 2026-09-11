import Foundation

/// The settings in `settings.json` (sprecorder-mac-0004). Keys keep the Windows `AppConfig`
/// names so a support conversation reads the same on both platforms, except where a Mac ADR
/// changed them: `OutputDirectory` (sprecorder-mac-0005), `FileNamePattern`
/// (sprecorder-mac-0019), the three hotkeys (Carbon, research #5), `AudioBitrateKbps`
/// (was `Mp3BitrateKbps`; AAC, research #6) and no `ScreenMonitorDeviceName`
/// (sprecorder-mac-0021). 26 settings.
public struct AppSettings: Codable, Equatable, Sendable {
    public var outputDirectory = "~/Movies/SPRecorder"
    public var fileNamePattern = AppSettings.defaultFileNamePattern
    public var hotkey = "Control+Option+R"
    public var quickMarkHotkey = "Control+Option+M"
    public var markWithNoteHotkey = "Control+Option+N"
    public var markerLogFormat = "Markdown"
    public var autoOpenMarkerReview = false
    public var audioBitrateKbps = 64
    public var microphoneDeviceId = ""
    public var systemAudioDeviceId = ""
    public var mixedFileEnabled = true
    public var mixedFileFormat = "Mono"
    public var mixedFileSampleRate = 44100
    public var promptForSessionName = false
    public var autoDetectCallsEnabled = false
    public var splitMode = "None"
    public var splitTimeMinutes = 30
    public var splitSizeMb = 195
    public var splitSystemTrack = true
    public var splitMicTrack = true
    public var splitMixedTrack = true
    public var screenRecordingEnabled = false
    public var screenFrameRate = 30
    public var screenQuality = "Medium"
    public var showMouseClicks = true
    public var showKeystrokes = true

    public static let defaultFileNamePattern = "{timestamp:yyyy-MM-dd EEE HH.mm}"

    public init() {}

    enum CodingKeys: String, CodingKey, CaseIterable {
        case outputDirectory = "OutputDirectory"
        case fileNamePattern = "FileNamePattern"
        case hotkey = "Hotkey"
        case quickMarkHotkey = "QuickMarkHotkey"
        case markWithNoteHotkey = "MarkWithNoteHotkey"
        case markerLogFormat = "MarkerLogFormat"
        case autoOpenMarkerReview = "AutoOpenMarkerReview"
        case audioBitrateKbps = "AudioBitrateKbps"
        case microphoneDeviceId = "MicrophoneDeviceId"
        case systemAudioDeviceId = "SystemAudioDeviceId"
        case mixedFileEnabled = "MixedFileEnabled"
        case mixedFileFormat = "MixedFileFormat"
        case mixedFileSampleRate = "MixedFileSampleRate"
        case promptForSessionName = "PromptForSessionName"
        case autoDetectCallsEnabled = "AutoDetectCallsEnabled"
        case splitMode = "SplitMode"
        case splitTimeMinutes = "SplitTimeMinutes"
        case splitSizeMb = "SplitSizeMb"
        case splitSystemTrack = "SplitSystemTrack"
        case splitMicTrack = "SplitMicTrack"
        case splitMixedTrack = "SplitMixedTrack"
        case screenRecordingEnabled = "ScreenRecordingEnabled"
        case screenFrameRate = "ScreenFrameRate"
        case screenQuality = "ScreenQuality"
        case showMouseClicks = "ShowMouseClicks"
        case showKeystrokes = "ShowKeystrokes"
    }

    /// Collects the keys `init(from:)` found but could not read, so the settings store can name
    /// them in the Diary instead of falling back silently. Pass one in the decoder's `userInfo`.
    public final class UnreadableKeys: @unchecked Sendable {
        private let lock = NSLock()
        private var _names: [String] = []
        public init() {}
        public var names: [String] { lock.withLock { _names } }
        func add(_ name: String) { lock.withLock { _names.append(name) } }
    }

    public static let unreadableKeysInfoKey = CodingUserInfoKey(rawValue: "SPRecorder.unreadableKeys")!

    /// A hand-edited file is the expected support path, so a missing key or a value of the
    /// wrong type falls back to that one setting's default instead of failing the whole file.
    /// A value of the wrong type is also listed in `UnreadableKeys`, when the decoder carries one.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        let unreadable = decoder.userInfo[AppSettings.unreadableKeysInfoKey] as? UnreadableKeys
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            do {
                return try c.decodeIfPresent(T.self, forKey: key) ?? fallback
            } catch {
                unreadable?.add(key.rawValue)
                return fallback
            }
        }
        outputDirectory = value(.outputDirectory, d.outputDirectory)
        fileNamePattern = value(.fileNamePattern, d.fileNamePattern)
        hotkey = value(.hotkey, d.hotkey)
        quickMarkHotkey = value(.quickMarkHotkey, d.quickMarkHotkey)
        markWithNoteHotkey = value(.markWithNoteHotkey, d.markWithNoteHotkey)
        markerLogFormat = value(.markerLogFormat, d.markerLogFormat)
        autoOpenMarkerReview = value(.autoOpenMarkerReview, d.autoOpenMarkerReview)
        audioBitrateKbps = value(.audioBitrateKbps, d.audioBitrateKbps)
        microphoneDeviceId = value(.microphoneDeviceId, d.microphoneDeviceId)
        systemAudioDeviceId = value(.systemAudioDeviceId, d.systemAudioDeviceId)
        mixedFileEnabled = value(.mixedFileEnabled, d.mixedFileEnabled)
        mixedFileFormat = value(.mixedFileFormat, d.mixedFileFormat)
        mixedFileSampleRate = value(.mixedFileSampleRate, d.mixedFileSampleRate)
        promptForSessionName = value(.promptForSessionName, d.promptForSessionName)
        autoDetectCallsEnabled = value(.autoDetectCallsEnabled, d.autoDetectCallsEnabled)
        splitMode = value(.splitMode, d.splitMode)
        splitTimeMinutes = value(.splitTimeMinutes, d.splitTimeMinutes)
        splitSizeMb = value(.splitSizeMb, d.splitSizeMb)
        splitSystemTrack = value(.splitSystemTrack, d.splitSystemTrack)
        splitMicTrack = value(.splitMicTrack, d.splitMicTrack)
        splitMixedTrack = value(.splitMixedTrack, d.splitMixedTrack)
        screenRecordingEnabled = value(.screenRecordingEnabled, d.screenRecordingEnabled)
        screenFrameRate = value(.screenFrameRate, d.screenFrameRate)
        screenQuality = value(.screenQuality, d.screenQuality)
        showMouseClicks = value(.showMouseClicks, d.showMouseClicks)
        showKeystrokes = value(.showKeystrokes, d.showKeystrokes)
    }

    /// The validation `AppConfig.Load` did on Windows, which must survive (sprecorder-mac-0004),
    /// plus the folder-name rule of sprecorder-mac-0019's correction.
    public func validated() -> AppSettings {
        var s = self
        if !["None", "Time", "Size"].contains(s.splitMode) { s.splitMode = "None" }
        s.splitTimeMinutes = min(max(s.splitTimeMinutes, 1), 1440)
        s.splitSizeMb = min(max(s.splitSizeMb, 1), 10000)
        s.screenFrameRate = AppSettings.nearestFrameRate(s.screenFrameRate)
        if !["Low", "Medium", "High"].contains(s.screenQuality) { s.screenQuality = "Medium" }
        if !["Markdown", "Csv"].contains(s.markerLogFormat) { s.markerLogFormat = "Markdown" }
        if !s.fileNamePattern.contains("{timestamp") { s.fileNamePattern = AppSettings.defaultFileNamePattern }
        if s.outputDirectory.trimmingCharacters(in: .whitespaces).isEmpty { s.outputDirectory = AppSettings().outputDirectory }
        return s
    }

    /// 15, 25 or 30; a tie goes to the lower rate, as on Windows.
    static func nearestFrameRate(_ fps: Int) -> Int {
        var best = 15
        for allowed in [15, 25, 30] where abs(allowed - fps) < abs(best - fps) { best = allowed }
        return best
    }

    /// The recordings folder as a URL. A plain path, never a bookmark (sprecorder-mac-0005);
    /// a leading `~` means the given home folder.
    public func outputDirectoryURL(home: URL) -> URL {
        if outputDirectory == "~" { return home }
        if outputDirectory.hasPrefix("~/") {
            return home.appendingPathComponent(String(outputDirectory.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: outputDirectory, isDirectory: true)
    }
}
