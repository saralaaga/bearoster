import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Assets/Logo/app-logo-source.png")
let iconset = root.appendingPathComponent("Packaging/AppIcon.iconset")
let icns = root.appendingPathComponent("Packaging/AppIcon.icns")
let tiff = root.appendingPathComponent("Packaging/AppIcon.tiff")
let preview2048 = root.appendingPathComponent("Assets/Logo/birthday-logo-2048.png")
let previewCropped = root.appendingPathComponent("Assets/Logo/birthday-logo-cropped.png")

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: source) else {
    fatalError("Could not read \(source.path)")
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

    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    bitmap.size = rect.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    rect.fill()
    sourceImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(side)x\(side)")
    }
    return data
}

let sizes: [(name: String, side: Int, icnsType: String?)] = [
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
    let data = renderPNG(side: side)
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

guard let tiffData = NSImage(data: renderPNG(side: 1024))?.tiffRepresentation else {
    fatalError("Could not encode TIFF")
}
try tiffData.write(to: tiff)

print(iconset.path)
print(icns.path)
print(tiff.path)
print(preview2048.path)
print(previewCropped.path)
