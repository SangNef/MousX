// Vẽ icon MousX (gradient + biểu tượng chuột) và xuất PNG kích thước tuỳ chọn.
// Dùng: swift scripts/make_icon.swift <output.png> <size>
import AppKit

let args = CommandLine.arguments
let out = args[1]
let size = CGFloat(Double(args[2]) ?? 1024)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let inset = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
NSGradient(colors: [NSColor(red: 0.36, green: 0.30, blue: 0.98, alpha: 1),
                    NSColor(red: 0.10, green: 0.70, blue: 0.95, alpha: 1)])!
    .draw(in: path, angle: -60)

let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
if let sym = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: sym.size)
    tinted.lockFocus()
    sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: sym.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    let r = NSRect(x: (size - sym.size.width) / 2, y: (size - sym.size.height) / 2,
                   width: sym.size.width, height: sym.size.height)
    tinted.draw(in: r)
}
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
