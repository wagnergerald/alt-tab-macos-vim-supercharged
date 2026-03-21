enum WindowHintLabels {
    private static let charset: [Character] = Array("asdfghjklqwertyuiopzxcvbnm1234567890")
    private static let charsetSet: Set<String> = Set(charset.map { String($0) })

    static func isHintCharacter(_ c: String) -> Bool {
        charsetSet.contains(c)
    }

    static func labels(for count: Int) -> [String] {
        guard count > 0 else { return [] }
        let n = charset.count
        var width = 1
        var capacity = n
        while capacity < count {
            width += 1
            capacity *= n
        }
        var result: [String] = []
        fillLength(width, "", &result, count)
        return result
    }

    private static func fillLength(_ len: Int, _ built: String, _ result: inout [String], _ max: Int) {
        guard result.count < max else { return }
        if built.count == len {
            result.append(built)
            return
        }
        for c in charset {
            fillLength(len, built + String(c), &result, max)
        }
    }
}
