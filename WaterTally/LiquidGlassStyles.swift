//
//  LiquidGlassStyles.swift
//  Water Tally
//
//  Shared look & feel: a calm night-blue background, flat cards with a hairline edge,
//  one accent colour. The same palette is used by the website (web/assets/style.css).
//

import SwiftUI

// MARK: - Palette

extension Color {
    /// App background.
    static let night = Color(hex: "#0B1724")
    /// Icon tile and deep surfaces.
    static let brandInk = Color(hex: "#0E3A66")
    /// Warm off-white used by the mark.
    static let paper = Color(hex: "#F5F1E8")
    /// The accent: buttons, links, progress.
    static let water = Color(hex: "#5DB7F5")
    /// Goal reached.
    static let goalGreen = Color(hex: "#6FCF97")
    /// Card fill and edge on the dark background.
    static let cardFill = Color.white.opacity(0.06)
    static let cardEdge = Color.white.opacity(0.09)
}

extension ShapeStyle where Self == Color {
    static var water: Color { .water }
    static var paper: Color { .paper }
    static var goalGreen: Color { .goalGreen }
}

// MARK: - Background

/// Night-blue background with a soft wash of the user's theme colour at the top.
struct AppBackground: View {
    let themeColor: String

    var body: some View {
        ZStack {
            Color.night
            LinearGradient(colors: [Color(hex: themeColor).opacity(0.32), .clear],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.cardEdge, lineWidth: 1)
                )
        )
    }
}

// MARK: - Button styles

/// A gentle press response for custom-drawn buttons.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Solid, high-contrast call-to-action used for primary buttons.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .water
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.night)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func card(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }

    /// On iPad, present as a tall page-style sheet instead of a small form sheet (iOS 18+).
    /// No effect on iPhone or earlier iOS versions.
    @ViewBuilder
    func pageSizedSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }

    /// Background and dark styling for sheets and navigation stacks.
    func appScreen(themeColor: String) -> some View {
        self
            .background(AppBackground(themeColor: themeColor))
            .preferredColorScheme(.dark)
    }
}

// MARK: - Colour choices

struct NamedColor: Identifiable {
    let hex: String
    let name: String
    var color: Color { Color(hex: hex) }
    var id: String { hex }
}

extension Color {
    /// Button colours (dark enough for white labels).
    static let buttonColors: [NamedColor] = [
        NamedColor(hex: "#00A8CC", name: "Teal"), NamedColor(hex: "#0077B6", name: "Ocean"),
        NamedColor(hex: "#1565C0", name: "Blue"), NamedColor(hex: "#6A1B9A", name: "Purple"),
        NamedColor(hex: "#AD1457", name: "Raspberry"), NamedColor(hex: "#C62828", name: "Red"),
        NamedColor(hex: "#D84315", name: "Rust"), NamedColor(hex: "#EF6C00", name: "Orange"),
        NamedColor(hex: "#2E7D32", name: "Green"), NamedColor(hex: "#00695C", name: "Pine")
    ]

    /// Background themes.
    static let themeColors: [NamedColor] = [
        NamedColor(hex: "#0B4F8A", name: "Deep water"), NamedColor(hex: "#00A8CC", name: "Teal"),
        NamedColor(hex: "#0077B6", name: "Ocean"), NamedColor(hex: "#1565C0", name: "Blue"),
        NamedColor(hex: "#6A1B9A", name: "Purple"), NamedColor(hex: "#4A148C", name: "Violet"),
        NamedColor(hex: "#AD1457", name: "Raspberry"), NamedColor(hex: "#C62828", name: "Red"),
        NamedColor(hex: "#00695C", name: "Pine")
    ]

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard !hex.isEmpty, Scanner(string: hex).scanHexInt64(&int) else {
            self.init(.sRGB, red: 0.36, green: 0.72, blue: 0.96, opacity: 1)
            return
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 93, 183, 245)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Number input

enum NumberInput {
    /// Parses what someone typed on a decimal pad, accepting either "." or "," as the separator.
    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
