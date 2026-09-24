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

    package var displayName: String {
        switch self {
        case .system: "System"
        case .zhHans: "简体中文"
        case .zhHant: "繁體中文"
        case .en: "English"
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

    package static let agentAccess = Key(zhHans: "MCP 开关", zhHant: "MCP 開關", en: "MCP")
    package static let agentAccessToggle = Key(zhHans: "允许外部智能体提交联系人草稿", zhHant: "允許外部智慧型代理人提交聯絡人草稿", en: "Let external agents submit contact drafts")
    package static let agentAccessEndpoint = Key(zhHans: "接入地址", zhHant: "接入位址", en: "Endpoint")
    package static let agentAccessTokenLabel = Key(zhHans: "访问令牌", zhHant: "存取權杖", en: "Access token")
    package static let agentAccessCopyToken = Key(zhHans: "拷贝令牌", zhHant: "拷貝權杖", en: "Copy Token")
    package static let agentAccessRotateToken = Key(zhHans: "轮换令牌", zhHant: "輪換權杖", en: "Rotate Token")
    package static let agentAccessRequiresRunning = Key(zhHans: "服务随 App 启停，仅监听本机 127.0.0.1。", zhHant: "服務隨 App 啟停，僅監聽本機 127.0.0.1。", en: "Runs only while the app is open, listening on 127.0.0.1 only.")
    package static let appName = Key(zhHans: "蓝熊名册", zhHant: "藍熊名冊", en: "Bearoster")
    package static let browse = Key(zhHans: "浏览", zhHant: "瀏覽", en: "Browse")
    package static let manage = Key(zhHans: "管理", zhHant: "管理", en: "Manage")
    package static let permissionGranted = Key(zhHans: "已获得通讯录访问权限", zhHant: "已獲得通訊錄存取權限", en: "Contacts access granted")
    package static let calendar = Key(zhHans: "日历", zhHant: "日曆", en: "Calendar")
    package static let list = Key(zhHans: "生日列表", zhHant: "生日列表", en: "Birthdays")
    package static let contacts = Key(zhHans: "通讯录", zhHant: "通訊錄", en: "Contacts")
    package static let permissions = Key(zhHans: "权限与设置", zhHant: "權限與設定", en: "Permissions")
    package static let settings = Key(zhHans: "设置", zhHant: "設定", en: "Settings")
    package static let about = Key(zhHans: "关于", zhHant: "關於", en: "About")
    package static let version = Key(zhHans: "版本号", zhHant: "版本號", en: "Version")
    package static let aboutBody = Key(zhHans: "蓝熊名册适合一次整理大量联系人。默认只填空白项，你也可以选择覆盖已有内容，改动保存前都能先预览。", zhHant: "藍熊名冊適合一次整理大量聯絡人。預設只填空白項，你也可以選擇覆蓋既有內容，改動儲存前都能先預覽。", en: "Bearoster is for cleaning up a lot of contacts at once. It only fills in blanks unless you say otherwise, and shows you every change before it’s saved.")
    package static let today = Key(zhHans: "今天", zhHant: "今天", en: "Today")
    package static let upcoming = Key(zhHans: "即将到来", zhHant: "即將到來", en: "Upcoming")
    package static let month = Key(zhHans: "月", zhHant: "月", en: "Month")
    package static let search = Key(zhHans: "搜索", zhHant: "搜尋", en: "Search")
    package static let filterContacts = Key(zhHans: "筛选", zhHant: "篩選", en: "Filter")
    package static let clearFilters = Key(zhHans: "清除", zhHant: "清除", en: "Clear")
    package static let addCondition = Key(zhHans: "添加条件", zhHant: "新增條件", en: "Add Condition")
    package static let matchAllConditions = Key(zhHans: "满足全部", zhHant: "符合全部", en: "Match All")
    package static let matchAnyCondition = Key(zhHans: "满足任一", zhHant: "符合任一", en: "Match Any")
    package static let all = Key(zhHans: "全部", zhHant: "全部", en: "All")
    package static let library = Key(zhHans: "资料库", zhHant: "資料庫", en: "Library")
    package static let groups = Key(zhHans: "分组", zhHant: "分組", en: "Groups")
    package static let sort = Key(zhHans: "排序", zhHant: "排序", en: "Sort")
    package static let nearest = Key(zhHans: "最近生日", zhHant: "最近生日", en: "Next")
    package static let name = Key(zhHans: "姓名", zhHant: "姓名", en: "Name")
    package static let givenName = Key(zhHans: "名", zhHant: "名", en: "Given name")
    package static let familyName = Key(zhHans: "姓", zhHant: "姓", en: "Family name")
    package static let nickname = Key(zhHans: "昵称", zhHant: "暱稱", en: "Nickname")
    package static let organization = Key(zhHans: "公司", zhHant: "公司", en: "Organization")
    package static let missingField = Key(zhHans: "资料缺失", zhHant: "資料缺漏", en: "Missing info")
    package static let missingPhone = Key(zhHans: "缺电话", zhHant: "缺電話", en: "No phone number")
    package static let missingEmail = Key(zhHans: "缺邮箱", zhHant: "缺電子郵件", en: "No email address")
    package static let missingOrganization = Key(zhHans: "缺公司", zhHant: "缺公司", en: "No organization")
    package static let department = Key(zhHans: "部门", zhHant: "部門", en: "Department")
    package static let jobTitle = Key(zhHans: "职位", zhHant: "職位", en: "Job title")
    package static let avatar = Key(zhHans: "头像", zhHant: "頭像", en: "Avatar")
    package static let chooseImage = Key(zhHans: "选择图片", zhHant: "選擇圖片", en: "Choose Image")
    package static let onePerLine = Key(zhHans: "每行一条", zhHant: "每行一筆", en: "One per line")
    package static let age = Key(zhHans: "年龄", zhHant: "年齡", en: "Age")
    package static let birthday = Key(zhHans: "生日", zhHant: "生日", en: "Birthday")
    package static let birthdayStatus = Key(zhHans: "生日状态", zhHant: "生日狀態", en: "Birthday status")
    package static let hasBirthday = Key(zhHans: "有生日", zhHant: "有生日", en: "Has birthday")
    package static let missingBirthday = Key(zhHans: "缺生日", zhHant: "缺生日", en: "No birthday")
    package static let upcomingBirthday = Key(zhHans: "近期生日", zhHant: "近期生日", en: "Birthday soon")
    package static let birthdays = Key(zhHans: "个生日", zhHant: "個生日", en: "birthdays")
    package static let day = Key(zhHans: "天", zhHant: "天", en: "day")
    package static let days = Key(zhHans: "天", zhHant: "天", en: "days")
    package static let birthdayRecords = Key(zhHans: "生日记录", zhHant: "生日記錄", en: "Birthdays")
    package static let addRoster = Key(zhHans: "添加生日", zhHant: "新增生日", en: "Add Birthday")
    package static let deleteRoster = Key(zhHans: "删除生日", zhHant: "刪除生日", en: "Delete Birthday")
    package static let birthDate = Key(zhHans: "出生日期", zhHant: "出生日期", en: "Birth date")
    package static let localOnly = Key(zhHans: "本地保存", zhHant: "本機保存", en: "Local only")
    package static let appleSynced = Key(zhHans: "Apple 通讯录", zhHant: "Apple 通訊錄", en: "Apple Contacts")
    package static let group = Key(zhHans: "分组", zhHant: "分組", en: "Group")
    package static let newContactGroup = Key(zhHans: "新建分组", zhHant: "新增分組", en: "New Group")
    package static let contactGroupName = Key(zhHans: "分组名称", zhHant: "分組名稱", en: "Group name")
    package static let deleteContactGroup = Key(zhHans: "删除分组", zhHant: "刪除分組", en: "Delete Group")
    package static let deleteContactGroupMessage = Key(zhHans: "这只会删除分组，不会删除联系人。", zhHant: "這只會刪除分組，不會刪除聯絡人。", en: "This deletes the group only. Contacts will not be deleted.")
    package static let contactGroupEditFailed = Key(zhHans: "无法编辑通讯录分组，请检查权限或该账户是否允许编辑分组。", zhHant: "無法編輯通訊錄分組，請檢查權限或該帳戶是否允許編輯分組。", en: "Could not edit the contact group. Check permissions or whether this account allows group edits.")
    package static let tags = Key(zhHans: "标签", zhHant: "標籤", en: "Tags")
    package static let appleGroups = Key(zhHans: "Apple 分组", zhHant: "Apple 分組", en: "Apple groups")
    package static let untaggedContacts = Key(zhHans: "未打标签", zhHant: "未打標籤", en: "Untagged")
    package static let addTags = Key(zhHans: "添加标签", zhHant: "新增標籤", en: "Add Tags")
    package static let editTags = Key(zhHans: "编辑标签", zhHant: "編輯標籤", en: "Edit Tags")
    package static let newTag = Key(zhHans: "新标签", zhHant: "新標籤", en: "New Tag")
    package static let newTagPathPlaceholder = Key(zhHans: "新标签，子标签用 / 分隔", zhHant: "新標籤，子標籤用 / 分隔", en: "New tag, use / for child tags")
    package static let newChildTag = Key(zhHans: "新建子标签", zhHant: "新增子標籤", en: "New Child Tag")
    package static let renameTag = Key(zhHans: "重命名", zhHant: "重新命名", en: "Rename")
    package static let changeColor = Key(zhHans: "更改颜色", zhHant: "更改顏色", en: "Change Color")
    package static let deleteTag = Key(zhHans: "删除标签", zhHant: "刪除標籤", en: "Delete Tag")
    package static let deleteTagTitle = Key(zhHans: "删除标签", zhHant: "刪除標籤", en: "Delete Tag")
    package static let deleteTagMessage = Key(zhHans: "这会删除该标签及其子标签，并移除相关联系人关联；不会删除联系人、生日或 Apple 通讯录数据。受影响联系人数量：", zhHant: "這會刪除該標籤及其子標籤，並移除相關聯絡人關聯；不會刪除聯絡人、生日或 Apple 通訊錄資料。受影響聯絡人數量：", en: "This deletes the tag and its child tags, and removes matching contact assignments. Contacts, birthdays, and Apple Contacts data are not deleted. Affected contacts: ")
    package static let removeTag = Key(zhHans: "移除标签", zhHant: "移除標籤", en: "Remove Tag")
    package static let apply = Key(zhHans: "应用", zhHant: "套用", en: "Apply")
    package static let noTags = Key(zhHans: "没有标签", zhHant: "沒有標籤", en: "No tags")
    package static let edit = Key(zhHans: "编辑", zhHant: "編輯", en: "Edit")
    package static let done = Key(zhHans: "完成", zhHant: "完成", en: "Done")
    package static let cancel = Key(zhHans: "取消", zhHant: "取消", en: "Cancel")
    package static let editContact = Key(zhHans: "编辑联系人", zhHant: "編輯聯絡人", en: "Edit Contact")
    package static let contactInfo = Key(zhHans: "联系信息", zhHant: "聯絡資訊", en: "Contact info")
    package static let message = Key(zhHans: "信息", zhHant: "訊息", en: "Message")
    package static let videoCall = Key(zhHans: "视频", zhHant: "視訊", en: "FaceTime")
    package static let phone = Key(zhHans: "电话", zhHant: "電話", en: "Phone")
    package static let email = Key(zhHans: "邮箱", zhHant: "電子郵件", en: "Email")
    package static let address = Key(zhHans: "地址", zhHant: "地址", en: "Address")
    package static let links = Key(zhHans: "链接", zhHant: "連結", en: "Links")
    package static let dates = Key(zhHans: "日期", zhHant: "日期", en: "Dates")
    package static let relations = Key(zhHans: "关系", zhHant: "關係", en: "Relations")
    package static let work = Key(zhHans: "工作", zhHant: "工作", en: "Work")
    package static let notes = Key(zhHans: "备注", zhHant: "備註", en: "Notes")
    package static let notFilled = Key(zhHans: "未填写", zhHant: "未填寫", en: "Not filled")
    package static let readOnlyExtendedFields = Key(zhHans: "这些字段来自 Apple 通讯录，不能在这里编辑。", zhHant: "這些欄位來自 Apple 通訊錄，不能在這裡編輯。", en: "These come from Apple Contacts and can’t be edited here.")
    package static let calendarKind = Key(zhHans: "历法", zhHant: "曆法", en: "Calendar")
    package static let originalDate = Key(zhHans: "原始日期", zhHant: "原始日期", en: "Original date")
    package static let thisYearDate = Key(zhHans: "今年日期", zhHant: "今年日期", en: "This year")
    package static let nextRoster = Key(zhHans: "下次生日", zhHant: "下次生日", en: "Next")
    package static let unknownAge = Key(zhHans: "未知", zhHant: "未知", en: "Unknown")
    package static let needContacts = Key(zhHans: "需要访问通讯录", zhHant: "需要存取通訊錄", en: "Contacts access needed")
    package static let allowContacts = Key(zhHans: "允许访问通讯录", zhHant: "允許存取通訊錄", en: "Allow Contacts Access")
    package static let openSettings = Key(zhHans: "前往系统设置", zhHant: "前往系統設定", en: "Open System Settings")
    package static let permissionDenied = Key(zhHans: "请在系统设置 > 隐私与安全性 > 通讯录中开启访问权限。", zhHant: "請在系統設定 > 隱私權與安全性 > 通訊錄中開啟存取權限。", en: "Enable access in System Settings > Privacy & Security > Contacts.")
    package static let noRosters = Key(zhHans: "没有生日记录", zhHant: "沒有生日記錄", en: "No birthdays found")
    package static let noRosterOnDay = Key(zhHans: "这一天没有联系人生日。", zhHant: "這一天沒有聯絡人生日。", en: "No birthdays on this day.")
    package static let written = Key(zhHans: "已保存到通讯录", zhHant: "已儲存到通訊錄", en: "Saved to Contacts")
    package static let saveFailed = Key(zhHans: "无法保存到通讯录，请检查权限或该联系人账户是否允许编辑。", zhHant: "無法儲存到通訊錄，請檢查權限或該聯絡人帳戶是否允許編輯。", en: "Couldn’t save to Contacts. Check permissions or whether this account allows editing.")
    package static let groupAssignmentFailed = Key(zhHans: "无法添加到通讯录分组，请检查权限或该账户是否允许编辑分组。", zhHant: "無法加入通訊錄分組，請檢查權限或該帳戶是否允許編輯分組。", en: "Couldn’t add contacts to the group. Check permissions or whether this account allows group edits.")
    package static let dataSource = Key(zhHans: "数据来源", zhHant: "資料來源", en: "Data source")
    package static let contactsSource = Key(zhHans: "macOS 通讯录", zhHant: "macOS 通訊錄", en: "macOS Contacts")
    package static let contactFieldAccess = Key(zhHans: "联系人字段访问", zhHant: "聯絡人欄位存取", en: "Contact field access")
    package static let extendedContactFields = Key(zhHans: "读取扩展字段", zhHant: "讀取延伸欄位", en: "Read extended fields")
    package static let extendedContactFieldsBody = Key(zhHans: "会额外读取通讯录里的网址、社交账号、关联人、日期和照片。常用字段不受影响。", zhHant: "會額外讀取通訊錄裡的網址、社群帳號、關聯人、日期和照片。常用欄位不受影響。", en: "Also reads websites, social accounts, related people, dates, and photos from Contacts. Everyday fields keep working either way.")
    package static let basicContactFields = Key(zhHans: "常用字段", zhHant: "常用欄位", en: "Common fields")
    package static let extendedContactFieldsEnabled = Key(zhHans: "扩展字段已开启", zhHant: "延伸欄位已開啟", en: "Extended fields enabled")
    package static let supportedCalendars = Key(zhHans: "支持的历法", zhHant: "支援的曆法", en: "Supported calendars")
    package static let appLanguage = Key(zhHans: "界面语言", zhHant: "介面語言", en: "App language")
    package static let displayAge = Key(zhHans: "显示年龄", zhHant: "顯示年齡", en: "Show age")
    package static let voiceInput = Key(zhHans: "语音日期输入", zhHant: "語音日期輸入", en: "Voice date input")
    package static let voicePlaceholder = Key(zhHans: "例如：农历六月初八是公历几号", zhHant: "例如：農曆六月初八是西曆幾號", en: "Example: What date is lunar 6/8?")
    package static let convertDate = Key(zhHans: "换算", zhHant: "換算", en: "Convert")
    package static let listening = Key(zhHans: "正在听写…", zhHant: "正在聽寫…", en: "Listening…")
    package static let startListening = Key(zhHans: "开始听写", zhHant: "開始聽寫", en: "Start dictation")
    package static let stopListening = Key(zhHans: "停止听写", zhHant: "停止聽寫", en: "Stop dictation")
    package static let invalidDatePhrase = Key(zhHans: "没听出要换算的日期，可以试试「农历六月初八」。", zhHant: "沒聽出要換算的日期，可以試試「農曆六月初八」。", en: "Couldn’t find a date to convert. Try “lunar 6/8.”")
    package static let leapMonth = Key(zhHans: "闰月", zhHant: "閏月", en: "Leap month")
    package static let previousMonth = Key(zhHans: "上个月", zhHant: "上個月", en: "Previous month")
    package static let nextMonth = Key(zhHans: "下个月", zhHant: "下個月", en: "Next month")
    package static let navigateToPreviousMonth = Key(zhHans: "切换到上一个月份", zhHant: "切換到上一個月份", en: "Navigate to the previous month")
    package static let navigateToNextMonth = Key(zhHans: "切换到下一个月份", zhHant: "切換到下一個月份", en: "Navigate to the next month")
    package static let refreshContacts = Key(zhHans: "刷新通讯录", zhHant: "重新整理通訊錄", en: "Refresh Contacts")
    package static let openContact = Key(zhHans: "打开联系人", zhHant: "打開聯絡人", en: "Open contact")
    package static let calculatingRosters = Key(zhHans: "正在计算生日数据", zhHant: "正在計算生日資料", en: "Calculating birthdays")
    package static let selectContacts = Key(zhHans: "选择", zhHant: "選擇", en: "Select")
    package static let selectAll = Key(zhHans: "全选", zhHant: "全選", en: "Select All")
    package static let selectedContacts = Key(zhHans: "已选择", zhHant: "已選擇", en: "Selected")
    package static let deleteContacts = Key(zhHans: "删除联系人", zhHant: "刪除聯絡人", en: "Delete Contacts")
    package static let deleteContactsTitle = Key(zhHans: "删除联系人？", zhHant: "刪除聯絡人？", en: "Delete contacts?")
    package static let deleteContactsMessage = Key(zhHans: "这会从 macOS 通讯录中删除所选联系人，并可能同步到 iCloud。此操作无法从蓝熊名册中撤销。", zhHant: "這會從 macOS 通訊錄中刪除所選聯絡人，並可能同步到 iCloud。此操作無法從藍熊名冊中復原。", en: "This deletes the selected contacts from macOS Contacts and may sync to iCloud. It can’t be undone in Bearoster.")
    package static let contactsDeleted = Key(zhHans: "已删除联系人", zhHant: "已刪除聯絡人", en: "Contacts deleted")
    package static let deleteContactsFailed = Key(zhHans: "无法删除联系人，请检查通讯录权限或账户是否允许编辑。", zhHant: "無法刪除聯絡人，請檢查通訊錄權限或帳戶是否允許編輯。", en: "Could not delete contacts. Check Contacts permission or whether the account allows editing.")
    package static let contactGroupAccess = Key(zhHans: "通讯录分组访问", zhHant: "通訊錄分組存取", en: "Contact group access")
    package static let allContactsAccess = Key(zhHans: "全部通讯录", zhHant: "全部通訊錄", en: "All contacts")
    package static let selectedGroupsAccess = Key(zhHans: "仅选择的分组", zhHant: "僅選取的分組", en: "Selected groups only")
    package static let contactGroupAccessBody = Key(zhHans: "这是蓝熊名册的本地访问范围。macOS 仍然按应用授权通讯录，蓝熊名册只会显示和计算你选的分组。", zhHant: "這是藍熊名冊的本機存取範圍。macOS 仍然以應用程式為單位授權通訊錄，藍熊名冊只會顯示和計算你選取的分組。", en: "This is Bearoster’s local access scope. macOS still gives the app Contacts access, but Bearoster only shows and calculates the groups you select.")
    package static let includeUngroupedContacts = Key(zhHans: "包含未分组联系人", zhHant: "包含未分組聯絡人", en: "Include ungrouped contacts")
    package static let ungroupedContacts = Key(zhHans: "未分组联系人", zhHant: "未分組聯絡人", en: "Ungrouped contacts")
    package static let noContactGroups = Key(zhHans: "Apple 通讯录里还没有分组。", zhHant: "Apple 通訊錄裡還沒有分組。", en: "No groups in Apple Contacts yet.")
    package static let clearSelection = Key(zhHans: "清空", zhHant: "清空", en: "Clear")
    package static let selectedGroupsSummary = Key(zhHans: "已选择分组", zhHant: "已選取分組", en: "Selected groups")
    package static let batchWritePolicy = Key(zhHans: "写入策略", zhHant: "寫入策略", en: "Write policy")
    package static let batchOnlyEmpty = Key(zhHans: "仅填写空项", zhHant: "僅填寫空項", en: "Fill empty fields only")
    package static let batchOverwrite = Key(zhHans: "覆盖已有值", zhHant: "覆蓋既有值", en: "Overwrite existing values")
    package static let batchRename = Key(zhHans: "批量重命名", zhHant: "批量重新命名", en: "Batch rename")
    package static let batchCommonFields = Key(zhHans: "通用字段", zhHant: "通用欄位", en: "Shared fields")
    package static let batchPreview = Key(zhHans: "预览", zhHant: "預覽", en: "Preview")
    package static let syncHistory = Key(zhHans: "同步与历史", zhHant: "同步與歷史", en: "Sync & History")
    package static let writePolicy = Key(zhHans: "写入模式", zhHant: "寫入模式", en: "Write mode")
    package static let writePolicyLocalOnly = Key(zhHans: "仅本地", zhHant: "僅本機", en: "Local only")
    package static let writePolicyConfirm = Key(zhHans: "确认后写入", zhHant: "確認後寫入", en: "Ask before writing")
    package static let writePolicyAutomatic = Key(zhHans: "自动写入", zhHant: "自動寫入", en: "Write automatically")
    package static let queue = Key(zhHans: "队列", zhHant: "佇列", en: "Queue")
    package static let statusPending = Key(zhHans: "待写入", zhHant: "待寫入", en: "Pending")
    package static let statusConflict = Key(zhHans: "冲突", zhHant: "衝突", en: "Conflict")
    package static let statusFailed = Key(zhHans: "失败", zhHant: "失敗", en: "Failed")
    package static let writePending = Key(zhHans: "写入待处理", zhHant: "寫入待處理", en: "Write Pending Changes")
    package static let history = Key(zhHans: "历史记录", zhHant: "歷史記錄", en: "History")
    package static let syncHistoryBody = Key(zhHans: "应用内的修改先保存在本地，在这里确认写回通讯录、处理冲突、重试失败的操作或撤销改动。", zhHant: "應用內的修改先儲存在本機，在這裡確認寫回通訊錄、處理衝突、重試失敗的操作或復原改動。", en: "Changes are saved locally first. Review them here to write them back to Contacts, resolve conflicts, retry failures, or undo.")
    package static let noEntries = Key(zhHans: "没有记录", zhHant: "沒有記錄", en: "No entries")
    package static let trash = Key(zhHans: "回收站", zhHant: "垃圾桶", en: "Recently Deleted")
    package static let trashLocal = Key(zhHans: "本地回收站", zhHant: "本機垃圾桶", en: "In Recently Deleted")
    package static let restore = Key(zhHans: "恢复", zhHant: "復原", en: "Restore")
    package static let keepMacOSVersion = Key(zhHans: "使用 macOS 版本", zhHant: "使用 macOS 版本", en: "Keep macOS Version")
    package static let keepLocalVersion = Key(zhHans: "用本地版本覆盖", zhHant: "用本機版本覆蓋", en: "Keep My Version")
    package static let statusApplied = Key(zhHans: "已写入", zhHant: "已寫入", en: "Written")
    package static let statusReverted = Key(zhHans: "已放弃", zhHant: "已放棄", en: "Discarded")
    package static let more = Key(zhHans: "更多", zhHant: "更多", en: "More")
    package static let smartGroups = Key(zhHans: "智能分组", zhHant: "智慧分組", en: "Smart groups")
    package static let myTags = Key(zhHans: "我的标签", zhHant: "我的標籤", en: "My tags")
    package static let sync = Key(zhHans: "同步", zhHant: "同步", en: "Sync")
    package static let noDates = Key(zhHans: "没有日期", zhHant: "沒有日期", en: "No dates")
    package static let contactsUnavailable = Key(zhHans: "联系人不可用", zhHant: "聯絡人不可用", en: "Contact unavailable")
    package static let noContacts = Key(zhHans: "没有联系人", zhHant: "沒有聯絡人", en: "No contacts")
    package static let mobilePhone = Key(zhHans: "手机", zhHant: "手機", en: "Mobile")
    package static let moreFields = Key(zhHans: "更多资料", zhHant: "更多資料", en: "More fields")
    package static let newContact = Key(zhHans: "新建联系人", zhHant: "新增聯絡人", en: "New contact")
    package static let searchContactsPrompt = Key(zhHans: "搜索姓名、公司、标签", zhHant: "搜尋姓名、公司、標籤", en: "Search names, companies, and tags")
    package static let showSidebar = Key(zhHans: "显示边栏", zhHant: "顯示側邊欄", en: "Show sidebar")
    package static let hideSidebar = Key(zhHans: "隐藏边栏", zhHant: "隱藏側邊欄", en: "Hide sidebar")
    package static let progressPreparing = Key(zhHans: "准备生日", zhHant: "準備生日", en: "Preparing birthdays")
    package static let progressFiltering = Key(zhHans: "筛选生日", zhHant: "篩選生日", en: "Filtering birthdays")
    package static let progressSorting = Key(zhHans: "排序生日", zhHant: "排序生日", en: "Sorting birthdays")
    package static let progressUpdating = Key(zhHans: "更新生日", zhHant: "更新生日", en: "Updating birthdays")
    package static let progressReadingContacts = Key(zhHans: "读取 macOS 通讯录", zhHant: "讀取 macOS 通訊錄", en: "Reading macOS Contacts")
    package static let voiceAccessRequired = Key(zhHans: "需要麦克风和语音识别权限，可以在系统设置 > 隐私与安全性中开启。", zhHant: "需要麥克風和語音辨識權限，可以在系統設定 > 隱私權與安全性中開啟。", en: "Bearoster needs access to the microphone and speech recognition. You can turn both on in System Settings › Privacy & Security.")
    package static let voiceLanguageUnavailable = Key(zhHans: "当前语言不支持语音识别。", zhHant: "目前語言不支援語音辨識。", en: "Speech recognition isn’t available for this language.")
}

extension L10n.Key {
    package static let agentAccess = L10n.agentAccess
    package static let agentAccessToggle = L10n.agentAccessToggle
    package static let agentAccessEndpoint = L10n.agentAccessEndpoint
    package static let agentAccessTokenLabel = L10n.agentAccessTokenLabel
    package static let agentAccessCopyToken = L10n.agentAccessCopyToken
    package static let agentAccessRotateToken = L10n.agentAccessRotateToken
    package static let agentAccessRequiresRunning = L10n.agentAccessRequiresRunning
    package static let appName = L10n.appName
    package static let browse = L10n.browse
    package static let manage = L10n.manage
    package static let permissionGranted = L10n.permissionGranted
    package static let calendar = L10n.calendar
    package static let list = L10n.list
    package static let contacts = L10n.contacts
    package static let permissions = L10n.permissions
    package static let settings = L10n.settings
    package static let about = L10n.about
    package static let version = L10n.version
    package static let aboutBody = L10n.aboutBody
    package static let today = L10n.today
    package static let upcoming = L10n.upcoming
    package static let month = L10n.month
    package static let search = L10n.search
    package static let filterContacts = L10n.filterContacts
    package static let clearFilters = L10n.clearFilters
    package static let addCondition = L10n.addCondition
    package static let matchAllConditions = L10n.matchAllConditions
    package static let matchAnyCondition = L10n.matchAnyCondition
    package static let all = L10n.all
    package static let library = L10n.library
    package static let groups = L10n.groups
    package static let sort = L10n.sort
    package static let nearest = L10n.nearest
    package static let name = L10n.name
    package static let givenName = L10n.givenName
    package static let familyName = L10n.familyName
    package static let nickname = L10n.nickname
    package static let organization = L10n.organization
    package static let missingField = L10n.missingField
    package static let missingPhone = L10n.missingPhone
    package static let missingEmail = L10n.missingEmail
    package static let missingOrganization = L10n.missingOrganization
    package static let department = L10n.department
    package static let jobTitle = L10n.jobTitle
    package static let avatar = L10n.avatar
    package static let chooseImage = L10n.chooseImage
    package static let onePerLine = L10n.onePerLine
    package static let age = L10n.age
    package static let birthday = L10n.birthday
    package static let birthdayStatus = L10n.birthdayStatus
    package static let hasBirthday = L10n.hasBirthday
    package static let missingBirthday = L10n.missingBirthday
    package static let upcomingBirthday = L10n.upcomingBirthday
    package static let birthdays = L10n.birthdays
    package static let day = L10n.day
    package static let days = L10n.days
    package static let birthdayRecords = L10n.birthdayRecords
    package static let addRoster = L10n.addRoster
    package static let deleteRoster = L10n.deleteRoster
    package static let birthDate = L10n.birthDate
    package static let localOnly = L10n.localOnly
    package static let appleSynced = L10n.appleSynced
    package static let group = L10n.group
    package static let newContactGroup = L10n.newContactGroup
    package static let contactGroupName = L10n.contactGroupName
    package static let deleteContactGroup = L10n.deleteContactGroup
    package static let deleteContactGroupMessage = L10n.deleteContactGroupMessage
    package static let contactGroupEditFailed = L10n.contactGroupEditFailed
    package static let tags = L10n.tags
    package static let appleGroups = L10n.appleGroups
    package static let untaggedContacts = L10n.untaggedContacts
    package static let addTags = L10n.addTags
    package static let editTags = L10n.editTags
    package static let newTag = L10n.newTag
    package static let newTagPathPlaceholder = L10n.newTagPathPlaceholder
    package static let newChildTag = L10n.newChildTag
    package static let renameTag = L10n.renameTag
    package static let changeColor = L10n.changeColor
    package static let deleteTag = L10n.deleteTag
    package static let deleteTagTitle = L10n.deleteTagTitle
    package static let deleteTagMessage = L10n.deleteTagMessage
    package static let removeTag = L10n.removeTag
    package static let apply = L10n.apply
    package static let noTags = L10n.noTags
    package static let edit = L10n.edit
    package static let done = L10n.done
    package static let cancel = L10n.cancel
    package static let editContact = L10n.editContact
    package static let contactInfo = L10n.contactInfo
    package static let message = L10n.message
    package static let videoCall = L10n.videoCall
    package static let phone = L10n.phone
    package static let email = L10n.email
    package static let address = L10n.address
    package static let links = L10n.links
    package static let dates = L10n.dates
    package static let relations = L10n.relations
    package static let work = L10n.work
    package static let notes = L10n.notes
    package static let notFilled = L10n.notFilled
    package static let readOnlyExtendedFields = L10n.readOnlyExtendedFields
    package static let calendarKind = L10n.calendarKind
    package static let originalDate = L10n.originalDate
    package static let thisYearDate = L10n.thisYearDate
    package static let nextRoster = L10n.nextRoster
    package static let unknownAge = L10n.unknownAge
    package static let needContacts = L10n.needContacts
    package static let allowContacts = L10n.allowContacts
    package static let openSettings = L10n.openSettings
    package static let permissionDenied = L10n.permissionDenied
    package static let noRosters = L10n.noRosters
    package static let noRosterOnDay = L10n.noRosterOnDay
    package static let written = L10n.written
    package static let saveFailed = L10n.saveFailed
    package static let groupAssignmentFailed = L10n.groupAssignmentFailed
    package static let dataSource = L10n.dataSource
    package static let contactsSource = L10n.contactsSource
    package static let contactFieldAccess = L10n.contactFieldAccess
    package static let extendedContactFields = L10n.extendedContactFields
    package static let extendedContactFieldsBody = L10n.extendedContactFieldsBody
    package static let basicContactFields = L10n.basicContactFields
    package static let extendedContactFieldsEnabled = L10n.extendedContactFieldsEnabled
    package static let supportedCalendars = L10n.supportedCalendars
    package static let appLanguage = L10n.appLanguage
    package static let displayAge = L10n.displayAge
    package static let voiceInput = L10n.voiceInput
    package static let voicePlaceholder = L10n.voicePlaceholder
    package static let convertDate = L10n.convertDate
    package static let listening = L10n.listening
    package static let startListening = L10n.startListening
    package static let stopListening = L10n.stopListening
    package static let invalidDatePhrase = L10n.invalidDatePhrase
    package static let leapMonth = L10n.leapMonth
    package static let previousMonth = L10n.previousMonth
    package static let nextMonth = L10n.nextMonth
    package static let navigateToPreviousMonth = L10n.navigateToPreviousMonth
    package static let navigateToNextMonth = L10n.navigateToNextMonth
    package static let refreshContacts = L10n.refreshContacts
    package static let openContact = L10n.openContact
    package static let calculatingRosters = L10n.calculatingRosters
    package static let selectContacts = L10n.selectContacts
    package static let selectAll = L10n.selectAll
    package static let selectedContacts = L10n.selectedContacts
    package static let deleteContacts = L10n.deleteContacts
    package static let deleteContactsTitle = L10n.deleteContactsTitle
    package static let deleteContactsMessage = L10n.deleteContactsMessage
    package static let contactsDeleted = L10n.contactsDeleted
    package static let deleteContactsFailed = L10n.deleteContactsFailed
    package static let contactGroupAccess = L10n.contactGroupAccess
    package static let allContactsAccess = L10n.allContactsAccess
    package static let selectedGroupsAccess = L10n.selectedGroupsAccess
    package static let contactGroupAccessBody = L10n.contactGroupAccessBody
    package static let includeUngroupedContacts = L10n.includeUngroupedContacts
    package static let ungroupedContacts = L10n.ungroupedContacts
    package static let noContactGroups = L10n.noContactGroups
    package static let clearSelection = L10n.clearSelection
    package static let selectedGroupsSummary = L10n.selectedGroupsSummary
    package static let batchWritePolicy = L10n.batchWritePolicy
    package static let batchOnlyEmpty = L10n.batchOnlyEmpty
    package static let batchOverwrite = L10n.batchOverwrite
    package static let batchRename = L10n.batchRename
    package static let batchCommonFields = L10n.batchCommonFields
    package static let batchPreview = L10n.batchPreview
    package static let syncHistory = L10n.syncHistory
    package static let showSidebar = L10n.showSidebar
    package static let hideSidebar = L10n.hideSidebar
    package static let progressPreparing = L10n.progressPreparing
    package static let progressFiltering = L10n.progressFiltering
    package static let progressSorting = L10n.progressSorting
    package static let progressUpdating = L10n.progressUpdating
    package static let progressReadingContacts = L10n.progressReadingContacts
    package static let voiceAccessRequired = L10n.voiceAccessRequired
    package static let voiceLanguageUnavailable = L10n.voiceLanguageUnavailable
    package static let writePolicy = L10n.writePolicy
    package static let writePolicyLocalOnly = L10n.writePolicyLocalOnly
    package static let writePolicyConfirm = L10n.writePolicyConfirm
    package static let writePolicyAutomatic = L10n.writePolicyAutomatic
    package static let queue = L10n.queue
    package static let statusPending = L10n.statusPending
    package static let statusConflict = L10n.statusConflict
    package static let statusFailed = L10n.statusFailed
    package static let writePending = L10n.writePending
    package static let history = L10n.history
    package static let syncHistoryBody = L10n.syncHistoryBody
    package static let noEntries = L10n.noEntries
    package static let trash = L10n.trash
    package static let trashLocal = L10n.trashLocal
    package static let restore = L10n.restore
    package static let keepMacOSVersion = L10n.keepMacOSVersion
    package static let keepLocalVersion = L10n.keepLocalVersion
    package static let statusApplied = L10n.statusApplied
    package static let statusReverted = L10n.statusReverted
    package static let more = L10n.more
    package static let smartGroups = L10n.smartGroups
    package static let myTags = L10n.myTags
    package static let sync = L10n.sync
    package static let noDates = L10n.noDates
    package static let contactsUnavailable = L10n.contactsUnavailable
    package static let mobilePhone = L10n.mobilePhone
    package static let moreFields = L10n.moreFields
    package static let newContact = L10n.newContact
    package static let searchContactsPrompt = L10n.searchContactsPrompt
    package static let noContacts = L10n.noContacts
}
