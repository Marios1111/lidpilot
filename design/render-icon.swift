#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Compile the approved light/dark artwork into native macOS asset sizes.
// Masters are retained so asset generation is deterministic and reviewable.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("App/Assets.xcassets", isDirectory: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func master(_ appearance: String) throws -> CGImage {
    let url = root.appendingPathComponent("design/icon/\(appearance)-master.png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == image.height, image.width >= 1024 else {
        throw NSError(domain: "LidPilotIcon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Missing square icon master: \(appearance)"])
    }
    return image
}
func write(_ image: CGImage, pixels: Int, to url: URL) throws {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "LidPilotIcon", code: 2) }
}
func contents(_ entries: [[String: Any]], folder: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: ["images": entries,
        "info": ["author": "LidPilot", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    try data.write(to: folder.appendingPathComponent("Contents.json"))
}
let light = try master("light"), dark = try master("dark")
let iconSet = assets.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
var icons: [[String: Any]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)@\(scale)x.png"
        try write(light, pixels: size * scale, to: iconSet.appendingPathComponent(name))
        icons.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
try contents(icons, folder: iconSet)
// A named image with public appearance variants serves SwiftUI and AppKit on
// macOS 15+. Finder uses the default AppIcon; no unsupported Finder override.
let markSet = assets.appendingPathComponent("PilotIcon.imageset", isDirectory: true)
try FileManager.default.createDirectory(at: markSet, withIntermediateDirectories: true)
var marks: [[String: Any]] = []
for (appearance, image) in [("light", light), ("dark", dark)] {
    let name = "\(appearance).png"
    try write(image, pixels: 1024, to: markSet.appendingPathComponent(name))
    var entry: [String: Any] = ["idiom": "universal", "filename": name]
    if appearance == "dark" { entry["appearances"] = [["appearance": "luminosity", "value": "dark"]] }
    marks.append(entry)
}
try contents(marks, folder: markSet)
print("Generated macOS app icon and adaptive light/dark PilotIcon")
