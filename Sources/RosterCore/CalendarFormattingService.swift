import Foundation

public struct CalendarFormattingService: Sendable {
    public enum AppLocale: String, CaseIterable, Sendable {
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        case english = "en"
    }

    private static let formatterCache = DateFormatterCache()
    private static let gregorianCalendar = Calendar(identifier: .gregorian)

    public init() {}

    public func calendarName(_ kind: RosterCalendarKind, locale: AppLocale) -> String {
        switch (kind, locale) {
        case (.gregorian, .simplifiedChinese): "公历"
        case (.gregorian, .traditionalChinese): "公曆"
        case (.gregorian, .english): "Gregorian"
        case (.chinese, .simplifiedChinese): "农历"
        case (.chinese, .traditionalChinese): "農曆"
        case (.chinese, .english): "Chinese lunar"
        case (.hebrew, .simplifiedChinese): "希伯来历 / עברי"
        case (.hebrew, .traditionalChinese): "希伯來曆 / עברי"
        case (.hebrew, .english): "Hebrew / עברי"
        case (.islamic, .simplifiedChinese): "伊斯兰历 / هجري"
        case (.islamic, .traditionalChinese): "伊斯蘭曆 / هجري"
        case (.islamic, .english): "Islamic / Hijri / هجري"
        }
    }

    public func originalDate(_ record: RosterRecord, locale: AppLocale) -> String {
        guard let month = record.month, let day = record.day else { return "—" }
        let yearPrefix = record.year.map { "\($0)-" } ?? ""

        switch record.kind {
        case .gregorian:
            return "\(yearPrefix)\(String(format: "%02d", month))-\(String(format: "%02d", day))"
        case .chinese:
            let leap = record.isLeapMonth ? localizedLeap(locale) : ""
            return "\(leap)\(chineseMonth(month))\(chineseDay(day))"
        case .hebrew:
            return "\(hebrewMonth(month)) \(hebrewDay(day))"
        case .islamic:
            return "\(islamicMonth(month)) \(day)"
        }
    }

    public func occurrenceDate(_ date: Date, locale: AppLocale) -> String {
        dateString(date, locale: locale, key: "occurrence", dateStyle: .medium)
    }

    public func fullDate(_ date: Date, locale: AppLocale) -> String {
        dateString(date, locale: locale, key: "full", dateStyle: .full)
    }

    public func monthTitle(_ date: Date, locale: AppLocale) -> String {
        dateString(date, locale: locale, key: "monthTitle", dateFormat: locale == .english ? "MMMM yyyy" : "yyyy年M月")
    }

    public func monthDay(_ date: Date, locale: AppLocale) -> String {
        dateString(date, locale: locale, key: "monthDay", dateFormat: "MMM d")
    }

    public func weekdayName(_ date: Date, locale: AppLocale) -> String {
        dateString(date, locale: locale, key: "weekdayName", dateFormat: "EEEE")
    }

    public func weekdaySymbols(locale: AppLocale) -> [String] {
        Self.formatterCache.symbols(key: "weekdaySymbols-\(locale.rawValue)") {
            let formatter = Self.makeFormatter(locale: locale)
            return formatter.shortStandaloneWeekdaySymbols
        }
    }

    public func monthSymbol(_ date: Date, locale: AppLocale) -> String {
        let month = Self.gregorianCalendar.component(.month, from: date)
        guard locale == .english else { return "\(month)月" }
        let symbols = Self.formatterCache.symbols(key: "monthSymbols-\(locale.rawValue)") {
            let formatter = Self.makeFormatter(locale: locale)
            return formatter.shortStandaloneMonthSymbols
        }
        return symbols.indices.contains(month - 1) ? symbols[month - 1] : "\(month)"
    }

    private func dateString(
        _ date: Date,
        locale: AppLocale,
        key: String,
        dateStyle: DateFormatter.Style? = nil,
        dateFormat: String? = nil
    ) -> String {
        Self.formatterCache.string(key: "\(key)-\(locale.rawValue)", from: date) {
            let formatter = Self.makeFormatter(locale: locale)
            if let dateStyle {
                formatter.dateStyle = dateStyle
                formatter.timeStyle = .none
            }
            if let dateFormat {
                formatter.dateFormat = dateFormat
            }
            return formatter
        }
    }

    private static func makeFormatter(locale: AppLocale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.calendar = gregorianCalendar
        return formatter
    }

    private func localizedLeap(_ locale: AppLocale) -> String {
        switch locale {
        case .simplifiedChinese: "闰"
        case .traditionalChinese: "閏"
        case .english: "leap "
        }
    }

    private func chineseMonth(_ month: Int) -> String {
        let names = ["", "正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        return names.indices.contains(month) ? names[month] : "\(month)月"
    }

    private func chineseDay(_ day: Int) -> String {
        let names = [
            "", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        return names.indices.contains(day) ? names[day] : "\(day)日"
    }

    private func hebrewMonth(_ month: Int) -> String {
        let names = ["", "ניסן", "אייר", "סיוון", "תמוז", "אב", "אלול", "תשרי", "חשוון", "כסלו", "טבת", "שבט", "אדר", "אדר ב׳"]
        return names.indices.contains(month) ? names[month] : "\(month)"
    }

    private func hebrewDay(_ day: Int) -> String {
        let names = ["", "א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "י״א", "י״ב", "י״ג", "י״ד", "ט״ו", "ט״ז", "י״ז", "י״ח", "י״ט", "כ׳", "כ״א", "כ״ב", "כ״ג", "כ״ד", "כ״ה", "כ״ו", "כ״ז", "כ״ח", "כ״ט", "ל׳"]
        return names.indices.contains(day) ? names[day] : "\(day)"
    }

    private func islamicMonth(_ month: Int) -> String {
        let names = [
            "", "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
            "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
        ]
        return names.indices.contains(month) ? names[month] : "\(month)"
    }
}

private final class DateFormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var formatters: [String: DateFormatter] = [:]
    private var cachedSymbols: [String: [String]] = [:]

    func string(key: String, from date: Date, make: () -> DateFormatter) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter = formatters[key] ?? {
            let formatter = make()
            formatters[key] = formatter
            return formatter
        }()
        return formatter.string(from: date)
    }

    func symbols(key: String, make: () -> [String]) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if let symbols = cachedSymbols[key] { return symbols }
        let symbols = make()
        cachedSymbols[key] = symbols
        return symbols
    }
}
