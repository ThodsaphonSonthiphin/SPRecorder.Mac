import Foundation
import Testing
@testable import SPRecorderCore

struct SessionFolderNameTests {
    let startedAt = TestTime.date(2026, 9, 10, 14, 30, 22)

    @Test func theDefaultPatternNamesTheFolderByDateWeekdayAndTime() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt, timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30")
    }

    @Test func theYearIsGregorianAndTheWeekdayEnglishWhateverTheMacsRegion() {
        // The formatter is pinned, so this holds on a Mac set to Thailand (Buddhist year 2569).
        let name = SessionFolderName.make(pattern: "{timestamp:yyyy EEEE}", startedAt: startedAt, timeZone: TestTime.bangkok)
        #expect(name == "2026 Thursday")
    }

    @Test func aBareTimestampTokenUsesTheDefaultFormat() {
        #expect(SessionFolderName.make(pattern: "{timestamp}", startedAt: startedAt, timeZone: TestTime.bangkok) == "2026-09-10 Thu 14.30")
    }

    @Test func textAroundTheTokenIsKept() {
        #expect(SessionFolderName.make(pattern: "Meeting {timestamp:yyyy-MM-dd}", startedAt: startedAt, timeZone: TestTime.bangkok) == "Meeting 2026-09-10")
    }

    @Test func aSessionNameGoesAfterTheStamp() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt,
                                          sessionName: "  Team standup ", timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30 — Team standup")
    }

    @Test func aBlankSessionNameAddsNothing() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt,
                                          sessionName: "   ", timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30")
    }

    @Test func colonsInTheFormatNeverReachTheDisk() {
        #expect(SessionFolderName.make(pattern: "{timestamp:HH:mm}", startedAt: startedAt, timeZone: TestTime.bangkok) == "14-30")
    }

    @Test(arguments: [
        ("Q2 Planning", "Q2 Planning"),
        ("foo/bar:baz", "foo-bar-baz"),
        ("..hidden", "hidden"),
        ("trailing dots...", "trailing dots"),
        ("trailing space  ", "trailing space"),
        ("Bad<>|chars?", "Bad<>|chars?"),
    ])
    func sanitizeAppliesTheMacRules(input: String, expected: String) {
        #expect(SessionFolderName.sanitize(input) == expected)
    }

    @Test func sanitizeCapsAt255BytesWithoutSplittingACharacter() {
        let thai = String(repeating: "ประชุม", count: 20)          // 3 bytes per character
        let capped = SessionFolderName.sanitize(thai)
        #expect(capped.utf8.count <= 255)
        #expect(capped.utf8.count > 250)
        #expect(thai.hasPrefix(capped))
    }

    @Test func aFolderThatAlreadyExistsGetsANumber() throws {
        let parent = try makeTemporaryDirectory()
        let name = "2026-09-10 Thu 14.30"
        let first = SessionFolderName.uniqueFolderURL(in: parent, name: name)
        #expect(first.lastPathComponent == name)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: false)

        let second = SessionFolderName.uniqueFolderURL(in: parent, name: name)
        #expect(second.lastPathComponent == "2026-09-10 Thu 14.30 (2)")
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: false)

        #expect(SessionFolderName.uniqueFolderURL(in: parent, name: name).lastPathComponent == "2026-09-10 Thu 14.30 (3)")
    }
}
