import BirthdayCore
import AppKit
import SwiftUI

@main
@MainActor
final class BirthdayApp: NSObject, NSApplicationDelegate {
    private let model = BirthdayAppModel()
    private var window: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = BirthdayApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        if window == nil {
            let rootView = RootView()
                .environment(model)
                .frame(
                    minWidth: BirthdayTheme.Layout.minWindowWidth,
                    idealWidth: BirthdayTheme.Layout.minWindowWidth,
                    maxWidth: .infinity,
                    minHeight: BirthdayTheme.Layout.minWindowHeight,
                    idealHeight: BirthdayTheme.Layout.minWindowHeight,
                    maxHeight: .infinity
                )

            let contentSize = NSSize(
                width: BirthdayTheme.Layout.minWindowWidth,
                height: BirthdayTheme.Layout.minWindowHeight
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
            window.title = "Birthday"
            window.minSize = contentSize
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.sizingOptions = []
            window.contentViewController = hostingController
            window.setFrame(NSRect(origin: .zero, size: window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size), display: false)
            window.setContentSize(contentSize)
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
