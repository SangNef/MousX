import AppKit
import CoreGraphics

/// Giá trị đánh dấu các sự kiện do chính MousX tạo ra, để event tap bỏ qua chúng.
let kMousXEventMarker: Int64 = 0x4D6F_7558 // "MouX"

enum SystemActions {
    // CoreDockSendNotification là API riêng của Dock (HIServices). Tra cứu động để
    // không crash nếu Apple gỡ bỏ; có phương án dự phòng bên dưới.
    private typealias CoreDockSendNotificationFn = @convention(c) (CFString, Int32) -> Void
    private static let coreDockSend: CoreDockSendNotificationFn? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(sym, to: CoreDockSendNotificationFn.self)
    }()

    private enum Key {
        static let leftArrow: CGKeyCode = 123
        static let rightArrow: CGKeyCode = 124
        static let downArrow: CGKeyCode = 125
        static let upArrow: CGKeyCode = 126
        static let leftBracket: CGKeyCode = 33
        static let rightBracket: CGKeyCode = 30
        static let f11: CGKeyCode = 103
    }

    static func perform(_ action: ButtonAction) {
        switch action {
        case .passthrough:
            break
        case .back:
            postKey(Key.leftBracket, flags: .maskCommand)
        case .forward:
            postKey(Key.rightBracket, flags: .maskCommand)
        case .missionControl:
            if !dock("com.apple.expose.awake") {
                postKey(Key.upArrow, flags: arrowFlags(.maskControl))
            }
        case .appExpose:
            if !dock("com.apple.expose.front.awake") {
                postKey(Key.downArrow, flags: arrowFlags(.maskControl))
            }
        case .showDesktop:
            if !dock("com.apple.showdesktop.awake") {
                postKey(Key.f11, flags: [.maskSecondaryFn])
            }
        case .launchpad:
            if !dock("com.apple.launchpad.toggle") {
                openApp(["/System/Applications/Launchpad.app", "/System/Applications/Apps.app"])
            }
        case .spaceLeft:
            postKey(Key.leftArrow, flags: arrowFlags(.maskControl))
        case .spaceRight:
            postKey(Key.rightArrow, flags: arrowFlags(.maskControl))
        case .middleClick:
            postClick(button: 2)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private static func dock(_ notification: String) -> Bool {
        guard let fn = coreDockSend else { return false }
        fn(notification as CFString, 0)
        return true
    }

    /// Phím mũi tên thật luôn mang cờ Fn + NumericPad; phím tắt hệ thống cần chúng để khớp.
    private static func arrowFlags(_ extra: CGEventFlags) -> CGEventFlags {
        [extra, .maskSecondaryFn, .maskNumericPad]
    }

    static func postKey(_ code: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: kMousXEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: kMousXEventMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Phát lại một cú click cho nút `button` (số nút CGEvent) tại vị trí con trỏ.
    static func postClick(button: Int64) {
        let loc = CGEvent(source: nil)?.location ?? .zero
        let btn = CGMouseButton(rawValue: UInt32(button)) ?? .center
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc, mouseButton: btn) else { continue }
            e.setIntegerValueField(.mouseEventButtonNumber, value: button)
            e.setIntegerValueField(.eventSourceUserData, value: kMousXEventMarker)
            e.post(tap: .cghidEventTap)
        }
    }

    private static func openApp(_ candidates: [String]) {
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                               configuration: NSWorkspace.OpenConfiguration())
            return
        }
    }
}
