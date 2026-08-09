import AppKit
import Foundation

// Renders Apple-style app-icon concept drafts for Birthday.
// Output: Assets/Logo/concepts/concept-N-<name>.png (2048x2048)

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("Assets/Logo/concepts")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let canvas: CGFloat = 2048

// MARK: - Helpers

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// Continuous-corner (superellipse) squircle, n ≈ 5 matches Apple's icon curvature.
func squirclePath(in rect: NSRect, exponent: Double = 5.0) -> NSBezierPath {
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let path = NSBezierPath()
    let steps = 720
    for i in 0...steps {
        let t = 2 * Double.pi * Double(i) / Double(steps)
        let c = cos(t), s = sin(t)
        let x = cx + a * (c >= 0 ? 1 : -1) * pow(abs(c), 2.0 / exponent)
        let y = cy + b * (s >= 0 ? 1 : -1) * pow(abs(s), 2.0 / exponent)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, in g: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: g.minX + x * g.width, y: g.minY + y * g.height,
                                     width: w * g.width, height: h * g.height),
                 xRadius: r * g.width, yRadius: r * g.width)
}

func pt(_ x: CGFloat, _ y: CGFloat, in g: NSRect) -> NSPoint {
    NSPoint(x: g.minX + x * g.width, y: g.minY + y * g.height)
}

func teardrop(cx: CGFloat, bottom: CGFloat, height: CGFloat, width: CGFloat, in g: NSRect) -> NSBezierPath {
    // Flame: pointed top, round bottom.
    let w = width * g.width, h = height * g.height
    let x = g.minX + cx * g.width, y0 = g.minY + bottom * g.height
    let tip = NSPoint(x: x, y: y0 + h)
    let baseY = y0 + h * 0.30 // center of the round part
    let r = w / 2
    let p = NSBezierPath()
    p.move(to: tip)
    p.curve(to: NSPoint(x: x - r, y: baseY),
            controlPoint1: NSPoint(x: x - w * 0.10, y: y0 + h * 0.78),
            controlPoint2: NSPoint(x: x - r, y: baseY + r * 0.9))
    p.appendArc(withCenter: NSPoint(x: x, y: baseY), radius: r, startAngle: 180, endAngle: 360, clockwise: false)
    p.curve(to: tip,
            controlPoint1: NSPoint(x: x + r, y: baseY + r * 0.9),
            controlPoint2: NSPoint(x: x + w * 0.10, y: y0 + h * 0.78))
    p.close()
    return p
}

func heart(in rect: NSRect) -> NSBezierPath {
    // Classic parametric heart: x = 16sin³t, y = 13cos t − 5cos 2t − 2cos 3t − cos 4t
    // (y-up; notch at top, tip at bottom). Ranges: x ∈ [-16,16], y ∈ [-17, ~12]
    let p = NSBezierPath()
    let steps = 240
    for i in 0...steps {
        let t = 2 * Double.pi * Double(i) / Double(steps)
        let hx = 16 * pow(sin(t), 3)
        let hy = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
        let px = rect.minX + CGFloat((hx + 16) / 32) * rect.width
        let py = rect.minY + CGFloat((hy + 17) / 29.2) * rect.height
        if i == 0 { p.move(to: NSPoint(x: px, y: py)) } else { p.line(to: NSPoint(x: px, y: py)) }
    }
    p.close()
    return p
}

/// Rotated ellipse via parametric points (avoids AffineTransform order pitfalls).
func rotatedEllipse(center: NSPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat) -> NSBezierPath {
    let theta = degrees * .pi / 180
    let c = cos(theta), s = sin(theta)
    let path = NSBezierPath()
    let steps = 90
    for i in 0...steps {
        let t = 2 * CGFloat.pi * CGFloat(i) / CGFloat(steps)
        let ex = rx * cos(t), ey = ry * sin(t)
        let point = NSPoint(x: center.x + ex * c - ey * s, y: center.y + ex * s + ey * c)
        if i == 0 { path.move(to: point) } else { path.line(to: point) }
    }
    path.close()
    return path
}

// MARK: - Glyphs (drawn white inside normalized unit box `g`)

