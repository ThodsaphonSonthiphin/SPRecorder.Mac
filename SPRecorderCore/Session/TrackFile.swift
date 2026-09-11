import Foundation

/// The fixed, plain-English file names inside a Session folder (sprecorder-mac-0019). The disk
/// does not speak the glossary: the System track is `Computer audio.m4a`.
/// Later plans add the Mixed file, Screen recording, Marker log and Marker review page.
public enum TrackFile: String, Sendable, CaseIterable {
    case systemTrack = "Computer audio.m4a"
    case micTrack = "My microphone.m4a"

    public var fileName: String { rawValue }

    public func url(in folder: URL) -> URL {
        folder.appendingPathComponent(fileName, isDirectory: false)
    }
}
