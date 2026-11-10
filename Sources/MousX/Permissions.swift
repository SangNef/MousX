import AppKit
import ApplicationServices
import Combine

/// Quyền Trợ năng (Accessibility) là bắt buộc để chặn & phát sự kiện chuột.
final class Permissions: ObservableObject {
    static let shared = Permissions()

    @Published private(set) var trusted = AXIsProcessTrusted()

    static var isTrusted: Bool { AXIsProcessTrusted() }

    func refresh() { trusted = AXIsProcessTrusted() }

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
