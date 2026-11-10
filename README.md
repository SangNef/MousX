# MousX

MousX là app chạy trên thanh menu, giúp chuột rời trên macOS dùng giống Magic Mouse / trackpad.

## Tính năng

**Cuộn mượt như trackpad**
- Mỗi nấc bánh xe được chuyển thành chuyển động pixel liên tục.
- Khung hình đồng bộ với tần số quét màn hình (CVDisplayLink, 60/120 Hz), lướt dần kiểu ease-out giống MOS.
- Tuỳ chọn gửi pha cử chỉ kiểu trackpad để có hiệu ứng nảy ở mép trang (thử nghiệm).
- Lăn nhanh thì cuộn xa hơn; chỉnh được tốc độ và độ lướt.
- Đảo chiều cuộn riêng cho chuột, không ảnh hưởng trackpad.
- Giữ `⇧` để cuộn ngang, `⌥` để cuộn chính xác. Giữ `⌘` hoặc `⌃` thì để nguyên hành vi gốc (phóng to/thu nhỏ).
- Không đụng tới thiết bị vốn đã cuộn liên tục (trackpad, Magic Mouse).

**Cử chỉ: giữ nút + kéo chuột** (mặc định là nút giữa)

| Thao tác                 | Kết quả                           |
|--------------------------|-----------------------------------|
| Kéo trái / phải          | Chuyển Space / app toàn màn hình  |
| Kéo lên                  | Mission Control                   |
| Kéo xuống                | App Exposé                        |
| Bấm rồi thả, không kéo   | Click bình thường (hoặc hành động đã gán) |

**Gán hành động cho nút:** nút giữa, nút 4, nút 5 có thể gán Back/Forward, Mission Control, App Exposé, hiện màn hình nền, Launchpad, chuyển Space…

## Build & cài đặt

Cần Xcode (hoặc Command Line Tools) có Swift 5.9 trở lên, macOS 13 trở lên.

```bash
./build.sh            # tạo build/MousX.app (universal: Apple Silicon + Intel)
./build.sh install    # build, cài vào /Applications rồi mở app
```

Lần chạy đầu tiên, macOS sẽ xin **quyền Trợ năng**. Bật MousX trong
*Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng*. App tự kích hoạt ngay khi được cấp quyền.

> **Lưu ý:** app được ký ad-hoc, nên mỗi lần build lại macOS coi đó là app mới.
> Nếu sau khi cập nhật MousX không hoạt động, xoá MousX khỏi danh sách Trợ năng rồi cấp lại, hoặc chạy:
> `tccutil reset Accessibility com.vscorp.MousX`

## Cấu trúc mã nguồn

```
Sources/MousX/
  main.swift            Điểm khởi động (app chỉ có trên thanh menu)
  AppDelegate.swift     Biểu tượng thanh menu, cửa sổ cài đặt, theo dõi quyền
  EventTapManager.swift CGEventTap chặn cuộn và nút phụ
  SmoothScroller.swift  Bộ máy cuộn mượt + quán tính + pha kiểu trackpad
  ButtonHandler.swift   Nhận diện cử chỉ giữ + kéo, gán hành động cho nút
  SystemActions.swift   Mission Control, Exposé, Spaces, phím tắt
  Preferences.swift     Cấu hình (UserDefaults)
  Permissions.swift     Quyền Trợ năng
  SettingsView.swift    Giao diện cài đặt SwiftUI
scripts/make_icon.swift Tạo icon app
build.sh                Đóng gói .app, ký, cài đặt
```

## Ghi chú kỹ thuật

- Chuyển Space dùng phím tắt mặc định `⌃←` / `⌃→`. Nếu đã tắt các phím tắt này trong
  *Cài đặt → Bàn phím → Phím tắt → Mission Control*, hãy bật lại.
- Mission Control / App Exposé / màn hình nền gọi qua API Dock (`CoreDockSendNotification`).
  Nếu API này không còn, app tự chuyển sang dùng phím tắt.
- Toàn bộ xử lý diễn ra trên máy, không có kết nối mạng.
