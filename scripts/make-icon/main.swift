// Собирает иконку приложения из общего рисунка BatteryGlyph.
// Запуск: make-icon <out.icns>
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)

    // Фон: скруглённый квадрат с градиентом.
    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s)
                                    .insetBy(dx: s * 0.06, dy: s * 0.06),
                                  xRadius: s * 0.22, yRadius: s * 0.22)
    NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.36, alpha: 1),
               ending: NSColor(calibratedRed: 0.07, green: 0.36, blue: 0.24, alpha: 1))?
        .draw(in: background, angle: -90)

    // Рисунок готовим отдельно: внутри него выжигается прозрачный зазор вокруг знака,
    // чтобы сквозь него был виден фон.
    let glyphHeight = s * 0.46
    let glyph = BatteryGlyph.image(height: glyphHeight, fillFraction: 0.62, color: .white, scale: 1)
    glyph.draw(in: NSRect(x: (s - glyph.size.width) / 2, y: (s - glyph.size.height) / 2,
                          width: glyph.size.width, height: glyph.size.height))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("BatteryStop-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in sizes {
    guard let data = drawIcon(size: size).representation(using: .png, properties: [:]) else { continue }
    try! data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    if size >= 32, let retina = drawIcon(size: size).representation(using: .png, properties: [:]) {
        try! retina.write(to: iconset.appendingPathComponent("icon_\(size / 2)x\(size / 2)@2x.png"))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputPath]
try! process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(process.terminationStatus)
