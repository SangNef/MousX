import Foundation
import CoreGraphics
import CoreVideo
import QuartzCore
import os

/// Biến các "nấc" cuộn rời rạc của chuột thành luồng cuộn pixel liên tục.
///
/// - Khung hình được đồng bộ với tần số quét màn hình qua CVDisplayLink (60/120 Hz),
///   nên mỗi lần màn hình vẽ lại nhận đúng một phần chuyển động — không giật.
/// - Mỗi khung hình tiến một tỉ lệ cố định phần quãng đường còn lại (ease-out mũ),
///   độc lập với tần số quét.
/// - Luôn gửi pha cử chỉ kiểu trackpad: began ở khung đầu, changed suốt hoạt ảnh
///   (kể cả khi đang lướt), ended khi dừng hẳn — chỉ một cử chỉ cho mỗi lượt cuộn.
///   Bắt buộc: sự kiện liên tục mà KHÔNG có pha bị các app chỉnh cuộn khác (Mos…)
///   coi là chuột và bắt lại => trang không cuộn. Có pha thì app còn có hiệu ứng nảy ở mép.
final class SmoothScroller {
    static let shared = SmoothScroller()

    private let prefs = Preferences.shared

    // ---- Trạng thái dùng chung giữa luồng chính (event tap) và luồng display link ----
    private var lock = os_unfair_lock()
    private var remainingX = 0.0, remainingY = 0.0
    private var carryX = 0.0, carryY = 0.0
    private var lastFrameTime: CFTimeInterval = 0
    private var animating = false
    private var gestureOpen = false        // đã gửi phase "began" chưa "ended"
    private var flags: CGEventFlags = []
    // Ảnh chụp cấu hình (đọc trên luồng chính, dùng trên luồng display link)
    private var stepPerFrame120 = 0.18

    // ---- Chỉ dùng trên luồng chính ----
    private var displayLink: CVDisplayLink?

    // MARK: - Đầu vào (luồng chính)

    /// Nhận một nấc cuộn từ chuột. `dy`/`dx` là số dòng (đã có gia tốc của macOS).
    func addTick(dy rawY: Double, dx rawX: Double, flags inFlags: CGEventFlags) {
        var dy = rawY, dx = rawX
        if prefs.shiftHorizontal && inFlags.contains(.maskShift) && dx == 0 {
            dx = dy; dy = 0
        }
        if prefs.reverseVertical { dy = -dy }
        if prefs.reverseHorizontal { dx = -dx }
        guard dy != 0 || dx != 0 else { return }

        let precise = prefs.optionPrecise && inFlags.contains(.maskAlternate)
        func distance(_ lines: Double) -> Double {
            guard lines != 0 else { return 0 }
            let sign: Double = lines > 0 ? 1 : -1
            if precise { return sign * 4 * prefs.scrollSpeed }
            // Gia tốc: dùng chính số dòng macOS đã tăng tốc (lăn nhanh => nhiều dòng).
            let n = prefs.acceleration ? min(max(abs(lines), 1), 14) : 1
            return sign * n * 34 * prefs.scrollSpeed
        }
        let addY = distance(dy), addX = distance(dx)

        var f = inFlags
        if prefs.shiftHorizontal { f.remove(.maskShift) }
        if precise { f.remove(.maskAlternate) }

        let smooth = min(max(prefs.smoothness, 0), 1)

        os_unfair_lock_lock(&lock)
        // Đổi hướng => huỷ quãng còn lại trên trục đó để phản hồi tức thì.
        if addY != 0 && remainingY != 0 && (addY > 0) != (remainingY > 0) { remainingY = 0; carryY = 0 }
        if addX != 0 && remainingX != 0 && (addX > 0) != (remainingX > 0) { remainingX = 0; carryX = 0 }
        remainingY += addY
        remainingX += addX
        flags = f
        // Độ lướt cao => mỗi khung hình (ở 120 Hz) tiêu thụ ít quãng đường hơn.
        stepPerFrame120 = 0.26 - 0.20 * smooth
        if !animating { lastFrameTime = 0 }
        animating = true
        os_unfair_lock_unlock(&lock)

        startDisplayLink()
    }

