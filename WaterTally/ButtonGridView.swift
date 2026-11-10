//
//  ButtonGridView.swift
//  Water Tally
//
//  The quick-log buttons on the main screen, plus the "custom amount" entry sheet.
//

import SwiftUI

struct ButtonGridView: View {
    @ObservedObject var appState: AppState
    @State private var customButton: HydrationButton?

    var body: some View {
        Group {
            if appState.buttons.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.cyan.opacity(0.6))
                    Text("No buttons yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tap Edit to add your first button.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                let rows = Self.rows(for: appState.buttons.count)
                let height: CGFloat = appState.buttons.count <= 4 ? 96 : 84

                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { index in
                                if index < appState.buttons.count {
                                    tile(appState.buttons[index], height: height)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(item: $customButton) { button in
            CustomAmountView(appState: appState, button: button)
                .presentationDetents([.medium])
        }
    }

    private func tile(_ button: HydrationButton, height: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if button.isCustom {
                customButton = button
            } else {
                appState.addLog(fluidOunces: button.fluidOunces, buttonName: button.name)
            }
        } label: {
            HydrationButtonLabel(appState: appState, button: button)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(GlassTileStyle(color: Color(hex: button.color)))
        .accessibilityLabel(button.isCustom
            ? "\(button.name.isEmpty ? "Custom" : button.name), enter a custom amount"
            : "Log \(appState.formatVolume(button.fluidOunces)), \(button.name)")
    }

    /// Row layout for `count` buttons: pairs for small sets, threes for larger ones.
    static func rows(for count: Int) -> [[Int]] {
        switch count {
        case 0: return []
        case 1: return [[0]]
        case 2: return [[0, 1]]
        case 3: return [[0, 1], [2]]
        case 4: return [[0, 1], [2, 3]]
        default:
            return stride(from: 0, to: count, by: 3).map { Array($0..<min($0 + 3, count)) }
        }
    }
}

struct HydrationButtonLabel: View {
    @ObservedObject var appState: AppState
    let button: HydrationButton

    var body: some View {
        VStack(spacing: 4) {
            if !button.name.isEmpty {
                Text(button.name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            if button.isCustom {
                Label("Enter amount", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .labelStyle(.titleAndIcon)
                    .opacity(0.85)
            } else if button.showAmount {
                Text(appState.formatVolume(button.fluidOunces))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.9)
            }
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.35), radius: 2)
        .padding(.horizontal, 6)
    }
}

struct GlassTileStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [color.opacity(0.32), Color.black.opacity(0.35)],
                                             startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color, lineWidth: 2)
                        .shadow(color: color.opacity(0.8), radius: 6))
            )
            .shadow(color: color.opacity(0.35), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Custom amount

struct CustomAmountView: View {
    @ObservedObject var appState: AppState
    let button: HydrationButton
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var errorText: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How much did you drink?")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 8)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                        .padding(.vertical, 10)
                        .liquidGlassBackground(cornerRadius: 16)
                        .focused($focused)
                        .onChange(of: amount) { _, newValue in
                            if let value = Double(newValue), value > appState.maxDisplayAmount {
                                amount = Volume.number(displayValue: appState.maxDisplayAmount, metric: appState.useMetric)
                            }
                        }
                        .accessibilityLabel("Amount in \(appState.currentUnitString)")

                    Text(appState.currentUnitString)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                Button("Add", action: add)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.cyan)
                }
            }
            .appScreen(themeColor: appState.themeColor)
            .onAppear { focused = true }
        }
    }

    private func add() {
        let text = amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(text) else {
            errorText = "Enter an amount to continue."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        let ounces = appState.convertFromDisplayUnit(value)
        guard ounces >= Limits.minLogOunces else {
            errorText = "Enter at least \(appState.formatVolume(Limits.minLogOunces))."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard ounces <= Limits.maxLogOunces else {
            errorText = "The maximum for one entry is \(appState.formatVolume(Limits.maxLogOunces))."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        appState.addLog(fluidOunces: ounces, buttonName: button.name.isEmpty ? "Custom" : button.name)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
