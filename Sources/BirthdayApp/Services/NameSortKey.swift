import Foundation

enum NameSortKey {
    static func romanized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "#" }
        let mutable = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).uppercased()
    }

    static func sectionKey(for sortKey: String) -> String {
        guard let first = sortKey.first else { return "#" }
        let letter = String(first)
        return letter.range(of: "[A-Z]", options: .regularExpression) == nil ? "#" : letter
    }

    static func sectionSortValue(_ key: String) -> Int {
        if key == "#" { return Int.max }
        guard let scalar = key.unicodeScalars.first else { return Int.max }
        return Int(scalar.value)
    }

    static func sectionSortValue(_ lhs: String, _ rhs: String) -> Bool {
        sectionSortValue(lhs) < sectionSortValue(rhs)
    }
}
