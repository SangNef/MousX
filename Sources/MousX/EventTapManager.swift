import Foundation
import CoreGraphics
import ApplicationServices

/// Cài đặt CGEventTap ở mức phiên để chặn & biến đổi sự kiện chuột.
final class EventTapManager {
    static let shared = EventTapManager()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let prefs = Preferences.shared

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let types: [CGEventType] = [.scrollWheel, .otherMouseDown, .otherMouseUp, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }

        let callback: CGEventTapCallBack = { _, type, event, _ in
            EventTapManager.shared.handle(type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: callback,
                                           userInfo: nil) else {
            NSLog("MousX: không tạo được event tap (thiếu quyền Trợ năng?)")
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        runLoopSource = src
        return true
    }

    func stop() {
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        tap = nil
        runLoopSource = nil
        SmoothScroller.shared.stop()
        ButtonHandler.shared.cancel()
    }

    // MARK: - Callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        // Hệ thống tự tắt tap nếu callback quá chậm — bật lại ngay.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
            ButtonHandler.shared.cancel()
            return pass
        }

        // Sự kiện do chính MousX phát ra.
        if event.getIntegerValueField(.eventSourceUserData) == kMousXEventMarker { return pass }

        guard prefs.enabled else { return pass }

        switch type {
        case .scrollWheel:
            return handleScroll(event) ? nil : pass
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            return ButtonHandler.shared.handle(type: type, event: event) ? nil : pass
        default:
            return pass
        }
    }

    /// Trả về `true` nếu sự kiện bị nuốt (được thay bằng cuộn mượt).
    private func handleScroll(_ event: CGEvent) -> Bool {
        // Trackpad / Magic Mouse đã cuộn liên tục sẵn — để nguyên.
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return false }

        let flags = event.flags
        // Giữ ⌘ hoặc ⌃: để nguyên cho phóng to / thu nhỏ trong ứng dụng.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) { return false }

        // Số dòng (đã gồm gia tốc của macOS). FixedPt có phần thập phân; dự phòng sang trường nguyên.
        func lines(_ fixed: CGEventField, _ int: CGEventField) -> Double {
            let v = event.getDoubleValueField(fixed)
            return v != 0 ? v : Double(event.getIntegerValueField(int))
        }
        let dy = lines(.scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventDeltaAxis1)
        let dx = lines(.scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventDeltaAxis2)

        if prefs.smoothScroll {
            SmoothScroller.shared.addTick(dy: dy, dx: dx, flags: flags)
            return true
        }

        // Không cuộn mượt: chỉ áp dụng đảo chiều.
        if prefs.reverseVertical { invert(event, axis: 1) }
        if prefs.reverseHorizontal { invert(event, axis: 2) }
        return false
    }

    private func invert(_ e: CGEvent, axis: Int) {
        let (delta, fixed, point): (CGEventField, CGEventField, CGEventField) = axis == 1
            ? (.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1)
            : (.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)
        e.setIntegerValueField(delta, value: -e.getIntegerValueField(delta))
        e.setDoubleValueField(fixed, value: -e.getDoubleValueField(fixed))
        e.setIntegerValueField(point, value: -e.getIntegerValueField(point))
    }
}
