import SwiftUI
import ServiceManagement

// MARK: - Điều hướng

enum SettingsPane: String, CaseIterable, Identifiable {
    case scroll, gestures, buttons, general
    var id: String { rawValue }

    var title: String {
        switch self {
        case .scroll:   return "Cuộn"
        case .gestures: return "Cử chỉ"
        case .buttons:  return "Nút chuột"
        case .general:  return "Chung"
        }
    }

    var subtitle: String {
        switch self {
        case .scroll:   return "Cuộn mượt, quán tính và hướng cuộn cho chuột rời."
        case .gestures: return "Giữ một nút và kéo chuột để điều khiển như vuốt trackpad."
        case .buttons:  return "Gán hành động cho nút giữa và các nút bên."
        case .general:  return "Quyền hệ thống, khởi động và thông tin ứng dụng."
        }
    }

    var symbol: String {
        switch self {
        case .scroll:   return "scroll.fill"
        case .gestures: return "hand.draw.fill"
        case .buttons:  return "computermouse.fill"
        case .general:  return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .scroll:   return .blue
        case .gestures: return .purple
        case .buttons:  return .orange
        case .general:  return .gray
        }
    }
}

// MARK: - Gốc

struct SettingsView: View {
    @AppStorage("settingsPane") private var pane: SettingsPane = .scroll
    @ObservedObject private var perm = Permissions.shared
    private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $pane)
                .frame(width: 230)
            Divider()
            DetailPane(pane: pane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 780, height: 580)
        .ignoresSafeArea()
        .onReceive(refresh) { _ in perm.refresh() }
    }
}

// MARK: - Thanh bên

private struct Sidebar: View {
    @Binding var selection: SettingsPane
    @ObservedObject private var p = Preferences.shared
    @ObservedObject private var perm = Permissions.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thẻ ứng dụng
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MousX").font(.system(size: 15, weight: .semibold))
                        StatusPill(enabled: p.enabled, trusted: perm.trusted)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text("Bật MousX").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $p.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
            .padding(.horizontal, 12)
            .padding(.top, 52) // chừa chỗ cho nút đóng/thu nhỏ của cửa sổ

