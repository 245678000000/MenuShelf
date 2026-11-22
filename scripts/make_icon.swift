import AppKit

let S = 1024.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 底板：深色圆角方块
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
NSGradient(colors: [NSColor(red: 0.16, green: 0.16, blue: 0.22, alpha: 1),
                    NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)])!.draw(in: squircle, angle: -90)

// 底部的橙紫光晕
NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(colors: [NSColor(red: 1.0, green: 0.48, blue: 0.2, alpha: 0.85), NSColor(red: 1.0, green: 0.48, blue: 0.2, alpha: 0)])!
    .draw(fromCenter: NSPoint(x: 700, y: 120), radius: 0, toCenter: NSPoint(x: 700, y: 120), radius: 520, options: [])
NSGradient(colors: [NSColor(red: 0.42, green: 0.36, blue: 1.0, alpha: 0.75), NSColor(red: 0.42, green: 0.36, blue: 1.0, alpha: 0)])!
    .draw(fromCenter: NSPoint(x: 300, y: 160), radius: 0, toCenter: NSPoint(x: 300, y: 160), radius: 480, options: [])
NSGraphicsContext.restoreGraphicsState()

// 玻璃胶囊
let bar = NSRect(x: 196, y: 446, width: 632, height: 132)
let cap = NSBezierPath(roundedRect: bar, xRadius: 66, yRadius: 66)
NSColor(white: 1, alpha: 0.14).setFill(); cap.fill()
NSColor(white: 1, alpha: 0.32).setStroke(); cap.lineWidth = 4; cap.stroke()

// 被收纳的圆点（淡）
for x in [290.0, 380.0] {
    NSColor(white: 1, alpha: 0.35).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - 22, y: 512 - 22, width: 44, height: 44)).fill()
}
// 分隔线
NSColor(white: 1, alpha: 0.6).setFill()
NSBezierPath(roundedRect: NSRect(x: 462, y: 470, width: 10, height: 84), xRadius: 5, yRadius: 5).fill()
// 箭头 ‹
let chev = NSBezierPath()
chev.move(to: NSPoint(x: 588, y: 548)); chev.line(to: NSPoint(x: 548, y: 512)); chev.line(to: NSPoint(x: 588, y: 476))
chev.lineWidth = 18; chev.lineCapStyle = .round; chev.lineJoinStyle = .round
NSColor.white.setStroke(); chev.stroke()
// 常显圆点
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: 690 - 26, y: 512 - 26, width: 52, height: 52)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