    /// Dừng mọi chuyển động (ví dụ khi tắt MousX).
    func stop() {
        os_unfair_lock_lock(&lock)
        let mustEnd = gestureOpen
        reset()
        let f = flags
        os_unfair_lock_unlock(&lock)
        if mustEnd { post(dy: 0, dx: 0, phase: 4, flags: f) }
        if let link = displayLink, CVDisplayLinkIsRunning(link) { CVDisplayLinkStop(link) }
    }

    // MARK: - Display link

    private func startDisplayLink() {
        if displayLink == nil {
            var link: CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            guard let link else { return }
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
                Unmanaged<SmoothScroller>.fromOpaque(ctx!).takeUnretainedValue().frame()
                return kCVReturnSuccess
            }, ctx)
            displayLink = link
        }
        guard let link = displayLink, !CVDisplayLinkIsRunning(link) else { return }
        // Đồng bộ theo màn hình đang chứa con trỏ (quan trọng khi có màn hình 60 Hz + 120 Hz).
        if let display = displayUnderCursor() {
            CVDisplayLinkSetCurrentCGDisplay(link, display)
        }
        CVDisplayLinkStart(link)
    }

    private func displayUnderCursor() -> CGDirectDisplayID? {
        guard let loc = CGEvent(source: nil)?.location else { return nil }
        var id: CGDirectDisplayID = 0
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(loc, 1, &id, &count) == .success, count > 0 else { return nil }
        return id
    }

    /// Gọi trên luồng chính khi hoạt ảnh kết thúc.
    private func stopIfIdle() {
        os_unfair_lock_lock(&lock)
        let idle = !animating
        os_unfair_lock_unlock(&lock)
        if idle, let link = displayLink, CVDisplayLinkIsRunning(link) {
            CVDisplayLinkStop(link)
        }
    }

    private func reset() {
        animating = false
        gestureOpen = false
        remainingX = 0; remainingY = 0; carryX = 0; carryY = 0
        lastFrameTime = 0
    }

    // MARK: - Khung hình (luồng display link)

    private func frame() {
        os_unfair_lock_lock(&lock)
        guard animating else {
            os_unfair_lock_unlock(&lock)
            return
        }

        let now = CACurrentMediaTime()
        let dt = lastFrameTime == 0 ? 1.0 / 120 : min(now - lastFrameTime, 1.0 / 30)
        lastFrameTime = now
        // Chuyển hệ số "mỗi khung 120 Hz" sang khoảng thời gian thực tế của khung này.
        let k = 1 - pow(1 - stepPerFrame120, dt * 120)

        let outY = remainingY * k, outX = remainingX * k
        remainingY -= outY
        remainingX -= outX

        let totalY = outY + carryY, totalX = outX + carryX
        let iy = totalY.rounded(.towardZero), ix = totalX.rounded(.towardZero)
        carryY = totalY - iy
        carryX = totalX - ix

        let done = abs(remainingY) < 0.5 && abs(remainingX) < 0.5
        let f = flags

        var events: [(Int32, Int32, Int64)] = []
        if iy != 0 || ix != 0 {
            events.append((Int32(iy), Int32(ix), gestureOpen ? 2 : 1))
            gestureOpen = true
        }
        if done {
            if gestureOpen { events.append((0, 0, 4)) }
            reset()
        }
        os_unfair_lock_unlock(&lock)

        for e in events { post(dy: e.0, dx: e.1, phase: e.2, flags: f) }
        if done {
            DispatchQueue.main.async { [weak self] in self?.stopIfIdle() }
        }
    }

    // MARK: - Phát sự kiện

    private func post(dy: Int32, dx: Int32, phase: Int64, flags: CGEventFlags) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        e.setIntegerValueField(.eventSourceUserData, value: kMousXEventMarker)
        e.flags = flags
        e.post(tap: .cghidEventTap)
    }
}
