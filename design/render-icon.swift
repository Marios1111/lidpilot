#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Original vector artwork. Generate every resolution directly from these paths.
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let colorSpace = CGColorSpaceCreateDeviceRGB()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}
var images: [[String: String]] = []
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = pointSize * scale
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                bytesPerRow: 0, space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = CGPath(roundedRect: CGRect(x: 90, y: 90, width: 844, height: 844),
                          cornerWidth: 190, cornerHeight: 190, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0.10, 0.18, 0.28, 0.15))
        context.addPath(tile); context.setFillColor(color(0.98, 0.99, 1)); context.fillPath()
        context.restoreGState()
        context.saveGState(); context.addPath(tile); context.clip()
        let background = CGGradient(colorsSpace: colorSpace,
            colors: [color(0.89, 0.94, 1), color(1, 1, 1)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 925), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.addPath(tile); context.setStrokeColor(color(1, 1, 1, 0.95)); context.setLineWidth(8); context.strokePath()

        // A lifted lid and a grounded base, drawn independently of SF Symbols.
        let lid = CGPath(roundedRect: CGRect(x: 261, y: 366, width: 502, height: 351),
                         cornerWidth: 38, cornerHeight: 38, transform: nil)
        context.saveGState(); context.addPath(lid); context.clip()
        let screen = CGGradient(colorsSpace: colorSpace,
            colors: [color(0.18, 0.40, 0.83), color(0.27, 0.64, 1)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(screen, start: CGPoint(x: 300, y: 380), end: CGPoint(x: 710, y: 710), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        let inset = CGPath(roundedRect: CGRect(x: 284, y: 389, width: 456, height: 305),
                           cornerWidth: 20, cornerHeight: 20, transform: nil)
        context.addPath(inset); context.setFillColor(color(0.96, 0.99, 1, 0.95)); context.fillPath()
        context.setLineCap(.round); context.setLineJoin(.round)
        context.setStrokeColor(color(0.15, 0.40, 0.82)); context.setLineWidth(26)
        context.move(to: CGPoint(x: 225, y: 328)); context.addLine(to: CGPoint(x: 799, y: 328)); context.strokePath()
        context.setLineWidth(22)
        context.move(to: CGPoint(x: 432, y: 306)); context.addLine(to: CGPoint(x: 592, y: 306)); context.strokePath()
        // A rising path suggests continuity without adding a letter or a badge.
        context.setLineWidth(32)
        context.move(to: CGPoint(x: 424, y: 470))
        context.addCurve(to: CGPoint(x: 599, y: 607), control1: CGPoint(x: 506, y: 470), control2: CGPoint(x: 514, y: 607))
        context.strokePath()
        context.move(to: CGPoint(x: 544, y: 613)); context.addLine(to: CGPoint(x: 608, y: 613)); context.addLine(to: CGPoint(x: 608, y: 549)); context.strokePath()

        let name = "icon_\(pointSize)@\(scale)x.png"
        let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,
                                                         UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not write icon") }
        images.append(["idiom": "mac", "size": "\(pointSize)x\(pointSize)", "scale": "\(scale)x", "filename": name])
    }
}
let data = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "LidPilot", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try data.write(to: folder.appendingPathComponent("Contents.json"))
print("Generated original LidPilot icon assets")
