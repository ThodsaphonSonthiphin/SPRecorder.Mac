import Foundation
import Testing
@testable import SPRecorderCore

struct TrackFileTests {
    @Test func tracksHavePlainEnglishFileNames() {
        let folder = URL(fileURLWithPath: "/x/2026-09-10 Thu 14.30", isDirectory: true)
        #expect(TrackFile.systemTrack.url(in: folder).path == "/x/2026-09-10 Thu 14.30/Computer audio.m4a")
        #expect(TrackFile.micTrack.url(in: folder).path == "/x/2026-09-10 Thu 14.30/My microphone.m4a")
    }
}
