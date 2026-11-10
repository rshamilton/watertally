//
//  Branding.swift
//  Water Tally
//
//  The Water Tally mark: a drop with tally marks (four strokes and the slash) inside it.
//

import SwiftUI

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.5, 0.0))
        path.addCurve(to: point(0.88, 0.62), control1: point(0.62, 0.22), control2: point(0.88, 0.40))
        path.addCurve(to: point(0.5, 1.0), control1: point(0.88, 0.83), control2: point(0.71, 1.0))
        path.addCurve(to: point(0.12, 0.62), control1: point(0.29, 1.0), control2: point(0.12, 0.83))
        path.addCurve(to: point(0.5, 0.0), control1: point(0.12, 0.40), control2: point(0.38, 0.22))
        path.closeSubpath()
        return path
    }
}

/// Four vertical strokes crossed by a slash: the classic "five" tally.
struct TallyMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<4 {
            let x = rect.minX + rect.width * (0.08 + 0.28 * CGFloat(index))
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        path.move(to: CGPoint(x: rect.minX - rect.width * 0.06, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.06, y: rect.minY + rect.height * 0.12))
        return path
    }
}

struct TallyMark: View {
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            DropShape()
                .fill(LinearGradient(colors: [Color(hex: "#7FE9FF"), Color(hex: "#1AA8E0"), Color(hex: "#0B5FA8")],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.cyan.opacity(0.55), radius: size * 0.18)

            TallyMarks()
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .frame(width: size * 0.36, height: size * 0.22)
                .offset(y: size * 0.16)
        }
        .frame(width: size * 0.82, height: size)
        .accessibilityHidden(true)
    }
}
