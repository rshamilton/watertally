//
//  Branding.swift
//  Water Tally
//
//  The Water Tally mark: four tally strokes crossed by a wave instead of a slash.
//  Same geometry as tools/generate_brand_assets.swift (1024-unit grid).
//

import SwiftUI

/// The four upright tally strokes.
struct TallyStrokes: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 1024
        var path = Path()
        for index in 0..<4 {
            let x = rect.minX + (300 + CGFloat(index) * 141) * s
            path.move(to: CGPoint(x: x, y: rect.minY + 270 * s))
            path.addLine(to: CGPoint(x: x, y: rect.minY + 754 * s))
        }
        return path
    }
}

/// The wave that crosses the strokes.
struct TallyWave: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 1024
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(200, 640))
        path.addCurve(to: p(824, 384), control1: p(420, 760), control2: p(600, 260))
        return path
    }
}

/// The app icon drawn in SwiftUI: a rounded ink tile with the mark.
struct BrandMark: View {
    var size: CGFloat = 96

    var body: some View {
        let line = StrokeStyle(lineWidth: size * 62 / 1024, lineCap: .round)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                .fill(Color.brandInk)
            TallyStrokes().stroke(Color.paper, style: line)
            TallyWave().stroke(Color.water, style: line)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    BrandMark(size: 160)
        .padding()
        .background(Color.night)
}
