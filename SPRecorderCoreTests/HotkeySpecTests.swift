import Testing
@testable import SPRecorderCore

struct HotkeySpecTests {
    @Test func parsesTheDefaultStartStopHotkey() throws {
        let spec = try HotkeySpec.parse("Control+Option+R")
        #expect(spec.modifiers == [.control, .option])
        #expect(spec.key == "R")
        #expect(spec.displayString == "⌃⌥R")
    }

    @Test func acceptsAliasesAnyCaseAndSpaces() throws {
        #expect(try HotkeySpec.parse("ctrl + alt + m") == HotkeySpec(modifiers: [.control, .option], key: "M"))
        #expect(try HotkeySpec.parse("Cmd+Shift+F5") == HotkeySpec(modifiers: [.command, .shift], key: "F5"))
        #expect(try HotkeySpec.parse("Opt+Control+7").displayString == "⌃⌥7")
    }

    @Test func displaysModifiersInMacOrder() throws {
        #expect(try HotkeySpec.parse("Command+Shift+Option+Control+K").displayString == "⌃⌥⇧⌘K")
    }

    @Test(arguments: [
        ("", HotkeySpec.ParseError.empty),
        ("Control+Option", .noKey),
        ("Control+R+M", .moreThanOneKey),
        ("Control+Enter", .unknownToken("Enter")),
        ("Option+Shift+R", .needsControlOrCommand),
        ("R", .needsControlOrCommand),
    ])
    func rejectsWhatCarbonCannotRegister(text: String, error: HotkeySpec.ParseError) {
        #expect(throws: error) { try HotkeySpec.parse(text) }
    }

    @Test func producesCarbonKeyCodesAndModifierFlags() throws {
        let r = try HotkeySpec.parse("Control+Option+R")
        #expect(r.macVirtualKeyCode == 0x0F)            // kVK_ANSI_R
        #expect(r.macModifierFlags == 0x1000 | 0x0800)  // controlKey | optionKey
        #expect(try HotkeySpec.parse("Control+Option+M").macVirtualKeyCode == 0x2E)
        #expect(try HotkeySpec.parse("Control+Option+N").macVirtualKeyCode == 0x2D)
        #expect(try HotkeySpec.parse("Command+Shift+A").macModifierFlags == 0x0100 | 0x0200)
    }

    @Test func everyLetterDigitAndFunctionKeyHasACode() {
        let letters = (UInt8(ascii: "A")...UInt8(ascii: "Z")).map { String(UnicodeScalar($0)) }
        let digits = (0...9).map(String.init)
        let functionKeys = (1...12).map { "F\($0)" }
        #expect(Set(HotkeySpec.keyCodes.keys) == Set(letters + digits + functionKeys))
        #expect(Set(HotkeySpec.keyCodes.values).count == 48)   // no two keys share a code
    }
}
