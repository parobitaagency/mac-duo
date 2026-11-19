import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var preferences: Preferences!
    private var controller: FoldController!
    private var windows: WindowCoordinator!
    private var updates: UpdateCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences.shared
        self.preferences = preferences
        let controller = FoldController(preferences: preferences)
        self.controller = controller
        if UISnapshots.renderIfRequested(preferences: preferences, controller: controller) {
            NSApp.terminate(nil)
            return
        }
        windows = WindowCoordinator(preferences: preferences, controller: controller)
        updates = UpdateCoordinator(preferences: preferences)
        installMainMenu()
        controller.start()

        // No menu bar icon: opening the app opens its window, closing the
        // window leaves it running. Started at login it stays out of sight.
        if !preferences.hasCompletedOnboarding {
            windows.showOnboarding()
        } else if !launchedAtLogin {
            windows.showSettings()
        }
        updates.checkOnLaunchIfDue()
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.mac-duo.app.checkUpdates"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkUpdatesNow() }
        }
        Log.app.notice("launched \(AppInfo.version, privacy: .public) (\(AppInfo.build, privacy: .public))")
        FileLog.write("app", "launched \(AppInfo.version) (\(AppInfo.build)), sensor \(controller.sensorAvailable), screen recording \(ScreenRecordingPermission.isGranted), model \(MacModel.identifier)")
    }

    private func checkUpdatesNow() {
        Task { await updates.check(interactive: true) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// A login item starts while the Mac is just up; opened by hand, it is not.
    private var launchedAtLogin: Bool {
        LaunchAtLogin.isEnabled && ProcessInfo.processInfo.systemUptime < 180
    }

    /// The app never shows a menu bar, but ⌘W and ⌘Q still work in its window.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem(title: "Quit Mac Duo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }
}
