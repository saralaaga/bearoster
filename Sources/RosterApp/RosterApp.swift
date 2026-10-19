import RosterCore
import RosterShared
import AppKit
import SwiftUI

@main
@MainActor
final class RosterApp: NSObject, NSApplicationDelegate {
    private let model: RosterAppModel
    private var window: NSWindow?

    override init() {
        model = RosterAppModel(e2eFixture: RosterApp.e2eFixture)
        super.init()
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = RosterApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.mainMenu = delegate.makeMainMenu()
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logE2E("applicationDidFinishLaunching")
        showMainWindow()
        Task { await model.refreshContacts() }
        Task { enableAgentAccessForE2E() }
    }

    /// Debug-only: `--roster-e2e agent-import --agent-token <token>` starts the
    /// MCP server with a script-chosen token so e2e never touches the user's
    /// real journal settings. Shipping builds ignore this entirely.
    private func enableAgentAccessForE2E() {
        // useAgentAccessTokenForE2E lives in the !ROSTER_MAS region of the
        // model; keep both gates in sync.
        #if DEBUG && !ROSTER_MAS
        let arguments = ProcessInfo.processInfo.arguments
        guard Self.e2eFixture != nil,
              let index = arguments.firstIndex(of: "--agent-token"),
              arguments.indices.contains(arguments.index(after: index))
        else { return }
        model.useAgentAccessTokenForE2E(arguments[arguments.index(after: index)])
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 程序化构建标准主菜单。App 菜单的退出和 Window 菜单的重开主窗口是
    /// App Review Guideline 4 的硬性要求；Edit 菜单让文本框的拷贝/粘贴
    /// 快捷键走标准响应链。
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: model.l10n(.menuAbout),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: model.l10n(.menuHide),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthers = appMenu.addItem(
            withTitle: model.l10n(.menuHideOthers),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: model.l10n(.menuShowAll),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: model.l10n(.menuQuit),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: model.l10n(.menuFile))
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: model.l10n(.menuCloseWindow),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: model.l10n(.edit))
        editMenuItem.submenu = editMenu
        // undo:/redo: 只在文本编辑器的响应链上，标准 Edit 菜单写法。
        editMenu.addItem(withTitle: model.l10n(.menuUndo), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: model.l10n(.menuRedo), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: model.l10n(.menuCut), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: model.l10n(.menuCopy), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: model.l10n(.menuPaste), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: model.l10n(.selectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: model.l10n(.menuWindow))
        windowMenuItem.submenu = windowMenu
        // 挂到 NSApp.windowsMenu 后，AppKit 会自动把打开的窗口列进菜单。
        NSApplication.shared.windowsMenu = windowMenu
        windowMenu.addItem(
            withTitle: model.l10n(.menuMinimize),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: model.l10n(.menuZoom),
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(.separator())
        // 窗口被关闭时（app 继续运行）仍能从菜单重开主窗口。
        let openItem = windowMenu.addItem(
            withTitle: model.l10n(.menuOpenBearoster),
            action: #selector(openMainWindow),
            keyEquivalent: ""
        )
        openItem.target = self
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            withTitle: model.l10n(.menuBringAllToFront),
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )

        return mainMenu
    }

    @objc private func openMainWindow() {
        showMainWindow()
    }

    private func showMainWindow() {
        logE2E("showMainWindow start")
        if window == nil {
            let rootView = RootView()
                .environment(model)
                .frame(
                    minWidth: RosterTheme.Layout.minWindowWidth,
                    idealWidth: RosterTheme.Layout.minWindowWidth,
                    maxWidth: .infinity,
                    minHeight: RosterTheme.Layout.minWindowHeight,
                    idealHeight: RosterTheme.Layout.minWindowHeight,
                    maxHeight: .infinity
                )

            let contentSize = NSSize(
                width: RosterTheme.Layout.minWindowWidth,
                height: RosterTheme.Layout.minWindowHeight
            )
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: contentSize.width,
                    height: contentSize.height
                ),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = model.l10n(.appName)
            window.minSize = contentSize
            // AppKit 默认在关闭时额外 release 一次窗口，会把这里持有的强引用
            // 变成悬空指针；置 false 后窗口由 self.window 持有，reopen 复用。
            window.isReleasedWhenClosed = false
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.sizingOptions = []
            window.contentViewController = hostingController
            window.setFrame(NSRect(origin: .zero, size: window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size), display: false)
            window.setContentSize(contentSize)
            window.center()
            self.window = window
            logE2E("created window")
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if RosterApp.e2eFixture != nil {
            window?.orderFrontRegardless()
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
        logE2E("ordered window visible=\(window?.isVisible == true)")
    }

    private func logE2E(_ message: String) {
        guard RosterApp.e2eFixture != nil else { return }
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/roster-e2e.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    private static var e2eFixture: RosterE2EFixture? {
        // Debug-only. Shipping builds must not expose the fixture-data path.
        #if !DEBUG
        return nil
        #else
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(where: { $0 == "--roster-e2e" || $0 == "--birthday-e2e" }),
              arguments.indices.contains(arguments.index(after: index))
        else {
            return nil
        }

        let nameIndex = arguments.index(after: index)
        switch arguments[nameIndex] {
        case "contact-drag", "agent-import":
            return RosterE2EFixtures.contactDragAndDrop
        case "store":
            let viewIndex = arguments.index(index, offsetBy: 2)
            let rawView = arguments.indices.contains(viewIndex) ? arguments[viewIndex] : "calendar"
            return RosterE2EFixtures.storeScreenshots(
                selection: SidebarSelection(rawValue: rawView) ?? .calendar
            )
        default:
            return nil
        }
        #endif
    }
}
