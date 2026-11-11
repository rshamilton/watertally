#!/usr/bin/env swift
//
//  Generates every raster brand asset for Water Tally from code:
//    - App icon (light / dark / tinted, 1024x1024, opaque)
//    - Launch logo (transparent, @1x/@2x/@3x)
//    - Web icon, favicon and social-share image
//
//  The mark is a five-bar tally: four upright strokes crossed by a wave instead of a slash.
//  Its geometry matches `BrandMark` in WaterTally/Branding.swift.
//
//  Usage (from the repo root):  swift tools/generate_brand_assets.swift
//
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = FileManager.default.currentDirectoryPath
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

// Brand palette (keep in sync with Branding.swift and web/assets/style.css).
let ink: UInt32 = 0x0E3A66      // icon background
let night: UInt32 = 0x0B1724    // app background
let paper: UInt32 = 0xF5F1E8    // strokes, light text
let water: UInt32 = 0x5DB7F5    // the wave, accent

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha
    ])!
}

func makeContext(_ width: Int, _ height: Int, opaque: Bool) -> CGContext {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                     space: colorSpace, bitmapInfo: info)!
}

func writePNG(_ context: CGContext, to relativePath: String) {
    let url = URL(fileURLWithPath: root).appendingPathComponent(relativePath)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, context.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(relativePath)")
}

// MARK: - The mark

/// Draws the mark inside `rect`, using the 1024-unit design grid (y down).
func drawMark(_ ctx: CGContext, in rect: CGRect, strokes: CGColor, wave: CGColor) {
    let s = rect.width / 1024
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.maxY - y * s) }

    ctx.setLineCap(.round)
    ctx.setLineWidth(62 * s)

    ctx.setStrokeColor(strokes)
    for index in 0..<4 {
        let x = 300 + CGFloat(index) * 141
        ctx.move(to: p(x, 270))
        ctx.addLine(to: p(x, 754))
    }
    ctx.strokePath()

    ctx.setStrokeColor(wave)
    ctx.move(to: p(200, 640))
    ctx.addCurve(to: p(824, 384), control1: p(420, 760), control2: p(600, 260))
    ctx.strokePath()
}

// MARK: - App icon

enum IconVariant { case light, dark, tinted }

func drawIcon(_ variant: IconVariant) -> CGContext {
    let ctx = makeContext(1024, 1024, opaque: true)
    let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    switch variant {
    case .light:
        ctx.setFillColor(rgb(ink)); ctx.fill(full)
        drawMark(ctx, in: full, strokes: rgb(paper), wave: rgb(water))
    case .dark:
        ctx.setFillColor(rgb(night)); ctx.fill(full)
        drawMark(ctx, in: full, strokes: rgb(paper, 0.92), wave: rgb(water))
    case .tinted:
        // Grayscale on black: the system applies the user's tint.
        ctx.setFillColor(rgb(0x000000)); ctx.fill(full)
        drawMark(ctx, in: full, strokes: rgb(0xFFFFFF), wave: rgb(0xFFFFFF, 0.55))
    }
    return ctx
}

func rounded(_ source: CGContext, to size: Int, cornerRadius: CGFloat) -> CGContext {
    let ctx = makeContext(size, size, opaque: false)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = cornerRadius * CGFloat(size)
    if radius > 0 {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
    }
    ctx.interpolationQuality = .high
    ctx.draw(source.makeImage()!, in: rect)
    return ctx
}

let iconCorner: CGFloat = 0.2237

// MARK: - Text helper

func drawText(_ ctx: CGContext, _ text: String, at point: CGPoint, size: CGFloat, weight: String, color: CGColor) {
    let font = CTFontCreateWithName(weight as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

// MARK: - Run

let appIcons = "WaterTally/Assets.xcassets/AppIcon.appiconset"
let icon = drawIcon(.light)
writePNG(icon, to: "\(appIcons)/AppIcon.png")
writePNG(drawIcon(.dark), to: "\(appIcons)/AppIcon-Dark.png")
writePNG(drawIcon(.tinted), to: "\(appIcons)/AppIcon-Tinted.png")

// Launch logo: the icon tile, 96 pt.
let launch = "WaterTally/Assets.xcassets/LaunchLogo.imageset"
for (scale, suffix) in [(1, ""), (2, "@2x"), (3, "@3x")] {
    writePNG(rounded(icon, to: 96 * scale, cornerRadius: iconCorner), to: "\(launch)/LaunchLogo\(suffix).png")
}

// Web
writePNG(icon, to: "web/assets/icon-1024.png")
writePNG(rounded(icon, to: 512, cornerRadius: iconCorner), to: "web/assets/icon-512.png")
writePNG(rounded(icon, to: 180, cornerRadius: 0), to: "web/assets/apple-touch-icon.png")
writePNG(rounded(icon, to: 64, cornerRadius: iconCorner), to: "web/assets/favicon.png")

// Social share card 1200x630
let card = makeContext(1200, 630, opaque: true)
card.setFillColor(rgb(night))
card.fill(CGRect(x: 0, y: 0, width: 1200, height: 630))
card.draw(rounded(icon, to: 280, cornerRadius: iconCorner).makeImage()!, in: CGRect(x: 110, y: 175, width: 280, height: 280))
drawText(card, "Water Tally", at: CGPoint(x: 450, y: 330), size: 96, weight: "HelveticaNeue-Bold", color: rgb(paper))
drawText(card, "Simple, private water tracking", at: CGPoint(x: 454, y: 262), size: 42, weight: "HelveticaNeue", color: rgb(water))
writePNG(card, to: "web/assets/social-card.png")
