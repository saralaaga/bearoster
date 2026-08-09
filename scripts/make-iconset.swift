import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Assets/Logo/concepts/concept-2-calendar.png")
let iconset = root.appendingPathComponent("Packaging/AppIcon.iconset")
let icns = root.appendingPathComponent("Packaging/AppIcon.icns")
let tiff = root.appendingPathComponent("Packaging/AppIcon.tiff")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let image = NSImage(contentsOf: source) else {
    fatalError("Could not open \(source.path)")
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
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not allocate \(name)")
    }

    bitmap.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(name)")
    }
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

guard let tiffData = image.tiffRepresentation else {
    fatalError("Could not encode TIFF")
}
try tiffData.write(to: tiff)

print(iconset.path)
print(icns.path)
print(tiff.path)
