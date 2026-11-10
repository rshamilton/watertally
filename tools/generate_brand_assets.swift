#!/usr/bin/env swift
//
//  Generates every raster brand asset for Water Tally from code:
//    - App icon (light / dark / tinted, 1024x1024, opaque)
//    - Launch logo (transparent, @1x/@2x/@3x)
//    - Web icon, favicon and social-share image
//
//  Usage (from the repo root):  swift tools/generate_brand_assets.swift
//
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = FileManager.default.currentDirectoryPath
let colorSpace = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha
    ])!
}

func gradient(_ stops: [(UInt32, CGFloat)], alpha: CGFloat = 1) -> CGGradient {
    CGGradient(colorsSpace: colorSpace,
               colors: stops.map { rgb($0.0, alpha) } as CFArray,
               locations: stops.map { $0.1 })!
}

func makeContext(_ width: Int, _ height: Int, opaque: Bool) -> CGContext {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                     space: colorSpace, bitmapInfo: info)!
}

func writePNG(_ context: CGContext, to relativePath: String) {
    let url = URL(fileURLWithPath: root).appendingPathComponent(relativePath)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let image = context.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(relativePath)")
}

// MARK: - The drop

/// Unit-square teardrop identical to `DropShape` in the app.
func dropPath(in rect: CGRect) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        // CoreGraphics is y-up; the app's shape is y-down, so flip.
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + (1 - y) * rect.height)
    }
    let path = CGMutablePath()
    path.move(to: p(0.5, 0.0))
    path.addCurve(to: p(0.88, 0.62), control1: p(0.62, 0.22), control2: p(0.88, 0.40))
    path.addCurve(to: p(0.5, 1.0), control1: p(0.88, 0.83), control2: p(0.71, 1.0))
    path.addCurve(to: p(0.12, 0.62), control1: p(0.29, 1.0), control2: p(0.12, 0.83))
    path.addCurve(to: p(0.5, 0.0), control1: p(0.12, 0.40), control2: p(0.38, 0.22))
    path.closeSubpath()
    return path
}

enum Style { case color, tinted }

func drawDrop(_ ctx: CGContext, in rect: CGRect, style: Style) {
    ctx.saveGState()
    ctx.addPath(dropPath(in: rect))
    ctx.clip()

    let fill: CGGradient = style == .color
        ? gradient([(0xA6F3FF, 0), (0x28B8EE, 0.45), (0x0A5FB0, 1)])
        : gradient([(0xFFFFFF, 0), (0xDDDDDD, 0.5), (0x9A9A9A, 1)])
    ctx.drawLinearGradient(fill, start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY), options: [])

    // Soft highlight on the left shoulder.
    ctx.setFillColor(rgb(0xFFFFFF, style == .tinted ? 0.35 : 0.30))
    ctx.fillEllipse(in: CGRect(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.52,
                               width: rect.width * 0.12, height: rect.height * 0.22))
    ctx.restoreGState()

    // Tally marks: four strokes and the slash.
    let markWidth = rect.width * 0.36
    let markHeight = rect.height * 0.22
    let centerY = rect.minY + rect.height * 0.34
    let left = rect.midX - markWidth / 2
    let marks = CGMutablePath()
    for index in 0..<4 {
        let x = left + markWidth * (0.08 + 0.28 * CGFloat(index))
        marks.move(to: CGPoint(x: x, y: centerY - markHeight / 2))
        marks.addLine(to: CGPoint(x: x, y: centerY + markHeight / 2))
    }
    marks.move(to: CGPoint(x: left - markWidth * 0.06, y: centerY - markHeight / 2 + markHeight * 0.12))
    marks.addLine(to: CGPoint(x: left + markWidth * 1.06, y: centerY + markHeight / 2 - markHeight * 0.12))
    ctx.addPath(marks)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.92))
    ctx.setLineWidth(rect.width * 0.05)
    ctx.setLineCap(.round)
    ctx.strokePath()
}

// MARK: - App icon

enum IconVariant { case light, dark, tinted }