            // Mục điều hướng
            VStack(spacing: 2) {
                ForEach(SettingsPane.allCases) { item in
                    SidebarRow(pane: item, selected: selection == item)
                        .onTapGesture { selection = item }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 16)

            Spacer()

            Text("Phiên bản \(appVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity)
        .background(VisualEffect(material: .sidebar))
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane
    let selected: Bool

    var body: some View {
        HStack(spacing: 9) {
            IconTile(symbol: pane.symbol, color: pane.color, size: 22)
            Text(pane.title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct StatusPill: View {
    let enabled: Bool
    let trusted: Bool

    private var info: (String, Color) {
        if !trusted { return ("Cần cấp quyền", .orange) }
        if !enabled { return ("Đang tắt", .secondary) }
        return ("Đang hoạt động", .green)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(info.1).frame(width: 6, height: 6)
            Text(info.0).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(info.1)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(info.1.opacity(0.14)))
    }
}

// MARK: - Khung nội dung

private struct DetailPane: View {
    let pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: pane.symbol, color: pane.color, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.title).font(.system(size: 20, weight: .bold))
                    Text(pane.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 2)

            Group {
                switch pane {
                case .scroll:   ScrollPane()
                case .gestures: GesturePane()
                case .buttons:  ButtonsPane()
                case .general:  GeneralPane()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .id(pane)
    }
}

// MARK: - Trang Cuộn

private enum ScrollPreset: String, CaseIterable, Identifiable {
    case snappy, balanced, glide, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .snappy: return "Gọn"
        case .balanced: return "Cân bằng"
        case .glide: return "Lướt dài"
        case .custom: return "Tuỳ chỉnh"
        }
    }
    var values: (speed: Double, smooth: Double)? {
        switch self {
        case .snappy: return (1.0, 0.2)
        case .balanced: return (1.0, 0.5)
        case .glide: return (1.15, 0.85)
        case .custom: return nil
        }
    }
}

private struct ScrollPane: View {
    @ObservedObject private var p = Preferences.shared

    private var preset: Binding<ScrollPreset> {
        Binding(
            get: {
                ScrollPreset.allCases.first {
                    guard let v = $0.values else { return false }
                    return abs(v.speed - p.scrollSpeed) < 0.01 && abs(v.smooth - p.smoothness) < 0.01
                } ?? .custom
            },
            set: { new in
                guard let v = new.values else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    p.scrollSpeed = v.speed
                    p.smoothness = v.smooth
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                SettingRow(symbol: "wand.and.stars", color: .blue,
                           title: "Cuộn mượt như trackpad",
                           subtitle: "Mỗi nấc bánh xe thành chuyển động liên tục, đồng bộ tần số quét màn hình.") {
                    Toggle("", isOn: $p.smoothScroll).labelsHidden().toggleStyle(.switch)
                }
            }

            Section {
                SettingRow(symbol: "slider.horizontal.3", color: .indigo, title: "Phong cách") {
                    Picker("", selection: preset) {
                        ForEach(ScrollPreset.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SliderRow(symbol: "hare.fill", color: .teal, title: "Tốc độ",
                          value: $p.scrollSpeed, range: 0.3...3.0,
                          display: String(format: "%.1f×", p.scrollSpeed),
                          minLabel: "Chậm", maxLabel: "Nhanh")
                SliderRow(symbol: "wind", color: .cyan, title: "Độ lướt",
                          value: $p.smoothness, range: 0...1,
                          display: "\(Int(p.smoothness * 100))%",
                          minLabel: "Gọn", maxLabel: "Lướt dài")
                SettingRow(symbol: "speedometer", color: .green,
                           title: "Tăng tốc khi lăn nhanh",
                           subtitle: "Dùng gia tốc cuộn của macOS — lăn nhanh để đi xa hơn.") {
                    Toggle("", isOn: $p.acceleration).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(symbol: "arrow.up.and.down.square.fill", color: .pink,
                           title: "Hiệu ứng nảy ở mép trang",
                           subtitle: "Thử nghiệm · đẹp trong Safari/Finder, có thể kém mượt ở vài ứng dụng.") {
                    Toggle("", isOn: $p.trackpadPhases).labelsHidden().toggleStyle(.switch)
                }
            } header: {
                Text("Cảm giác")
            }
            .disabled(!p.smoothScroll)

            Section {
                ScrollTestArea()
            } header: {
                Text("Thử ngay")
            } footer: {
                FooterText("Lăn chuột trong khung trên để cảm nhận thay đổi tức thì.")
            }

            Section {
                SettingRow(symbol: "arrow.up.arrow.down", color: .orange,
                           title: "Đảo chiều cuộn dọc") {
                    Toggle("", isOn: $p.reverseVertical).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(symbol: "arrow.left.arrow.right", color: .orange,
                           title: "Đảo chiều cuộn ngang") {
                    Toggle("", isOn: $p.reverseHorizontal).labelsHidden().toggleStyle(.switch)
                }
            } header: {
                Text("Hướng cuộn")
            } footer: {
                FooterText("Chỉ áp dụng cho chuột rời — trackpad và Magic Mouse giữ nguyên.")
            }

            Section {
                ModifierRow(key: "⇧", title: "Cuộn ngang", isOn: $p.shiftHorizontal)
                ModifierRow(key: "⌥", title: "Cuộn chính xác, từng chút một", isOn: $p.optionPrecise)
                HStack(spacing: 10) {
                    HStack(spacing: 3) { KeyCap("⌘"); KeyCap("⌃") }
                    Text("Giữ nguyên hành vi gốc (phóng to / thu nhỏ)")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } header: {
                Text("Phím bổ trợ khi cuộn")
            }
        }
    }
}

private struct ScrollTestArea: View {
    private let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(0..<40, id: \.self) { i in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(colors[i % colors.count].gradient)
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(Color.primary.opacity(0.18))
                                .frame(width: CGFloat(120 + (i * 37) % 160), height: 7)
                            Capsule().fill(Color.primary.opacity(0.09))
                                .frame(width: CGFloat(70 + (i * 53) % 120), height: 6)
                        }
                        Spacer()
                        Text("#\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
        )
    }
}

private struct ModifierRow: View {
    let key: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            KeyCap(key)
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

// MARK: - Trang Cử chỉ

private struct GesturePane: View {
    @ObservedObject private var p = Preferences.shared

    var body: some View {
        Form {
            Section {
                SettingRow(symbol: "hand.tap.fill", color: .purple,
                           title: "Nút cử chỉ",
                           subtitle: "Giữ nút này rồi kéo chuột theo một hướng.") {
                    Picker("", selection: $p.gestureButton) {
                        ForEach(GestureButton.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            Section {
                GestureDiagram(natural: p.gestureNatural)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .opacity(p.gestureButton == .none ? 0.4 : 1)
            } header: {
                Text("Bản đồ cử chỉ")
            } footer: {
                FooterText("Bấm rồi thả mà không kéo sẽ thực hiện hành động click ở trang Nút chuột.")
            }

            Section {
                SettingRow(symbol: "arrow.triangle.swap", color: .blue,
                           title: "Hướng tự nhiên",
                           subtitle: "Kéo sang trái để tới Space bên phải — giống vuốt trên trackpad.") {
                    Toggle("", isOn: $p.gestureNatural).labelsHidden().toggleStyle(.switch)
                }
                SliderRow(symbol: "dial.medium.fill", color: .pink, title: "Độ nhạy",
                          value: $p.gestureSensitivity, range: 0...1,
                          display: "\(Int(p.gestureSensitivity * 100))%",
                          minLabel: "Kéo xa", maxLabel: "Kéo ngắn")
            } header: {
                Text("Tinh chỉnh")
            }
            .disabled(p.gestureButton == .none)
        }
    }
}

private struct GestureDiagram: View {
    let natural: Bool

    var body: some View {
        VStack(spacing: 10) {
            GestureChip(arrow: "arrow.up", title: "Mission Control", color: .blue)
            HStack(spacing: 10) {
                GestureChip(arrow: "arrow.left",
                            title: natural ? "Space bên phải" : "Space bên trái", color: .purple)
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 74, height: 74)
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 74, height: 74)
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentColor)
                }
                GestureChip(arrow: "arrow.right",
                            title: natural ? "Space bên trái" : "Space bên phải", color: .purple)
            }
            GestureChip(arrow: "arrow.down", title: "App Exposé", color: .teal)
        }
    }
}

private struct GestureChip: View {
    let arrow: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: arrow)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(color.gradient))
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

// MARK: - Trang Nút chuột

private struct ButtonsPane: View {
    @ObservedObject private var p = Preferences.shared

    var body: some View {
        Form {
            Section {
                ButtonActionRow(number: "3", title: "Nút giữa (bánh xe)",
                                isGesture: p.gestureButton == .middle,
                                selection: $p.middleAction)
                ButtonActionRow(number: "4", title: "Nút bên 4",
                                isGesture: p.gestureButton == .button4,
                                selection: $p.button4Action)
                ButtonActionRow(number: "5", title: "Nút bên 5",
                                isGesture: p.gestureButton == .button5,
                                selection: $p.button5Action)
            } header: {
                Text("Hành động khi click")
            } footer: {
                FooterText("\"Mặc định\" giữ nguyên chức năng gốc của nút. Nút đang làm nút cử chỉ chỉ thực hiện hành động khi bấm-thả không kéo.")
            }

            Section {
                TipRow(symbol: "safari.fill", color: .blue,
                       text: "Nút 4/5 → Quay lại / Tiến tới hoạt động trong Safari, Finder và hầu hết ứng dụng.")
                TipRow(symbol: "rectangle.3.group.fill", color: .purple,
                       text: "Gán Mission Control cho một nút bên để mở nhanh bằng một cú bấm.")
            } header: {
                Text("Gợi ý")
            }
        }
    }
}

private struct ButtonActionRow: View {
    let number: String
    let title: String
    let isGesture: Bool
    @Binding var selection: ButtonAction

    var body: some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.orange.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if isGesture {
                    Label("Đang dùng làm nút cử chỉ", systemImage: "hand.draw.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            Spacer(minLength: 12)
            Picker("", selection: $selection) {
                ForEach(ButtonAction.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

private struct TipRow: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 22)
            Text(text).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Trang Chung

private struct GeneralPane: View {
    @ObservedObject private var p = Preferences.shared
    @ObservedObject private var perm = Permissions.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                PermissionCard(trusted: perm.trusted)
            } header: {
                Text("Quyền hệ thống")
            }

            Section {
                SettingRow(symbol: "power", color: .green, title: "Bật MousX",
                           subtitle: "Tắt để dùng chuột như mặc định của macOS.") {
                    Toggle("", isOn: $p.enabled).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(symbol: "sunrise.fill", color: .orange, title: "Khởi động cùng macOS",
                           subtitle: loginError) {
                    Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { on in
                            do {
                                if on { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                loginError = nil
                            } catch {
                                loginError = error.localizedDescription
                            }
                        }
                }
            } header: {
                Text("Hoạt động")
            }

            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MousX").font(.system(size: 15, weight: .semibold))
                        Text("Phiên bản \(appVersion)").font(.caption).foregroundStyle(.secondary)
                        Text("Mọi xử lý diễn ra trên máy, không gửi dữ liệu ra ngoài.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Khôi phục mặc định…") { confirmReset = true }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Giới thiệu")
            }
        }
        .alert("Khôi phục cài đặt mặc định?", isPresented: $confirmReset) {
            Button("Khôi phục", role: .destructive) { p.resetToDefaults() }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Mọi tuỳ chỉnh về cuộn, cử chỉ và nút chuột sẽ trở về giá trị ban đầu.")
        }
    }
}

private struct PermissionCard: View {
    let trusted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 26))
                .foregroundStyle(trusted ? Color.green : Color.orange)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(trusted ? "Đã cấp quyền Trợ năng" : "Chưa cấp quyền Trợ năng")
                    .font(.system(size: 13, weight: .semibold))
                Text(trusted
                     ? "MousX đang có thể đọc và chuyển đổi sự kiện chuột."
                     : "Vào Quyền riêng tư & Bảo mật → Trợ năng và bật MousX. App tự kích hoạt khi được cấp.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if !trusted {
                Button("Mở cài đặt") {
                    Permissions.requestAccess()
                    Permissions.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Thành phần dùng chung

private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
}

private struct FooterText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.25), radius: 1, y: 0.5)
    }
}

private struct SettingRow<Trailing: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
    }
}

private struct SliderRow: View {
    let symbol: String
    let color: Color
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let display: String
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                IconTile(symbol: symbol, color: color)
                Text(title)
                Spacer()
                Text(display)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            HStack(spacing: 8) {
                Text(minLabel).font(.caption2).foregroundStyle(.secondary)
                Slider(value: $value, in: range)
                    .labelsHidden()
                    .controlSize(.small)
                Text(maxLabel).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.leading, 32)
        }
    }
}

private struct KeyCap: View {
    let key: String
    init(_ key: String) { self.key = key }

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .semibold))
            .frame(minWidth: 22, minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12))
            )
    }
}

private struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
    }
}
