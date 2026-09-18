// Рисует фон для окна DMG. Запуск: make-dmg-background <out.png>
// Холст 600×400 точек рисуется в двойном разрешении; DPI выставляет make-dmg.sh.
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let width: CGFloat = 600
let height: CGFloat = 400
let scale: CGFloat = 2

let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                           pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Фон.
NSGradient(starting: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1),
           ending: NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.95, alpha: 1))?
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

/// Координаты в тексте ниже задаются от левого верхнего угла, как в Finder.
func flip(_ y: CGFloat) -> CGFloat { height - y }

func draw(_ text: String, font: NSFont, color: NSColor, centerY: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(at: NSPoint(x: (width - size.width) / 2, y: flip(centerY) - size.height / 2),
                            withAttributes: attributes)
}

draw("BatteryStop",
     font: .systemFont(ofSize: 24, weight: .semibold),
     color: NSColor(calibratedWhite: 0.17, alpha: 1),
     centerY: 52)
draw("Drag the app into the Applications folder",
     font: .systemFont(ofSize: 13, weight: .regular),
     color: NSColor(calibratedWhite: 0.45, alpha: 1),
     centerY: 80)

// Стрелка между иконками: иконки стоят в (150, 200) и (450, 200).
let arrowColor = NSColor(calibratedRed: 0.67, green: 0.70, blue: 0.74, alpha: 1)
arrowColor.setFill()
arrowColor.setStroke()

let arrowY = flip(200)
let shaft = NSBezierPath()
shaft.lineWidth = 9
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 253, y: arrowY))
shaft.line(to: NSPoint(x: 333, y: arrowY))
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 355, y: arrowY))
head.line(to: NSPoint(x: 325, y: arrowY + 20))
head.line(to: NSPoint(x: 325, y: arrowY - 20))
head.close()
head.fill()

NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: outputPath))
