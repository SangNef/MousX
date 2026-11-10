import AppKit
import SwiftUI
import Combine
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let prefs = Preferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        prefs.$enabled
            .receive(on: RunLoop.main)
            .sink { [weak self] on in
                if !on { SmoothScroller.shared.stop(); ButtonHandler.shared.cancel() }
                self?.updateStatusIcon(enabled: on)
            }
            .store(in: &cancellables)

        if Permissions.isTrusted {
            EventTapManager.shared.start()
        } else {
            Permissions.requestAccess()
            waitForPermission()
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        EventTapManager.shared.stop()
    }

    /// Mở lại app (ví dụ nhấp đúp trong Finder) => hiện cửa sổ cài đặt.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: - Quyền Trợ năng

    private func waitForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard Permissions.isTrusted else { return }
            t.invalidate()
            self?.permissionTimer = nil
            EventTapManager.shared.start()
            Permissions.shared.refresh()
        }
    }

    // MARK: - Thanh menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon(enabled: prefs.enabled)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateStatusIcon(enabled: Bool) {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: enabled ? "computermouse.fill" : "computermouse",
                            accessibilityDescription: "MousX")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !enabled
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "MousX", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        if !Permissions.isTrusted {
            let warn = NSMenuItem(title: "⚠︎ Cần cấp quyền Trợ năng…", action: #selector(openAccessibility), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Bật MousX", action: #selector(toggleEnabled), keyEquivalent: "e")
        toggle.target = self
        toggle.state = prefs.enabled ? .on : .off
        menu.addItem(toggle)

        let smooth = NSMenuItem(title: "Cuộn mượt", action: #selector(toggleSmooth), keyEquivalent: "")
        smooth.target = self
        smooth.state = prefs.smoothScroll ? .on : .off
        menu.addItem(smooth)

        let gestures = NSMenuItem(title: "Cử chỉ bằng nút giữ + kéo", action: #selector(toggleGestures), keyEquivalent: "")
        gestures.target = self
        gestures.state = prefs.gestureButton != .none ? .on : .off
        menu.addItem(gestures)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Cài đặt…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Thoát MousX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleEnabled() { prefs.enabled.toggle() }
    @objc private func toggleSmooth() { prefs.smoothScroll.toggle() }
    @objc private func toggleGestures() {
        prefs.gestureButton = prefs.gestureButton == .none ? .middle : .none
    }

    @objc private func openAccessibility() {
        Permissions.requestAccess()
        Permissions.openAccessibilitySettings()
        waitForPermission()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            hosting.sizingOptions = [] // tự đặt kích thước, để nội dung tràn cả vùng thanh tiêu đề
            let w = NSWindow(contentViewController: hosting)
            w.setContentSize(NSSize(width: 780, height: 580))
            w.title = "MousX"
            // Kiểu System Settings: thanh tiêu đề trong suốt, nội dung tràn lên dưới nút cửa sổ.
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 780, height: 580))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
