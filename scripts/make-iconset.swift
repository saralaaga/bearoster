import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Assets/Logo/birthday-logo.svg")
let iconset = root.appendingPathComponent("Packaging/AppIcon.iconset")
let icns = root.appendingPathComponent("Packaging/AppIcon.icns")
let tiff = root.appendingPathComponent("Packaging/AppIcon.tiff")
let preview2048 = root.appendingPathComponent("Assets/Logo/birthday-logo-2048.png")
let previewCropped = root.appendingPathComponent("Assets/Logo/birthday-logo-cropped.png")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard FileManager.default.fileExists(atPath: source.path) else {
    fatalError("Could not find \(source.path)")
}

func renderPNG(side: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not allocate \(side)x\(side)")
    }

    let logicalSide = CGFloat(side)
    bitmap.size = NSSize(width: logicalSide, height: logicalSide)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: logicalSide, height: logicalSide))
    drawLogo(in: context, side: logicalSide)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(side)x\(side)")
    }
    return data
}

func drawLogo(in context: CGContext, side: CGFloat) {
    let scale = side / 1024
    context.saveGState()
    context.translateBy(x: 0, y: side)
    context.scaleBy(x: scale, y: -scale)

    let back = color(0xF5A623)
    let front = color(0xDCDCE1)
    let frontStroke = color(0xC7C7CF)
    let glyph = color(0x1B2A4A)

    context.saveGState()
    rotate(context, degrees: -11, around: CGPoint(x: 470, y: 530))
    context.setFillColor(back)
    context.addPath(CGPath(roundedRect: CGRect(x: 210, y: 230, width: 520, height: 640), cornerWidth: 95, cornerHeight: 95, transform: nil))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    rotate(context, degrees: 6, around: CGPoint(x: 560, y: 540))

    context.addPath(CGPath(roundedRect: CGRect(x: 300, y: 240, width: 520, height: 640), cornerWidth: 95, cornerHeight: 95, transform: nil))
    context.setFillColor(front)
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: 300, y: 240, width: 520, height: 640), cornerWidth: 95, cornerHeight: 95, transform: nil))
    context.setStrokeColor(frontStroke)
    context.setLineWidth(6)
    context.strokePath()

    context.setFillColor(glyph)
    context.fillEllipse(in: CGRect(x: 472, y: 357, width: 176, height: 176))

    let shoulders = CGMutablePath()
    shoulders.move(to: CGPoint(x: 460, y: 640))
    shoulders.addCurve(to: CGPoint(x: 560, y: 520), control1: CGPoint(x: 460, y: 560), control2: CGPoint(x: 505, y: 520))
    shoulders.addCurve(to: CGPoint(x: 660, y: 640), control1: CGPoint(x: 615, y: 520), control2: CGPoint(x: 660, y: 560))
    shoulders.addCurve(to: CGPoint(x: 638, y: 662), control1: CGPoint(x: 660, y: 655), control2: CGPoint(x: 650, y: 662))
    shoulders.addLine(to: CGPoint(x: 482, y: 662))
    shoulders.addCurve(to: CGPoint(x: 460, y: 640), control1: CGPoint(x: 470, y: 662), control2: CGPoint(x: 460, y: 655))
    shoulders.closeSubpath()
    context.addPath(shoulders)
    context.fillPath()

    context.addPath(CGPath(roundedRect: CGRect(x: 452, y: 706, width: 240, height: 36), cornerWidth: 18, cornerHeight: 18, transform: nil))
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: 452, y: 768, width: 168, height: 36), cornerWidth: 18, cornerHeight: 18, transform: nil))
    context.fillPath()

    context.restoreGState()
    context.restoreGState()
}

func rotate(_ context: CGContext, degrees: CGFloat, around point: CGPoint) {
    context.translateBy(x: point.x, y: point.y)
    context.rotate(by: degrees * .pi / 180)
    context.translateBy(x: -point.x, y: -point.y)
}

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let sizes: [(name: String, side: CGFloat, icnsType: String?)] = [
    ("icon_16x16.png", 16, "icp4"),
    ("icon_16x16@2x.png", 32, nil),
    ("icon_32x32.png", 32, "icp5"),
    ("icon_32x32@2x.png", 64, "icp6"),
    ("icon_128x128.png", 128, "ic07"),
    ("icon_128x128@2x.png", 256, nil),
    ("icon_256x256.png", 256, "ic08"),
    ("icon_256x256@2x.png", 512, nil),
    ("icon_512x512.png", 512, "ic09"),
    ("icon_512x512@2x.png", 1024, "ic10")
]

var icnsElements: [(type: String, data: Data)] = []

for (name, side, icnsType) in sizes {
    let pixels = Int(side)
    let data = renderPNG(side: pixels)
    try data.write(to: iconset.appendingPathComponent(name))
    if let icnsType {
        icnsElements.append((icnsType, data))
    }
}

func fourCC(_ value: String) -> Data {
    guard value.utf8.count == 4 else {
        fatalError("Invalid ICNS type \(value)")
    }
    return Data(value.utf8)
}

func uint32BE(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

var icnsData = Data()
let totalLength = 8 + icnsElements.reduce(0) { $0 + 8 + $1.data.count }
icnsData.append(fourCC("icns"))
icnsData.append(uint32BE(totalLength))
for element in icnsElements {
    icnsData.append(fourCC(element.type))
    icnsData.append(uint32BE(8 + element.data.count))
    icnsData.append(element.data)
}
try icnsData.write(to: icns)

try renderPNG(side: 2048).write(to: preview2048)
try renderPNG(side: 1536).write(to: previewCropped)

let tiffImage = NSImage(data: renderPNG(side: 1024))
guard let tiffData = tiffImage?.tiffRepresentation else {
    fatalError("Could not encode TIFF")
}
try tiffData.write(to: tiff)

print(iconset.path)
print(icns.path)
print(tiff.path)
print(preview2048.path)
print(previewCropped.path)