func drawCake(in g: NSRect) {
    roundedRect(0.06, 0.10, 0.88, 0.08, 0.04, in: g).fill()      // plate
    roundedRect(0.16, 0.18, 0.68, 0.40, 0.08, in: g).fill()      // cake body
    roundedRect(0.455, 0.58, 0.09, 0.22, 0.045, in: g).fill()    // candle
    teardrop(cx: 0.5, bottom: 0.83, height: 0.17, width: 0.16, in: g).fill() // flame
}

func drawCalendar(in g: NSRect, knockout: (NSBezierPath) -> Void) {
    roundedRect(0.30, 0.84, 0.06, 0.16, 0.03, in: g).fill()      // ring left
    roundedRect(0.64, 0.84, 0.06, 0.16, 0.03, in: g).fill()      // ring right
    roundedRect(0.08, 0.10, 0.84, 0.80, 0.14, in: g).fill()      // body
    knockout(roundedRect(0.20, 0.20, 0.60, 0.38, 0.06, in: g))   // page window
    heartInWindow(in: g)
}

// MARK: - Calendar variants (built on the same body)

func calendarBody(in g: NSRect, knockout: (NSBezierPath) -> Void) {
    roundedRect(0.30, 0.84, 0.06, 0.16, 0.03, in: g).fill()      // ring left
    roundedRect(0.64, 0.84, 0.06, 0.16, 0.03, in: g).fill()      // ring right
    roundedRect(0.08, 0.10, 0.84, 0.80, 0.14, in: g).fill()      // body
    knockout(roundedRect(0.20, 0.20, 0.60, 0.38, 0.06, in: g))   // page window
}

func heartInWindow(in g: NSRect) {
    heart(in: NSRect(x: g.minX + 0.38 * g.width, y: g.minY + 0.255 * g.height,
                     width: 0.24 * g.width, height: 0.24 * g.height)).fill()
}

func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat, in g: NSRect) -> NSBezierPath {
    let x = g.minX + cx * g.width, y = g.minY + cy * g.height
    let R = radius * g.width, r = R * 0.22
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 + .pi / 2
        let rad = i % 2 == 0 ? R : r
        let p = NSPoint(x: x + rad * cos(angle), y: y + rad * sin(angle))
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    return path
}

/// 2a: stacked pages + sparkles
func drawCalendarLayered(in g: NSRect, knockout ko: (NSBezierPath) -> Void) {
    NSColor.white.withAlphaComponent(0.30).setFill()
    roundedRect(0.14, 0.16, 0.84, 0.80, 0.14, in: g).fill()      // back page, offset top-right
    NSColor.white.setFill()
    calendarBody(in: g, knockout: ko)
    heartInWindow(in: g)
    sparkle(0.13, 0.945, 0.055, in: g).fill()
    sparkle(0.87, 0.945, 0.04, in: g).fill()
}

/// 2b: candle in the page window
func drawCalendarCandle(in g: NSRect, knockout ko: (NSBezierPath) -> Void) {
    calendarBody(in: g, knockout: ko)
    roundedRect(0.465, 0.23, 0.07, 0.19, 0.035, in: g).fill()    // candle
    teardrop(cx: 0.5, bottom: 0.44, height: 0.115, width: 0.12, in: g).fill() // flame
}

/// 2c: balloon floating at the calendar's top-right corner
func drawCalendarBalloon(in g: NSRect, knockout ko: (NSBezierPath) -> Void) {
    NSBezierPath(ovalIn: NSRect(x: g.minX + 0.875 * g.width, y: g.minY + 0.825 * g.height,
                                width: 0.17 * g.width, height: 0.23 * g.height)).fill()
    let knot = NSBezierPath()
    knot.move(to: pt(0.96, 0.83, in: g))
    knot.line(to: pt(0.935, 0.785, in: g))
    knot.line(to: pt(0.985, 0.785, in: g))
    knot.close()
    knot.fill()
    let string = NSBezierPath()
    string.move(to: pt(0.96, 0.78, in: g))
    string.curve(to: pt(0.945, 0.66, in: g),
                 controlPoint1: pt(1.01, 0.74, in: g),
                 controlPoint2: pt(0.91, 0.70, in: g))
    string.lineWidth = 0.028 * g.width
    string.lineCapStyle = .round
    string.stroke()
    calendarBody(in: g, knockout: ko)
    heartInWindow(in: g)
}

