import BirthdayCore
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case zhHant
    case en

    var id: String { rawValue }

    var coreLocale: CalendarFormattingService.AppLocale {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-HK") || preferred.hasPrefix("zh-TW") {
                return .traditionalChinese
            }
            if preferred.hasPrefix("zh") {
                return .simplifiedChinese
            }
            return .english
        case .zhHans: return .simplifiedChinese
        case .zhHant: return .traditionalChinese
        case .en: return .english
        }
    }
}

struct L10n {
    var language: AppLanguage

    func callAsFunction(_ key: Key) -> String {
        let locale = language.coreLocale
        switch locale {
        case .simplifiedChinese: return key.zhHans
        case .traditionalChinese: return key.zhHant
        case .english: return key.en
        }
    }

    struct Key {
        let zhHans: String
        let zhHant: String
        let en: String
    }

    static let browse = Key(zhHans: "浏览", zhHant: "瀏覽", en: "Browse")
    static let manage = Key(zhHans: "管理", zhHant: "管理", en: "Manage")
    static let permissionGranted = Key(zhHans: "已获得通讯录访问权限", zhHant: "已獲得通訊錄存取權限", en: "Contacts access granted")
    static let calendar = Key(zhHans: "日历", zhHant: "日曆", en: "Calendar")
    static let list = Key(zhHans: "生日列表", zhHant: "生日列表", en: "Birthdays")
    static let contacts = Key(zhHans: "通讯录", zhHant: "通訊錄", en: "Contacts")
    static let permissions = Key(zhHans: "权限与设置", zhHant: "權限與設定", en: "Permissions")
    static let settings = Key(zhHans: "设置", zhHant: "設定", en: "Settings")
    static let today = Key(zhHans: "今天", zhHant: "今天", en: "Today")
    static let upcoming = Key(zhHans: "即将到来", zhHant: "即將到來", en: "Upcoming")
    static let month = Key(zhHans: "月", zhHant: "月", en: "Month")
    static let search = Key(zhHans: "搜索", zhHant: "搜尋", en: "Search")
    static let all = Key(zhHans: "全部", zhHant: "全部", en: "All")
    static let sort = Key(zhHans: "排序", zhHant: "排序", en: "Sort")
    static let nearest = Key(zhHans: "最近生日", zhHant: "最近生日", en: "Next birthday")
    static let name = Key(zhHans: "姓名", zhHant: "姓名", en: "Name")
    static let age = Key(zhHans: "年龄", zhHant: "年齡", en: "Age")
    static let calendarKind = Key(zhHans: "历法", zhHant: "曆法", en: "Calendar")
    static let originalDate = Key(zhHans: "原始日期", zhHant: "原始日期", en: "Original date")
    static let thisYearDate = Key(zhHans: "今年日期", zhHant: "今年日期", en: "This year")
    static let nextBirthday = Key(zhHans: "下次生日", zhHant: "下次生日", en: "Next")
    static let unknownAge = Key(zhHans: "未知", zhHant: "未知", en: "Unknown")
    static let needContacts = Key(zhHans: "需要访问通讯录", zhHant: "需要存取通訊錄", en: "Contacts access required")
    static let permissionBody = Key(zhHans: "用于读取和维护联系人生日。生日会直接写回 macOS 通讯录，不会上传联系人，也没有账号登录。", zhHant: "用於讀取和維護聯絡人生日。生日會直接寫回 macOS 通訊錄，不會上傳聯絡人，也沒有帳號登入。", en: "Used to read and maintain birthdays. Changes are written directly to macOS Contacts. Contacts are not uploaded and no account is required.")
    static let allowContacts = Key(zhHans: "允许访问通讯录", zhHant: "允許存取通訊錄", en: "Allow Contacts Access")
    static let openSettings = Key(zhHans: "前往系统设置", zhHant: "前往系統設定", en: "Open System Settings")
    static let permissionDenied = Key(zhHans: "请在系统设置 > 隐私与安全性 > 通讯录中开启访问权限。", zhHant: "請在系統設定 > 隱私權與安全性 > 通訊錄中開啟存取權限。", en: "Enable access in System Settings > Privacy & Security > Contacts.")
    static let noBirthdays = Key(zhHans: "没有生日记录", zhHant: "沒有生日記錄", en: "No birthdays")
    static let noBirthdayOnDay = Key(zhHans: "这一天没有联系人生日。", zhHant: "這一天沒有聯絡人生日。", en: "No contact birthdays on this day.")
    static let written = Key(zhHans: "已写入通讯录", zhHant: "已寫入通訊錄", en: "Written to Contacts")
    static let saveFailed = Key(zhHans: "无法保存到通讯录，请检查权限或该联系人账户是否允许编辑。", zhHant: "無法儲存到通訊錄，請檢查權限或該聯絡人帳戶是否允許編輯。", en: "Could not save to Contacts. Check permissions or whether this account allows editing.")
    static let dataSource = Key(zhHans: "数据来源", zhHant: "資料來源", en: "Data source")
    static let contactsSource = Key(zhHans: "macOS 通讯录", zhHant: "macOS 通訊錄", en: "macOS Contacts")
    static let supportedCalendars = Key(zhHans: "支持的历法", zhHant: "支援的曆法", en: "Supported calendars")
    static let appLanguage = Key(zhHans: "界面语言", zhHant: "介面語言", en: "App language")
    static let displayAge = Key(zhHans: "显示年龄", zhHant: "顯示年齡", en: "Show age")
    static let voiceInput = Key(zhHans: "语音日期输入", zhHant: "語音日期輸入", en: "Voice date input")
    static let voicePlaceholder = Key(zhHans: "例如：农历六月初八是公历几号", zhHant: "例如：農曆六月初八是西曆幾號", en: "Example: Chinese lunar sixth month eighth day")
    static let convertDate = Key(zhHans: "换算", zhHant: "換算", en: "Convert")
    static let listening = Key(zhHans: "正在听写…", zhHant: "正在聽寫…", en: "Listening...")
    static let startListening = Key(zhHans: "开始听写", zhHant: "開始聽寫", en: "Start dictation")
    static let stopListening = Key(zhHans: "停止听写", zhHant: "停止聽寫", en: "Stop dictation")
    static let invalidDatePhrase = Key(zhHans: "没有识别出可换算的生日日期。", zhHant: "沒有識別出可換算的生日日期。", en: "No convertible birthday date was recognized.")
    static let leapMonth = Key(zhHans: "闰月", zhHant: "閏月", en: "Leap month")
    static let previousMonth = Key(zhHans: "上个月", zhHant: "上個月", en: "Previous month")
    static let nextMonth = Key(zhHans: "下个月", zhHant: "下個月", en: "Next month")
    static let navigateToPreviousMonth = Key(zhHans: "切换到上一个月份", zhHant: "切換到上一個月份", en: "Navigate to the previous month")
    static let navigateToNextMonth = Key(zhHans: "切换到下一个月份", zhHant: "切換到下一個月份", en: "Navigate to the next month")
    static let refreshContacts = Key(zhHans: "刷新通讯录", zhHant: "重新整理通訊錄", en: "Refresh Contacts")
    static let openContact = Key(zhHans: "打开联系人", zhHant: "打開聯絡人", en: "Open contact")
}

