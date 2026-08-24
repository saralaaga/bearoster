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
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logE2E("applicationDidFinishLaunching")
        showMainWindow()
        Task { await model.refreshContacts() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(where: { $0 == "--roster-e2e" || $0 == "--birthday-e2e" }),
              arguments.indices.contains(arguments.index(after: index))
        else {
            return nil
        }

        switch arguments[arguments.index(after: index)] {
        case "contact-drag":
            return RosterE2EFixtures.contactDragAndDrop
        default:
            return nil
        }
    }
}