func drawBalloon(in g: NSRect) {
    NSBezierPath(ovalIn: NSRect(x: g.minX + 0.24 * g.width, y: g.minY + 0.28 * g.height,
                                width: 0.52 * g.width, height: 0.70 * g.height)).fill()
    let knot = NSBezierPath()
    knot.move(to: pt(0.5, 0.29, in: g))
    knot.curve(to: pt(0.455, 0.21, in: g),
               controlPoint1: pt(0.46, 0.27, in: g),
               controlPoint2: pt(0.445, 0.24, in: g))
    knot.curve(to: pt(0.5, 0.29, in: g),
               controlPoint1: pt(0.5, 0.19, in: g),
               controlPoint2: pt(0.54, 0.27, in: g))
    knot.close()
    knot.fill()
    let string = NSBezierPath()
    string.move(to: pt(0.5, 0.20, in: g))
    string.curve(to: pt(0.47, 0.0, in: g),
                 controlPoint1: pt(0.62, 0.12, in: g),
                 controlPoint2: pt(0.38, 0.05, in: g))
    string.lineWidth = 0.035 * g.width
    string.lineCapStyle = .round
    string.stroke()
}

func drawGift(in g: NSRect, knockout: (NSBezierPath) -> Void) {
    roundedRect(0.18, 0.08, 0.64, 0.44, 0.06, in: g).fill()      // box
    roundedRect(0.12, 0.52, 0.76, 0.18, 0.06, in: g).fill()      // lid
    knockout(roundedRect(0.44, 0.08, 0.12, 0.62, 0.02, in: g))   // ribbon
    // bow loops
    for (cx, angle) in [(CGFloat(0.36), CGFloat(-26)), (CGFloat(0.64), CGFloat(26))] {
        rotatedEllipse(center: pt(cx, 0.82, in: g),
                       rx: 0.125 * g.width, ry: 0.085 * g.height,
                       degrees: angle).fill()
    }
    NSBezierPath(ovalIn: NSRect(x: g.minX + 0.455 * g.width, y: g.minY + 0.705 * g.height,
                                width: 0.09 * g.width, height: 0.09 * g.width)).fill() // knot
}

// MARK: - Renderer

struct Concept {
    let name: String
    let background: UInt32    // solid background color
    let glyphScale: CGFloat   // glyph size as fraction of squircle
    let draw: (NSRect, (NSBezierPath) -> Void) -> Void
}

let concepts: [Concept] = [
    Concept(name: "1-cake", background: 0xFF9F0A, glyphScale: 0.56) { g, ko in drawCake(in: g) },
    Concept(name: "2-calendar", background: 0x0A84FF, glyphScale: 0.58) { g, ko in drawCalendar(in: g, knockout: ko) },
    Concept(name: "2a-calendar-layered", background: 0x0A84FF, glyphScale: 0.58) { g, ko in drawCalendarLayered(in: g, knockout: ko) },
    Concept(name: "2b-calendar-candle", background: 0x0A84FF, glyphScale: 0.58) { g, ko in drawCalendarCandle(in: g, knockout: ko) },
    Concept(name: "2c-calendar-balloon", background: 0x0A84FF, glyphScale: 0.58) { g, ko in drawCalendarBalloon(in: g, knockout: ko) },
    Concept(name: "3-balloon", background: 0xBF5AF2, glyphScale: 0.52) { g, ko in drawBalloon(in: g) },
    Concept(name: "4-gift", background: 0x30B0C7, glyphScale: 0.56) { g, ko in drawGift(in: g, knockout: ko) },
]

for (index, concept) in concepts.enumerated() {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Squircle: 80.5% of canvas, centered (macOS icon grid)
    let side = canvas * 0.805
    let iconRect = NSRect(x: (canvas - side) / 2, y: (canvas - side) / 2, width: side, height: side)
    let squircle = squirclePath(in: iconRect)

    // Solid background (no gradient)
    color(concept.background).setFill()
    squircle.fill()

    // Glyph
    let gs = side * concept.glyphScale
    let g = NSRect(x: iconRect.midX - gs / 2, y: iconRect.midY - gs / 2, width: gs, height: gs)
    NSColor.white.set()
    let knockout: (NSBezierPath) -> Void = { path in
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    concept.draw(g, knockout)

    NSGraphicsContext.restoreGraphicsState()

    let url = outDir.appendingPathComponent("concept-\(concept.name).png")
    try rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}