extension L10n.Key {
    static let browse = L10n.browse
    static let manage = L10n.manage
    static let permissionGranted = L10n.permissionGranted
    static let calendar = L10n.calendar
    static let list = L10n.list
    static let contacts = L10n.contacts
    static let permissions = L10n.permissions
    static let settings = L10n.settings
    static let today = L10n.today
    static let upcoming = L10n.upcoming
    static let month = L10n.month
    static let search = L10n.search
    static let all = L10n.all
    static let sort = L10n.sort
    static let nearest = L10n.nearest
    static let name = L10n.name
    static let age = L10n.age
    static let calendarKind = L10n.calendarKind
    static let originalDate = L10n.originalDate
    static let thisYearDate = L10n.thisYearDate
    static let nextBirthday = L10n.nextBirthday
    static let unknownAge = L10n.unknownAge
    static let needContacts = L10n.needContacts
    static let permissionBody = L10n.permissionBody
    static let allowContacts = L10n.allowContacts
    static let openSettings = L10n.openSettings
    static let permissionDenied = L10n.permissionDenied
    static let noBirthdays = L10n.noBirthdays
    static let noBirthdayOnDay = L10n.noBirthdayOnDay
    static let written = L10n.written
    static let saveFailed = L10n.saveFailed
    static let dataSource = L10n.dataSource
    static let contactsSource = L10n.contactsSource
    static let supportedCalendars = L10n.supportedCalendars
    static let appLanguage = L10n.appLanguage
    static let displayAge = L10n.displayAge
    static let voiceInput = L10n.voiceInput
    static let voicePlaceholder = L10n.voicePlaceholder
    static let convertDate = L10n.convertDate
    static let listening = L10n.listening
    static let startListening = L10n.startListening
    static let stopListening = L10n.stopListening
    static let invalidDatePhrase = L10n.invalidDatePhrase
    static let leapMonth = L10n.leapMonth
    static let previousMonth = L10n.previousMonth
    static let nextMonth = L10n.nextMonth
    static let navigateToPreviousMonth = L10n.navigateToPreviousMonth
    static let navigateToNextMonth = L10n.navigateToNextMonth
    static let refreshContacts = L10n.refreshContacts
    static let openContact = L10n.openContact
}
