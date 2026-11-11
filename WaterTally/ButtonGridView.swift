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
                let height: CGFloat = appState.buttons.count <= 4 ? 88 : 76

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
        .buttonStyle(TileButtonStyle(color: Color(hex: button.color)))
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
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            if button.isCustom {
                Text("Enter amount")
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.8)
            } else if button.showAmount {
                Text(appState.formatVolume(button.fluidOunces))
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.8)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
    }
}

/// A flat, solid tile in the button's own colour.
struct TileButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(configuration.isPressed ? 0.18 : 0))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
                        .card(cornerRadius: 16)
                        .focused($focused)
                        .onChange(of: amount) { _, newValue in
                            if let value = NumberInput.parse(newValue), value > appState.maxDisplayAmount {
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
                    Button("Cancel") { dismiss() }.foregroundColor(.water)
                }
            }
            .appScreen(themeColor: appState.themeColor)
            .onAppear { focused = true }
        }
    }

    private func add() {
        guard let value = NumberInput.parse(amount) else {
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
