import Foundation
import Combine

/// Hành động có thể gán cho nút chuột.
enum ButtonAction: String, CaseIterable, Identifiable {
    case passthrough
    case back
    case forward
    case missionControl
    case appExpose
    case showDesktop
    case launchpad
    case spaceLeft
    case spaceRight
    case middleClick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .passthrough:    return "Mặc định (giữ nguyên)"
        case .back:           return "Quay lại (⌘[)"
        case .forward:        return "Tiến tới (⌘])"
        case .missionControl: return "Mission Control"
        case .appExpose:      return "App Exposé"
        case .showDesktop:    return "Hiện màn hình nền"
        case .launchpad:      return "Launchpad"
        case .spaceLeft:      return "Chuyển sang Space bên trái"
        case .spaceRight:     return "Chuyển sang Space bên phải"
        case .middleClick:    return "Click chuột giữa"
        }
    }
}

/// Nút dùng để giữ + kéo tạo cử chỉ.
enum GestureButton: Int, CaseIterable, Identifiable {
    case none = -1
    case middle = 2
    case button4 = 3
    case button5 = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none:    return "Tắt"
        case .middle:  return "Nút giữa (bánh xe)"
        case .button4: return "Nút bên 4 (Back)"
        case .button5: return "Nút bên 5 (Forward)"
        }
    }
}

/// Toàn bộ cấu hình của MousX, lưu trong UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let d = UserDefaults.standard

    // Chung
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }

    // Cuộn
    @Published var smoothScroll: Bool { didSet { d.set(smoothScroll, forKey: "smoothScroll") } }
    @Published var scrollSpeed: Double { didSet { d.set(scrollSpeed, forKey: "scrollSpeed") } }
    @Published var smoothness: Double { didSet { d.set(smoothness, forKey: "smoothness") } }
    @Published var acceleration: Bool { didSet { d.set(acceleration, forKey: "acceleration") } }
    @Published var reverseVertical: Bool { didSet { d.set(reverseVertical, forKey: "reverseVertical") } }
    @Published var reverseHorizontal: Bool { didSet { d.set(reverseHorizontal, forKey: "reverseHorizontal") } }
    @Published var shiftHorizontal: Bool { didSet { d.set(shiftHorizontal, forKey: "shiftHorizontal") } }
    @Published var optionPrecise: Bool { didSet { d.set(optionPrecise, forKey: "optionPrecise") } }

    // Nút & cử chỉ
    @Published var gestureButton: GestureButton { didSet { d.set(gestureButton.rawValue, forKey: "gestureButton") } }
    @Published var gestureNatural: Bool { didSet { d.set(gestureNatural, forKey: "gestureNatural") } }
    @Published var gestureSensitivity: Double { didSet { d.set(gestureSensitivity, forKey: "gestureSensitivity") } }
    @Published var middleAction: ButtonAction { didSet { d.set(middleAction.rawValue, forKey: "middleAction") } }
    @Published var button4Action: ButtonAction { didSet { d.set(button4Action.rawValue, forKey: "button4Action") } }
    @Published var button5Action: ButtonAction { didSet { d.set(button5Action.rawValue, forKey: "button5Action") } }

    private init() {
        let d = UserDefaults.standard
        func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) as? Bool ?? def }
        func dbl(_ k: String, _ def: Double) -> Double { d.object(forKey: k) as? Double ?? def }
        func act(_ k: String, _ def: ButtonAction) -> ButtonAction {
            ButtonAction(rawValue: d.string(forKey: k) ?? "") ?? def
        }

        enabled = bool("enabled", true)
        smoothScroll = bool("smoothScroll", true)
        scrollSpeed = dbl("scrollSpeed", 1.0)
        smoothness = dbl("smoothness", 0.5)
        acceleration = bool("acceleration", true)
        reverseVertical = bool("reverseVertical", false)
        reverseHorizontal = bool("reverseHorizontal", false)
        shiftHorizontal = bool("shiftHorizontal", true)
        optionPrecise = bool("optionPrecise", true)

        gestureButton = GestureButton(rawValue: d.object(forKey: "gestureButton") as? Int ?? 2) ?? .middle
        gestureNatural = bool("gestureNatural", true)
        gestureSensitivity = dbl("gestureSensitivity", 0.5)
        middleAction = act("middleAction", .passthrough)
        button4Action = act("button4Action", .back)
        button5Action = act("button5Action", .forward)
    }

    /// Hành động click (không kéo) cho số nút CGEvent (2 = giữa, 3 = nút 4, 4 = nút 5).
    func clickAction(forButton n: Int64) -> ButtonAction {
        switch n {
        case 2: return middleAction
        case 3: return button4Action
        case 4: return button5Action
        default: return .passthrough
        }
    }

    func resetToDefaults() {
        enabled = true
        smoothScroll = true; scrollSpeed = 1.0; smoothness = 0.5
        acceleration = true; reverseVertical = false; reverseHorizontal = false
        shiftHorizontal = true; optionPrecise = true
        gestureButton = .middle; gestureNatural = true; gestureSensitivity = 0.5
        middleAction = .passthrough; button4Action = .back; button5Action = .forward
    }
}
