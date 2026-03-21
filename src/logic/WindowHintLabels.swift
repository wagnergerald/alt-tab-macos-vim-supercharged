import Cocoa
import ShortcutRecorder

enum WindowHintLabels {
    private static let baseCharset: [Character] = Array("hjkluiopnmasdfgqwertyzxcvb1234567890")

    private static func dismissSwitcherExcludedCharacter() -> String? {
        guard let sc = Preferences.shortcut("dismissSwitcherShortcut"), sc.keyCode != .none else { return nil }
        let code = UInt32(sc.carbonKeyCode)
        guard let any = LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: code)) else { return nil }
        let trimmed = String(describing: any).trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 1, let c = trimmed.first else { return nil }
        if c.isLetter || c.isNumber { return String(c).lowercased() }
        return nil
    }

    private static func charset() -> [Character] {
        guard let ex = dismissSwitcherExcludedCharacter() else { return Array(baseCharset) }
        return baseCharset.filter { String($0).lowercased() != ex }
    }

    static func isHintCharacter(_ c: String) -> Bool {
        Set(charset().map { String($0) }).contains(c)
    }

    static func circledGlyphString(for text: String) -> String {
        text.map { circledGlyph($0) }.joined()
    }

    private static func circledGlyph(_ c: Character) -> String {
        if let ascii = c.asciiValue, ascii >= Character("a").asciiValue!, ascii <= Character("z").asciiValue! {
            let idx = Int(ascii - Character("a").asciiValue!)
            return String(UnicodeScalar(0x24D0 + idx)!)
        }
        if let d = c.wholeNumberValue, d >= 0, d <= 9 {
            if d == 0 { return "\u{24EA}" }
            return String(UnicodeScalar(0x2460 + d - 1)!)
        }
        return String(c)
    }

    static func labels(for count: Int) -> [String] {
        let chars = charset()
        guard count > 0, !chars.isEmpty else { return [] }
        let n = chars.count
        var width = 1
        var capacity = n
        while capacity < count {
            width += 1
            capacity *= n
        }
        var result: [String] = []
        fillLength(width, "", &result, count, chars)
        return result
    }

    private static func fillLength(_ len: Int, _ built: String, _ result: inout [String], _ max: Int, _ chars: [Character]) {
        guard result.count < max else { return }
        if built.count == len {
            result.append(built)
            return
        }
        for c in chars {
            fillLength(len, built + String(c), &result, max, chars)
        }
    }
}
