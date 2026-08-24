import RosterCore
import Foundation

package enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans
    case zhHant
    case en

    package var id: String { rawValue }

    package var coreLocale: CalendarFormattingService.AppLocale {
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

package struct L10n {
    package var language: AppLanguage

    package func callAsFunction(_ key: Key) -> String {
        let locale = language.coreLocale
        switch locale {
        case .simplifiedChinese: return key.zhHans
        case .traditionalChinese: return key.zhHant
        case .english: return key.en
        }
    }

    package struct Key {
        package let zhHans: String
        package let zhHant: String
        package let en: String
    }

    package static let appName = Key(zhHans: "名册", zhHant: "名冊", en: "Roster")
    package static let browse = Key(zhHans: "浏览", zhHant: "瀏覽", en: "Browse")
    package static let manage = Key(zhHans: "管理", zhHant: "管理", en: "Manage")
    package static let permissionGranted = Key(zhHans: "已获得通讯录访问权限", zhHant: "已獲得通訊錄存取權限", en: "Contacts access granted")
    package static let calendar = Key(zhHans: "日历", zhHant: "日曆", en: "Calendar")
    package static let list = Key(zhHans: "生日列表", zhHant: "生日列表", en: "Rosters")
    package static let contacts = Key(zhHans: "通讯录", zhHant: "通訊錄", en: "Contacts")
    package static let permissions = Key(zhHans: "权限与设置", zhHant: "權限與設定", en: "Permissions")
    package static let settings = Key(zhHans: "设置", zhHant: "設定", en: "Settings")
    package static let about = Key(zhHans: "关于", zhHant: "關於", en: "About")
    package static let version = Key(zhHans: "版本号", zhHant: "版本號", en: "Version")
    package static let aboutBody = Key(zhHans: "这套界面是为批量整理联系人设计的，默认保守写入，支持覆盖选择和变更预览，适合大批量维护通讯录。", zhHant: "這套介面是為批量整理聯絡人設計的，預設保守寫入，支援覆蓋選擇和變更預覽，適合大批量維護通訊錄。", en: "This interface is designed for bulk contact organization. It defaults to conservative writes, supports overwrite selection and change previews, and is built for large-scale contact maintenance.")
    package static let today = Key(zhHans: "今天", zhHant: "今天", en: "Today")
    package static let upcoming = Key(zhHans: "即将到来", zhHant: "即將到來", en: "Upcoming")
    package static let month = Key(zhHans: "月", zhHant: "月", en: "Month")
    package static let search = Key(zhHans: "搜索", zhHant: "搜尋", en: "Search")
    package static let all = Key(zhHans: "全部", zhHant: "全部", en: "All")
    package static let library = Key(zhHans: "资料库", zhHant: "資料庫", en: "Library")
    package static let groups = Key(zhHans: "分组", zhHant: "分組", en: "Groups")
    package static let sort = Key(zhHans: "排序", zhHant: "排序", en: "Sort")
    package static let nearest = Key(zhHans: "最近生日", zhHant: "最近生日", en: "Next birthday")
    package static let name = Key(zhHans: "姓名", zhHant: "姓名", en: "Name")
    package static let givenName = Key(zhHans: "名", zhHant: "名", en: "Given name")
    package static let familyName = Key(zhHans: "姓", zhHant: "姓", en: "Family name")
    package static let nickname = Key(zhHans: "昵称", zhHant: "暱稱", en: "Nickname")
    package static let organization = Key(zhHans: "公司", zhHant: "公司", en: "Organization")
    package static let department = Key(zhHans: "部门", zhHant: "部門", en: "Department")
    package static let jobTitle = Key(zhHans: "职位", zhHant: "職位", en: "Job title")
    package static let avatar = Key(zhHans: "头像", zhHant: "頭像", en: "Avatar")
    package static let chooseImage = Key(zhHans: "选择图片", zhHant: "選擇圖片", en: "Choose Image")
    package static let onePerLine = Key(zhHans: "每行一条", zhHant: "每行一筆", en: "One per line")
    package static let age = Key(zhHans: "年龄", zhHant: "年齡", en: "Age")
    package static let birthday = Key(zhHans: "生日", zhHant: "生日", en: "Birthday")
    package static let birthdays = Key(zhHans: "个生日", zhHant: "個生日", en: "birthdays")
    package static let birthdayRecords = Key(zhHans: "生日记录", zhHant: "生日記錄", en: "Roster records")
    package static let addRoster = Key(zhHans: "添加生日", zhHant: "新增生日", en: "Add birthday")
    package static let deleteRoster = Key(zhHans: "删除生日", zhHant: "刪除生日", en: "Delete birthday")
    package static let birthDate = Key(zhHans: "出生日期", zhHant: "出生日期", en: "Birth date")
    package static let localOnly = Key(zhHans: "本地保存", zhHant: "本機保存", en: "Local only")
    package static let appleSynced = Key(zhHans: "Apple 通讯录", zhHant: "Apple 通訊錄", en: "Apple Contacts")
    package static let group = Key(zhHans: "分组", zhHant: "分組", en: "Group")
    package static let tags = Key(zhHans: "标签", zhHant: "標籤", en: "Tags")
    package static let appleGroups = Key(zhHans: "Apple 分组", zhHant: "Apple 分組", en: "Apple Groups")
    package static let untaggedContacts = Key(zhHans: "未打标签", zhHant: "未打標籤", en: "Untagged")
    package static let addTags = Key(zhHans: "添加标签", zhHant: "新增標籤", en: "Add Tags")
    package static let editTags = Key(zhHans: "编辑标签", zhHant: "編輯標籤", en: "Edit Tags")
    package static let newTag = Key(zhHans: "新标签", zhHant: "新標籤", en: "New tag")
    package static let newTagPathPlaceholder = Key(zhHans: "新标签，子标签用 / 分隔", zhHant: "新標籤，子標籤用 / 分隔", en: "New tag, use / for child tags")
    package static let newChildTag = Key(zhHans: "新建子标签", zhHant: "新增子標籤", en: "New Child Tag")
    package static let renameTag = Key(zhHans: "重命名", zhHant: "重新命名", en: "Rename")
    package static let changeColor = Key(zhHans: "更改颜色", zhHant: "更改顏色", en: "Change Color")
    package static let deleteTag = Key(zhHans: "删除标签", zhHant: "刪除標籤", en: "Delete Tag")
    package static let deleteTagTitle = Key(zhHans: "删除标签", zhHant: "刪除標籤", en: "Delete tag")
    package static let deleteTagMessage = Key(zhHans: "这会删除该标签及其子标签，并移除相关联系人关联；不会删除联系人、生日或 Apple 通讯录数据。受影响联系人数量：", zhHant: "這會刪除該標籤及其子標籤，並移除相關聯絡人關聯；不會刪除聯絡人、生日或 Apple 通訊錄資料。受影響聯絡人數量：", en: "This deletes the tag and its child tags, and removes matching contact assignments. Contacts, birthdays, and Apple Contacts data are not deleted. Affected contacts: ")
    package static let removeTag = Key(zhHans: "移除标签", zhHant: "移除標籤", en: "Remove tag")
    package static let apply = Key(zhHans: "应用", zhHant: "套用", en: "Apply")
    package static let noTags = Key(zhHans: "没有标签", zhHant: "沒有標籤", en: "No tags")
    package static let edit = Key(zhHans: "编辑", zhHant: "編輯", en: "Edit")
    package static let done = Key(zhHans: "完成", zhHant: "完成", en: "Done")
    package static let cancel = Key(zhHans: "取消", zhHant: "取消", en: "Cancel")
    package static let editContact = Key(zhHans: "编辑联系人", zhHant: "編輯聯絡人", en: "Edit Contact")
    package static let contactInfo = Key(zhHans: "联系信息", zhHant: "聯絡資訊", en: "Contact Info")
    package static let phone = Key(zhHans: "电话", zhHant: "電話", en: "Phone")
    package static let email = Key(zhHans: "邮箱", zhHant: "電子郵件", en: "Email")
    package static let address = Key(zhHans: "地址", zhHant: "地址", en: "Address")
    package static let links = Key(zhHans: "链接", zhHant: "連結", en: "Links")
    package static let dates = Key(zhHans: "日期", zhHant: "日期", en: "Dates")
    package static let relations = Key(zhHans: "关系", zhHant: "關係", en: "Relations")
    package static let work = Key(zhHans: "工作", zhHant: "工作", en: "Work")
    package static let notes = Key(zhHans: "备注", zhHant: "備註", en: "Notes")
    package static let notFilled = Key(zhHans: "未填写", zhHant: "未填寫", en: "Not filled")
    package static let readOnlyExtendedFields = Key(zhHans: "其它扩展字段当前只从 Apple 通讯录读取。", zhHant: "其它延伸欄位目前只從 Apple 通訊錄讀取。", en: "Other extended fields are currently read from Apple Contacts.")
    package static let calendarKind = Key(zhHans: "历法", zhHant: "曆法", en: "Calendar")
    package static let originalDate = Key(zhHans: "原始日期", zhHant: "原始日期", en: "Original date")
    package static let thisYearDate = Key(zhHans: "今年日期", zhHant: "今年日期", en: "This year")
    package static let nextRoster = Key(zhHans: "下次生日", zhHant: "下次生日", en: "Next")
    package static let unknownAge = Key(zhHans: "未知", zhHant: "未知", en: "Unknown")
    package static let needContacts = Key(zhHans: "需要访问通讯录", zhHant: "需要存取通訊錄", en: "Contacts access required")
    package static let permissionBody = Key(zhHans: "用于读取和维护联系人生日。生日会直接写回 macOS 通讯录，不会上传联系人，也没有账号登录。", zhHant: "用於讀取和維護聯絡人生日。生日會直接寫回 macOS 通訊錄，不會上傳聯絡人，也沒有帳號登入。", en: "Used to read and maintain birthdays. Changes are written directly to macOS Contacts. Contacts are not uploaded and no account is required.")
    package static let allowContacts = Key(zhHans: "允许访问通讯录", zhHant: "允許存取通訊錄", en: "Allow Contacts Access")
    package static let openSettings = Key(zhHans: "前往系统设置", zhHant: "前往系統設定", en: "Open System Settings")
    package static let permissionDenied = Key(zhHans: "请在系统设置 > 隐私与安全性 > 通讯录中开启访问权限。", zhHant: "請在系統設定 > 隱私權與安全性 > 通訊錄中開啟存取權限。", en: "Enable access in System Settings > Privacy & Security > Contacts.")
    package static let noRosters = Key(zhHans: "没有生日记录", zhHant: "沒有生日記錄", en: "No birthdays")
    package static let noRosterOnDay = Key(zhHans: "这一天没有联系人生日。", zhHant: "這一天沒有聯絡人生日。", en: "No contact birthdays on this day.")
    package static let written = Key(zhHans: "已写入通讯录", zhHant: "已寫入通訊錄", en: "Written to Contacts")
    package static let saveFailed = Key(zhHans: "无法保存到通讯录，请检查权限或该联系人账户是否允许编辑。", zhHant: "無法儲存到通訊錄，請檢查權限或該聯絡人帳戶是否允許編輯。", en: "Could not save to Contacts. Check permissions or whether this account allows editing.")
    package static let groupAssignmentFailed = Key(zhHans: "无法添加到通讯录分组，请检查权限或该账户是否允许编辑分组。", zhHant: "無法加入通訊錄分組，請檢查權限或該帳戶是否允許編輯分組。", en: "Could not add contacts to the group. Check permissions or whether this account allows group edits.")
    package static let dataSource = Key(zhHans: "数据来源", zhHant: "資料來源", en: "Data source")
    package static let contactsSource = Key(zhHans: "macOS 通讯录", zhHant: "macOS 通訊錄", en: "macOS Contacts")
    package static let contactFieldAccess = Key(zhHans: "联系人字段访问", zhHant: "聯絡人欄位存取", en: "Contact field access")
    package static let extendedContactFields = Key(zhHans: "读取扩展字段", zhHant: "讀取延伸欄位", en: "Read extended fields")
    package static let extendedContactFieldsBody = Key(zhHans: "开启后会额外读取网址、社交账号、关系、日期和头像等扩展字段。常用联系人字段仍然可用。", zhHant: "開啟後會額外讀取網址、社群帳號、關係、日期和頭像等延伸欄位。常用聯絡人欄位仍然可用。", en: "When enabled, Roster additionally reads extended fields like URLs, social profiles, relations, dates, and avatars. Common contact fields remain available.")
    package static let basicContactFields = Key(zhHans: "常用字段", zhHant: "常用欄位", en: "Common fields")
    package static let extendedContactFieldsEnabled = Key(zhHans: "扩展字段已开启", zhHant: "延伸欄位已開啟", en: "Extended fields enabled")
    package static let supportedCalendars = Key(zhHans: "支持的历法", zhHant: "支援的曆法", en: "Supported calendars")
    package static let appLanguage = Key(zhHans: "界面语言", zhHant: "介面語言", en: "App language")
    package static let displayAge = Key(zhHans: "显示年龄", zhHant: "顯示年齡", en: "Show age")
    package static let voiceInput = Key(zhHans: "语音日期输入", zhHant: "語音日期輸入", en: "Voice date input")
    package static let voicePlaceholder = Key(zhHans: "例如：农历六月初八是公历几号", zhHant: "例如：農曆六月初八是西曆幾號", en: "Example: Chinese lunar sixth month eighth day")
    package static let convertDate = Key(zhHans: "换算", zhHant: "換算", en: "Convert")
    package static let listening = Key(zhHans: "正在听写…", zhHant: "正在聽寫…", en: "Listening...")
    package static let startListening = Key(zhHans: "开始听写", zhHant: "開始聽寫", en: "Start dictation")
    package static let stopListening = Key(zhHans: "停止听写", zhHant: "停止聽寫", en: "Stop dictation")
    package static let invalidDatePhrase = Key(zhHans: "没有识别出可换算的生日日期。", zhHant: "沒有識別出可換算的生日日期。", en: "No convertible birthday date was recognized.")
    package static let leapMonth = Key(zhHans: "闰月", zhHant: "閏月", en: "Leap month")
    package static let previousMonth = Key(zhHans: "上个月", zhHant: "上個月", en: "Previous month")
    package static let nextMonth = Key(zhHans: "下个月", zhHant: "下個月", en: "Next month")
    package static let navigateToPreviousMonth = Key(zhHans: "切换到上一个月份", zhHant: "切換到上一個月份", en: "Navigate to the previous month")
    package static let navigateToNextMonth = Key(zhHans: "切换到下一个月份", zhHant: "切換到下一個月份", en: "Navigate to the next month")
    package static let refreshContacts = Key(zhHans: "刷新通讯录", zhHant: "重新整理通訊錄", en: "Refresh Contacts")
    package static let openContact = Key(zhHans: "打开联系人", zhHant: "打開聯絡人", en: "Open contact")
    package static let calculatingRosters = Key(zhHans: "正在计算生日数据", zhHant: "正在計算生日資料", en: "Calculating birthday data")
    package static let selectContacts = Key(zhHans: "选择", zhHant: "選擇", en: "Select")
    package static let selectAll = Key(zhHans: "全选", zhHant: "全選", en: "Select All")
    package static let selectedContacts = Key(zhHans: "已选择", zhHant: "已選擇", en: "Selected")
    package static let deleteContacts = Key(zhHans: "删除联系人", zhHant: "刪除聯絡人", en: "Delete Contacts")
    package static let deleteContactsTitle = Key(zhHans: "删除联系人？", zhHant: "刪除聯絡人？", en: "Delete contacts?")
    package static let deleteContactsMessage = Key(zhHans: "这会从 macOS 通讯录中删除所选联系人，并可能同步到 iCloud。此操作无法从名册中撤销。", zhHant: "這會從 macOS 通訊錄中刪除所選聯絡人，並可能同步到 iCloud。此操作無法從名冊中復原。", en: "This will delete the selected contacts from macOS Contacts and may sync to iCloud. This cannot be undone in Roster.")
    package static let contactsDeleted = Key(zhHans: "已删除联系人", zhHant: "已刪除聯絡人", en: "Contacts deleted")
    package static let deleteContactsFailed = Key(zhHans: "无法删除联系人，请检查通讯录权限或账户是否允许编辑。", zhHant: "無法刪除聯絡人，請檢查通訊錄權限或帳戶是否允許編輯。", en: "Could not delete contacts. Check Contacts permission or whether the account allows editing.")
    package static let contactGroupAccess = Key(zhHans: "通讯录分组访问", zhHant: "通訊錄分組存取", en: "Contact group access")
    package static let allContactsAccess = Key(zhHans: "全部通讯录", zhHant: "全部通訊錄", en: "All contacts")
    package static let selectedGroupsAccess = Key(zhHans: "仅选择的分组", zhHant: "僅選取的分組", en: "Selected groups only")
    package static let contactGroupAccessBody = Key(zhHans: "这是名册内部的访问范围。macOS 仍然按 App 授权通讯录，名册会只显示和计算你选择的分组。", zhHant: "這是名冊內部的存取範圍。macOS 仍然以 App 為單位授權通訊錄，名冊只會顯示和計算你選取的分組。", en: "This is Roster's local access scope. macOS still grants Contacts access to the app, and Roster only displays and calculates selected groups.")
    package static let includeUngroupedContacts = Key(zhHans: "包含未分组联系人", zhHant: "包含未分組聯絡人", en: "Include ungrouped contacts")
    package static let ungroupedContacts = Key(zhHans: "未分组联系人", zhHant: "未分組聯絡人", en: "Ungrouped contacts")
    package static let noContactGroups = Key(zhHans: "没有从 Apple 通讯录读取到分组。", zhHant: "沒有從 Apple 通訊錄讀取到分組。", en: "No groups were found in Apple Contacts.")
    package static let clearSelection = Key(zhHans: "清空", zhHant: "清空", en: "Clear")
    package static let selectedGroupsSummary = Key(zhHans: "已选择分组", zhHant: "已選取分組", en: "Selected groups")
    package static let batchWritePolicy = Key(zhHans: "写入策略", zhHant: "寫入策略", en: "Write policy")
    package static let batchOnlyEmpty = Key(zhHans: "仅补空", zhHant: "僅補空", en: "Fill empty only")
    package static let batchOverwrite = Key(zhHans: "覆盖已有值", zhHant: "覆蓋既有值", en: "Overwrite existing")
    package static let batchRename = Key(zhHans: "批量重命名", zhHant: "批量重新命名", en: "Bulk rename")
    package static let batchCommonFields = Key(zhHans: "共同字段", zhHant: "共同欄位", en: "Common fields")
    package static let batchPreview = Key(zhHans: "预览", zhHant: "預覽", en: "Preview")
}

package extension L10n.Key {
    static let appName = L10n.appName
    static let browse = L10n.browse
    static let manage = L10n.manage
    static let permissionGranted = L10n.permissionGranted
    static let calendar = L10n.calendar
    static let list = L10n.list
    static let contacts = L10n.contacts
    static let permissions = L10n.permissions
    static let settings = L10n.settings
    static let about = L10n.about
    static let version = L10n.version
    static let aboutBody = L10n.aboutBody
    static let today = L10n.today
    static let upcoming = L10n.upcoming
    static let month = L10n.month
    static let search = L10n.search
    static let all = L10n.all
    static let library = L10n.library
    static let groups = L10n.groups
    static let sort = L10n.sort
    static let nearest = L10n.nearest
    static let name = L10n.name
    static let givenName = L10n.givenName
    static let familyName = L10n.familyName
    static let nickname = L10n.nickname
    static let organization = L10n.organization
    static let department = L10n.department
    static let jobTitle = L10n.jobTitle
    static let avatar = L10n.avatar
    static let chooseImage = L10n.chooseImage
    static let onePerLine = L10n.onePerLine
    static let age = L10n.age
    static let birthday = L10n.birthday
    static let birthdays = L10n.birthdays
    static let birthdayRecords = L10n.birthdayRecords
    static let addRoster = L10n.addRoster
    static let deleteRoster = L10n.deleteRoster
    static let birthDate = L10n.birthDate
    static let localOnly = L10n.localOnly
    static let appleSynced = L10n.appleSynced
    static let group = L10n.group
    static let tags = L10n.tags
    static let appleGroups = L10n.appleGroups
    static let untaggedContacts = L10n.untaggedContacts
    static let addTags = L10n.addTags
    static let editTags = L10n.editTags
    static let newTag = L10n.newTag
    static let newTagPathPlaceholder = L10n.newTagPathPlaceholder
    static let newChildTag = L10n.newChildTag
    static let renameTag = L10n.renameTag
    static let changeColor = L10n.changeColor
    static let deleteTag = L10n.deleteTag
    static let deleteTagTitle = L10n.deleteTagTitle
    static let deleteTagMessage = L10n.deleteTagMessage
    static let removeTag = L10n.removeTag
    static let apply = L10n.apply
    static let noTags = L10n.noTags
    static let edit = L10n.edit
    static let done = L10n.done
    static let cancel = L10n.cancel
    static let editContact = L10n.editContact
    static let contactInfo = L10n.contactInfo
    static let phone = L10n.phone
    static let email = L10n.email
    static let address = L10n.address
    static let links = L10n.links
    static let dates = L10n.dates
    static let relations = L10n.relations
    static let work = L10n.work
    static let notes = L10n.notes
    static let notFilled = L10n.notFilled
    static let readOnlyExtendedFields = L10n.readOnlyExtendedFields
    static let calendarKind = L10n.calendarKind
    static let originalDate = L10n.originalDate
    static let thisYearDate = L10n.thisYearDate
    static let nextRoster = L10n.nextRoster
    static let unknownAge = L10n.unknownAge
    static let needContacts = L10n.needContacts
    static let permissionBody = L10n.permissionBody
    static let allowContacts = L10n.allowContacts
    static let openSettings = L10n.openSettings
    static let permissionDenied = L10n.permissionDenied
    static let noRosters = L10n.noRosters
    static let noRosterOnDay = L10n.noRosterOnDay
    static let written = L10n.written
    static let saveFailed = L10n.saveFailed
    static let groupAssignmentFailed = L10n.groupAssignmentFailed
    static let dataSource = L10n.dataSource
    static let contactsSource = L10n.contactsSource
    static let contactFieldAccess = L10n.contactFieldAccess
    static let extendedContactFields = L10n.extendedContactFields
    static let extendedContactFieldsBody = L10n.extendedContactFieldsBody
    static let basicContactFields = L10n.basicContactFields
    static let extendedContactFieldsEnabled = L10n.extendedContactFieldsEnabled
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
    static let calculatingRosters = L10n.calculatingRosters
    static let selectContacts = L10n.selectContacts
    static let selectAll = L10n.selectAll
    static let selectedContacts = L10n.selectedContacts
    static let deleteContacts = L10n.deleteContacts
    static let deleteContactsTitle = L10n.deleteContactsTitle
    static let deleteContactsMessage = L10n.deleteContactsMessage
    static let contactsDeleted = L10n.contactsDeleted
    static let deleteContactsFailed = L10n.deleteContactsFailed
    static let contactGroupAccess = L10n.contactGroupAccess
    static let allContactsAccess = L10n.allContactsAccess
    static let selectedGroupsAccess = L10n.selectedGroupsAccess
    static let contactGroupAccessBody = L10n.contactGroupAccessBody
    static let includeUngroupedContacts = L10n.includeUngroupedContacts
    static let ungroupedContacts = L10n.ungroupedContacts
    static let noContactGroups = L10n.noContactGroups
    static let clearSelection = L10n.clearSelection
    static let selectedGroupsSummary = L10n.selectedGroupsSummary
    static let batchWritePolicy = L10n.batchWritePolicy
    static let batchOnlyEmpty = L10n.batchOnlyEmpty
    static let batchOverwrite = L10n.batchOverwrite
    static let batchRename = L10n.batchRename
    static let batchCommonFields = L10n.batchCommonFields
    static let batchPreview = L10n.batchPreview
}
