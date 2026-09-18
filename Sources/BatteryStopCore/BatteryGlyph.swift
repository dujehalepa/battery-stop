import AppKit

/// Общий рисунок программы: батарея, поверх неё классический знак запрета
/// (круг с косой чертой). Используется и для иконки приложения, и для строки меню,
/// поэтому геометрия задана в условных единицах и масштабируется под нужный размер.
public enum BatteryGlyph {
    /// Значок поверх батареи: знак запрета, когда заряд ограничен,
    /// и молния, когда ограничения нет.
    public enum Badge: Sendable {
        case prohibition
        case bolt
    }

    /// Рисунок вписан в прямоугольник 0.90 × 0.72 условных единиц.
    private static let unitWidth: CGFloat = 0.90
    private static let unitHeight: CGFloat = 0.72
    public static var aspectRatio: CGFloat { unitWidth / unitHeight }

    /// Рисует знак в текущем графическом контексте.
    /// Вокруг круга выжигается прозрачный зазор, чтобы он не сливался с батареей,
    /// поэтому рисовать нужно в отдельном (прозрачном) буфере.
    public static func draw(in rect: NSRect, fillFraction: Double, color: NSColor,
                            badge: Badge = .prohibition) {
        let k = rect.height / unitHeight
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * k, y: rect.minY + y * k)
        }
        func size(_ value: CGFloat) -> CGFloat { value * k }
        func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
            NSRect(origin: point(x, y), size: NSSize(width: size(width), height: size(height)))
        }

        color.setStroke()
        color.setFill()

        // Корпус батареи.
        let body = box(0.03, 0.300, 0.70, 0.39)
        let bodyPath = NSBezierPath(roundedRect: body, xRadius: size(0.07), yRadius: size(0.07))
        bodyPath.lineWidth = size(0.062)
        bodyPath.stroke()

        // Клемма.
        let cap = box(0.755, 0.413, 0.05, 0.165)
        NSBezierPath(roundedRect: cap, xRadius: size(0.018), yRadius: size(0.018)).fill()

        // Уровень заряда внутри корпуса.
        let inset = size(0.058)
        let fraction = min(max(fillFraction, 0), 1)
        if fraction > 0 {
            let fill = NSRect(x: body.minX + inset, y: body.minY + inset,
                              width: (body.width - inset * 2) * fraction,
                              height: body.height - inset * 2)
            NSBezierPath(roundedRect: fill, xRadius: size(0.03), yRadius: size(0.03)).fill()
        }

        // Значок поверх батареи.
        let center = point(0.62, 0.200)
        let radius = size(0.200)
        let strokeWidth = size(0.080)
        let gap = size(0.068)

        switch badge {
        case .prohibition:
            func circle(_ r: CGFloat) -> NSBezierPath {
                NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r,
                                            width: r * 2, height: r * 2))
            }

            // Прозрачный зазор отделяет знак от батареи.
            NSGraphicsContext.current?.compositingOperation = .clear
            circle(radius + gap).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            let ring = circle(radius - strokeWidth / 2)
            ring.lineWidth = strokeWidth
            ring.stroke()

            // Косая черта из верхнего левого угла в нижний правый.
            let arm = radius - strokeWidth * 0.9
            let angle = 135.0 * .pi / 180
            let slash = NSBezierPath()
            slash.lineWidth = strokeWidth
            slash.lineCapStyle = .butt
            slash.move(to: NSPoint(x: center.x - cos(angle) * arm, y: center.y - sin(angle) * arm))
            slash.line(to: NSPoint(x: center.x + cos(angle) * arm, y: center.y + sin(angle) * arm))
            slash.stroke()

        case .bolt:
            // Молния: зигзаг чуть меньше знака запрета, чтобы зазор не задевал клемму.
            let center = point(0.60, 0.205)
            let r = size(0.200)
            let outline: [(CGFloat, CGFloat)] = [
                (0.34, 1.00), (-0.46, 0.06), (0.02, 0.06),
                (-0.34, -1.00), (0.46, -0.06), (-0.02, -0.06),
            ]
            let bolt = NSBezierPath()
            for (index, coordinate) in outline.enumerated() {
                let target = NSPoint(x: center.x + coordinate.0 * r, y: center.y + coordinate.1 * r)
                if index == 0 { bolt.move(to: target) } else { bolt.line(to: target) }
            }
            bolt.close()

            // Тот же приём: сначала выжигаем контур с запасом, потом заливаем.
            bolt.lineJoinStyle = .round
            bolt.lineWidth = gap * 2
            NSGraphicsContext.current?.compositingOperation = .clear
            bolt.stroke()
            bolt.fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            bolt.fill()
        }
    }

    /// Готовое изображение заданной высоты (в точках) с растром под Retina.
    public static func image(height: CGFloat, fillFraction: Double, color: NSColor,
                             badge: Badge = .prohibition, scale: CGFloat = 2) -> NSImage {
        let width = (height * aspectRatio).rounded()
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(x: 0, y: 0, width: width, height: height),
             fillFraction: fillFraction, color: color, badge: badge)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}
