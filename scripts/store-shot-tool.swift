// Helper for App Store screenshot capture.
//
//   swift scripts/store-shot-tool.swift window-id <owner-name>
//   swift scripts/store-shot-tool.swift flatten <in.png> <out.png>
//
// `window-id` prints the CGWindowID of the frontmost on-screen window owned by
// <owner-name>. `flatten` composites a PNG with alpha onto an opaque white
// background so App Store Connect receives a flat, sector-correct image.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func windowID(ownerName: String) -> CGWindowID? {
    guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: AnyObject]] else { return nil }

    for entry in info {
        guard let owner = entry[kCGWindowOwnerName as String] as? String, owner == ownerName else { continue }
        guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        guard let number = entry[kCGWindowNumber as String] as? Int else { continue }
        return CGWindowID(number)
    }
    return nil
}

func flatten(source: String, destination: String) -> Bool {
    let sourceURL = URL(fileURLWithPath: source) as CFURL
    let destinationURL = URL(fileURLWithPath: destination) as CFURL

    guard let imageSource = CGImageSourceCreateWithURL(sourceURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        FileHandle.standardError.write(Data("cannot read \(source)\n".utf8))
        return false
    }

    let width = image.width
    let height = image.height
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("cannot create bitmap context\n".utf8))
        return false
    }

    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(bounds)
    context.draw(image, in: bounds)

    guard let flattened = context.makeImage(),
          let destinationImage = CGImageDestinationCreateWithURL(
              destinationURL, UTType.png.identifier as CFString, 1, nil
          ) else {
        FileHandle.standardError.write(Data("cannot encode PNG\n".utf8))
        return false
    }

    CGImageDestinationAddImage(destinationImage, flattened, nil)
    guard CGImageDestinationFinalize(destinationImage) else {
        FileHandle.standardError.write(Data("cannot write \(destination)\n".utf8))
        return false
    }
    return true
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: store-shot-tool.swift window-id <owner> | flatten <in> <out>\n".utf8))
    exit(2)
}

switch arguments[1] {
case "window-id":
    guard arguments.count >= 3, let id = windowID(ownerName: arguments[2]) else { exit(1) }
    print(id)
case "flatten":
    guard arguments.count >= 4, flatten(source: arguments[2], destination: arguments[3]) else { exit(1) }
default:
    FileHandle.standardError.write(Data("unknown command \(arguments[1])\n".utf8))
    exit(2)
}
