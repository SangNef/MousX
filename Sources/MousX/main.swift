import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // chỉ hiện trên thanh menu, không có icon Dock
app.run()
