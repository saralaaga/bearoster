import Foundation

public enum DateIntentAction: String, Sendable {
    case convert
    case fillBirthday
}

public struct ParsedDateIntent: Equatable, Sendable {
    public let calendarKind: BirthdayCalendarKind
    public let year: Int?
    public let month: Int
    public let day: Int
    public let isLeapMonth: Bool
    public let action: DateIntentAction
}

public struct DatePhraseParser: Sendable {
    public init() {}

    public func parse(_ phrase: String) -> ParsedDateIntent? {
        let normalized = phrase
            .lowercased()
            .replacingOccurrences(of: "農", with: "农")
            .replacingOccurrences(of: "曆", with: "历")
            .replacingOccurrences(of: "陰", with: "阴")
            .replacingOccurrences(of: "　", with: " ")

        let kind = detectCalendar(in: normalized)
        let action: DateIntentAction = normalized.contains("生日") || normalized.contains("birthday") ? .fillBirthday : .convert

        if kind == .chinese, let parsed = parseChineseLunar(normalized) {
            return ParsedDateIntent(calendarKind: .chinese, year: parsed.year, month: parsed.month, day: parsed.day, isLeapMonth: parsed.leap, action: action)
        }

        if kind == .islamic, let parsed = parseNamedMonth(normalized, months: islamicMonths) {
            return ParsedDateIntent(calendarKind: .islamic, year: parsed.year, month: parsed.month, day: parsed.day, isLeapMonth: false, action: action)
        }

        if kind == .hebrew, let parsed = parseNamedMonth(normalized, months: hebrewMonths) {
            return ParsedDateIntent(calendarKind: .hebrew, year: parsed.year, month: parsed.month, day: parsed.day, isLeapMonth: false, action: action)
        }

        if let parsed = parseNumericMonthDay(normalized) {
            return ParsedDateIntent(calendarKind: kind, year: parsed.year, month: parsed.month, day: parsed.day, isLeapMonth: false, action: action)
        }

        return nil
    }

    private func detectCalendar(in text: String) -> BirthdayCalendarKind {
        if text.contains("农历") || text.contains("阴历") || text.contains("lunar") || text.contains("chinese") {
            return .chinese
        }
        if text.contains("伊斯兰") || text.contains("回历") || text.contains("hijri") || text.contains("islamic") || text.contains("ramadan") {
            return .islamic
        }
        if text.contains("希伯来") || text.contains("hebrew") || text.contains("elul") || text.contains("א") {
            return .hebrew
        }
        return .gregorian
    }

    private func parseChineseLunar(_ text: String) -> (year: Int?, month: Int, day: Int, leap: Bool)? {
        let leap = text.contains("闰")
        let monthText = text.replacingOccurrences(of: "闰", with: "")
        guard let month = chineseMonths.first(where: { monthText.contains($0.key + "月") })?.value,
              let day = chineseDays.first(where: { monthText.contains($0.key) })?.value
        else { return nil }
        return (parseYear(text), month, day, leap)
    }

    private func parseNamedMonth(_ text: String, months: [String: Int]) -> (year: Int?, month: Int, day: Int)? {
        guard let match = months.first(where: { text.contains($0.key) }) else { return nil }
        let day = integers(in: text).first { (1...31).contains($0) }
        guard let day else { return nil }
        return (parseYear(text), match.value, day)
    }

    private func parseNumericMonthDay(_ text: String) -> (year: Int?, month: Int, day: Int)? {
        let values = integers(in: text)
        if values.count >= 3, values[0] > 31 {
            return (values[0], values[1], values[2])
        }
        if values.count >= 2 {
            return (parseYear(text), values[0], values[1])
        }
        return nil
    }

    private func parseYear(_ text: String) -> Int? {
        integers(in: text).first { $0 > 999 }
    }

    private func integers(in text: String) -> [Int] {
        text.matches(of: /\d+/).compactMap { Int($0.output) }
    }

    private let chineseMonths: [String: Int] = [
        "十二": 12, "十一": 11, "冬": 11, "腊": 12, "正": 1,
        "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6,
        "七": 7, "八": 8, "九": 9, "十": 10
    ]

    private let chineseDays: [String: Int] = [
        "三十": 30, "廿九": 29, "二十九": 29, "廿八": 28, "二十八": 28,
        "廿七": 27, "二十七": 27, "廿六": 26, "二十六": 26,
        "廿五": 25, "二十五": 25, "廿四": 24, "二十四": 24,
        "廿三": 23, "二十三": 23, "廿二": 22, "二十二": 22,
        "廿一": 21, "二十一": 21, "二十": 20,
        "十九": 19, "十八": 18, "十七": 17, "十六": 16, "十五": 15,
        "十四": 14, "十三": 13, "十二": 12, "十一": 11,
        "初十": 10, "初九": 9, "初八": 8, "初七": 7, "初六": 6,
        "初五": 5, "初四": 4, "初三": 3, "初二": 2, "初一": 1
    ]

    private let islamicMonths: [String: Int] = [
        "muharram": 1, "safar": 2, "rabi al-awwal": 3, "rabi i": 3,
        "rabi al-thani": 4, "rabi ii": 4, "jumada al-awwal": 5, "jumada i": 5,
        "jumada al-thani": 6, "jumada ii": 6, "rajab": 7, "shaban": 8,
        "shaaban": 8, "ramadan": 9, "رمضان": 9, "shawwal": 10,
        "dhu al-qadah": 11, "dhu al-hijjah": 12
    ]

    private let hebrewMonths: [String: Int] = [
        "nisan": 1, "iyyar": 2, "iyar": 2, "sivan": 3, "tammuz": 4,
        "av": 5, "elul": 6, "אלול": 6, "tishri": 7, "tishrei": 7,
        "cheshvan": 8, "heshvan": 8, "kislev": 9, "tevet": 10,
        "shevat": 11, "adar": 12
    ]
}
