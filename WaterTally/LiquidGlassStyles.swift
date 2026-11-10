//
//  LiquidGlassStyles.swift
//  Water Tally
//
//  Shared look & feel: deep-water backgrounds, glass cards with an aqua edge.
//

import SwiftUI

// MARK: - Background

/// Deep-water gradient tinted by the user's theme colour. Used behind every screen.
struct AppBackground: View {
    let themeColor: String
    var diagonal = false

    var body: some View {
        let theme = Color(hex: themeColor)
        LinearGradient(
            colors: diagonal
                ? [.black, theme.opacity(0.35), theme.opacity(0.22), .black]
                : [.black, theme.opacity(0.28), theme.opacity(0.14)],
            startPoint: diagonal ? .topLeading : .top,
            endPoint: diagonal ? .bottomTrailing : .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Glass card

struct LiquidGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.thinMaterial)
                        )
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.cyan.opacity(0.75), Color.cyan.opacity(0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2
                        )
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct GlowingText: ViewModifier {
    var color: Color = .cyan

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .shadow(color: color.opacity(0.55), radius: 6, x: 0, y: 0)
    }
}

struct FluidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Filled, high-contrast call-to-action used for primary buttons.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: tint.opacity(0.45), radius: 12, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func liquidGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassBackground(cornerRadius: cornerRadius))
    }

    func glowingText(color: Color = .cyan) -> some View {
        modifier(GlowingText(color: color))
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

    /// Dark styling for sheets/navigation stacks so system chrome stays legible on the dark UI.
    func appScreen(themeColor: String) -> some View {
        self
            .background(AppBackground(themeColor: themeColor))
            .preferredColorScheme(.dark)
    }
}

// MARK: - Colours

extension Color {
    static let neonCyan = Color(red: 0.0, green: 0.66, blue: 0.8)

    /// Button colours (dark enough for white labels).
    static let buttonColors: [(String, Color)] = [
        "#00A8CC", "#0077B6", "#1565C0", "#6A1B9A", "#AD1457",
        "#C62828", "#D84315", "#EF6C00", "#2E7D32", "#00695C"
    ].map { ($0, Color(hex: $0)) }

    /// Background themes.
    static let themeColors: [(String, Color)] = [
        "#0B4F8A", "#00A8CC", "#0077B6", "#1565C0",
        "#6A1B9A", "#4A148C", "#AD1457", "#C62828", "#00695C"
    ].map { ($0, Color(hex: $0)) }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard !hex.isEmpty, Scanner(string: hex).scanHexInt64(&int) else {
            self.init(.sRGB, red: 0.0, green: 0.66, blue: 0.8, opacity: 1)
            return
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 168, 204)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
