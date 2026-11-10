import Foundation
import CoreGraphics

/// Xử lý nút phụ (giữa / 4 / 5): giữ nút + kéo chuột => cử chỉ kiểu trackpad,
/// click không kéo => hành động gán cho nút.
///
/// Cử chỉ (hướng "tự nhiên", giống vuốt 3/4 ngón trên trackpad):
///   kéo trái  → Space bên phải      kéo phải → Space bên trái
///   kéo lên   → Mission Control     kéo xuống → App Exposé
final class ButtonHandler {
    static let shared = ButtonHandler()
    private let prefs = Preferences.shared

    private var tracking = false
    private var trackedButton: Int64 = -1
    private var accX = 0.0, accY = 0.0
    private var triggered = false
    private var verticalDone = false
    private var cursorFrozen = false
    /// Các nút mà sự kiện "down" đã bị nuốt — phải nuốt luôn "up"/"dragged" tương ứng.
    private var swallowed = Set<Int64>()

    private var threshold: Double {
        110 - 80 * min(max(prefs.gestureSensitivity, 0), 1)
    }

    /// Trả về `true` nếu sự kiện đã được xử lý (cần nuốt).
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let gestureButton = Int64(prefs.gestureButton.rawValue)

        switch type {
        case .otherMouseDown:
            if button == gestureButton {
                beginTracking(button)
                return true
            }
            let action = prefs.clickAction(forButton: button)
            guard action != .passthrough else { return false }
            swallowed.insert(button)
            SystemActions.perform(action)
            return true

        case .otherMouseDragged:
            if tracking && button == trackedButton {
                accX += Double(event.getIntegerValueField(.mouseEventDeltaX))
                accY += Double(event.getIntegerValueField(.mouseEventDeltaY))
                evaluateGesture()
                return true
            }
            return swallowed.contains(button)

        case .otherMouseUp:
            if tracking && button == trackedButton {
                endTracking()
                if !triggered {
                    let action = prefs.clickAction(forButton: button)
                    if action == .passthrough {
                        SystemActions.postClick(button: button)
                    } else {
                        SystemActions.perform(action)
                    }
                }
                return true
            }
            return swallowed.remove(button) != nil

        default:
            return false
        }
    }

    /// Huỷ cử chỉ đang dở (ví dụ khi tắt MousX hoặc event tap bị vô hiệu).
    func cancel() {
        if tracking { endTracking() }
        swallowed.removeAll()
    }

    // MARK: - Private

    private func beginTracking(_ button: Int64) {
        tracking = true
        trackedButton = button
        accX = 0; accY = 0
        triggered = false
        verticalDone = false
        // Giữ con trỏ đứng yên trong lúc vẽ cử chỉ; delta vẫn được báo về.
        CGAssociateMouseAndMouseCursorPosition(0)
        cursorFrozen = true
    }

    private func endTracking() {
        tracking = false
        trackedButton = -1
        if cursorFrozen {
            CGAssociateMouseAndMouseCursorPosition(1)
            cursorFrozen = false
        }
    }

    private func evaluateGesture() {
        let t = threshold
        let natural = prefs.gestureNatural

        if abs(accX) > abs(accY) * 1.3, abs(accX) >= t {
            let draggedLeft = accX < 0
            let goRight = natural ? draggedLeft : !draggedLeft
            SystemActions.perform(goRight ? .spaceRight : .spaceLeft)
            triggered = true
            accX = 0; accY = 0
        } else if abs(accY) > abs(accX) * 1.3, abs(accY) >= t {
            if !verticalDone {
                let draggedUp = accY < 0
                SystemActions.perform(draggedUp ? .missionControl : .appExpose)
                verticalDone = true
                triggered = true
            }
            accX = 0; accY = 0
        }
    }
}