func drawIcon(_ variant: IconVariant) -> CGContext {
    let size = 1024
    let ctx = makeContext(size, size, opaque: true)

    let bg: CGGradient
    switch variant {
    case .light:  bg = gradient([(0x0E63A8, 0), (0x073B70, 0.5), (0x03172C, 1)])
    case .dark:   bg = gradient([(0x06253F, 0), (0x03121F, 0.55), (0x010A12, 1)])
    case .tinted: bg = gradient([(0x2A2A2A, 0), (0x101010, 0.6), (0x000000, 1)])
    }
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])

    if variant != .tinted {
        let radial = CGGradient(colorsSpace: colorSpace,
                                colors: [rgb(0x39D0FF, variant == .light ? 0.55 : 0.4), rgb(0x39D0FF, 0)] as CFArray,
                                locations: [0, 1])!
        ctx.drawRadialGradient(radial, startCenter: CGPoint(x: 512, y: 520), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 520), endRadius: 520, options: [])
    }

    // Ripples under the drop.
    for (index, scale) in [1.0, 1.55].enumerated() {
        let alpha: CGFloat = index == 0 ? 0.35 : 0.16
        ctx.setStrokeColor(variant == .tinted ? rgb(0xFFFFFF, alpha * 0.8) : rgb(0x7FE9FF, alpha))
        ctx.setLineWidth(14)
        let w = 300 * scale, h = 66 * scale
        ctx.strokeEllipse(in: CGRect(x: 512 - w / 2, y: 196 - h / 2, width: w, height: h))
    }

    let dropRect = CGRect(x: 512 - 230, y: 250, width: 460, height: 560)
    if variant != .tinted {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 60, color: rgb(0x39D0FF, 0.7))
        ctx.addPath(dropPath(in: dropRect))
        ctx.setFillColor(rgb(0x1AA8E0))
        ctx.fillPath()
        ctx.restoreGState()
    }
    drawDrop(ctx, in: dropRect, style: variant == .tinted ? .tinted : .color)
    return ctx
}

// MARK: - Launch logo (transparent)

func drawLogo(width: Int, height: Int) -> CGContext {
    let ctx = makeContext(width, height, opaque: false)
    let rect = CGRect(x: CGFloat(width) * 0.05, y: CGFloat(height) * 0.05,
                      width: CGFloat(width) * 0.9, height: CGFloat(height) * 0.9)
    drawDrop(ctx, in: rect, style: .color)
    return ctx
}

// MARK: - Text helper

func drawText(_ ctx: CGContext, _ text: String, at point: CGPoint, size: CGFloat, color: CGColor) {
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

func scaled(_ source: CGContext, to size: Int, cornerRadius: CGFloat) -> CGContext {
    let ctx = makeContext(size, size, opaque: false)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = cornerRadius * CGFloat(size)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(source.makeImage()!, in: rect)
    return ctx
}

// MARK: - Run

let appIcons = "WaterTally/Assets.xcassets/AppIcon.appiconset"
writePNG(drawIcon(.light), to: "\(appIcons)/AppIcon.png")
writePNG(drawIcon(.dark), to: "\(appIcons)/AppIcon-Dark.png")
writePNG(drawIcon(.tinted), to: "\(appIcons)/AppIcon-Tinted.png")

let launch = "WaterTally/Assets.xcassets/LaunchLogo.imageset"
writePNG(drawLogo(width: 96, height: 118), to: "\(launch)/LaunchLogo.png")
writePNG(drawLogo(width: 192, height: 236), to: "\(launch)/LaunchLogo@2x.png")
writePNG(drawLogo(width: 288, height: 354), to: "\(launch)/LaunchLogo@3x.png")

// Web
let icon = drawIcon(.light)
writePNG(icon, to: "web/assets/icon-1024.png")
writePNG(scaled(icon, to: 512, cornerRadius: 0.2237), to: "web/assets/icon-512.png")
writePNG(scaled(icon, to: 180, cornerRadius: 0), to: "web/assets/apple-touch-icon.png")
writePNG(scaled(icon, to: 64, cornerRadius: 0.2237), to: "web/assets/favicon.png")

// Social share card 1200x630
let card = makeContext(1200, 630, opaque: true)
card.drawLinearGradient(gradient([(0x0E63A8, 0), (0x073B70, 0.5), (0x02101E, 1)]),
                        start: CGPoint(x: 0, y: 630), end: CGPoint(x: 1200, y: 0), options: [])
card.draw(scaled(icon, to: 300, cornerRadius: 0.2237).makeImage()!, in: CGRect(x: 110, y: 165, width: 300, height: 300))
drawText(card, "Water Tally", at: CGPoint(x: 470, y: 330), size: 100, color: rgb(0xFFFFFF))
drawText(card, "Simple water tracking for iPhone", at: CGPoint(x: 474, y: 262), size: 44, color: rgb(0xBDEBFF))
writePNG(card, to: "web/assets/social-card.png")
