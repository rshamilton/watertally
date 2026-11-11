//
//  GoalSettingsView.swift
//  Water Tally
//

import SwiftUI

struct GoalSettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var goalText: String
    @State private var errorText: String?
    @FocusState private var focused: Bool

    init(appState: AppState) {
        self.appState = appState
        _goalText = State(initialValue: Volume.number(appState.dailyGoal, metric: appState.useMetric))
    }

    private var presets: [Double] {
        appState.useMetric ? [1500, 2000, 2500, 3000] : [48, 64, 80, 96]
    }

    private var enteredOunces: Double? {
        guard let value = Double(goalText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return appState.convertFromDisplayUnit(value)
    }

    private var showsHighGoalNote: Bool {
        (enteredOunces ?? 0) >= Limits.highGoalWarningOunces
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 8) {
                        Text("Your daily goal")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("A target you choose for tracking. It isn't a medical recommendation.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TextField("Goal", text: $goalText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 170)
                            .padding(.vertical, 8)
                            .card(cornerRadius: 18)
                            .focused($focused)
                            .accessibilityLabel("Daily goal in \(appState.currentUnitString)")
                        Text(appState.currentUnitString)
                            .font(.title.weight(.semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    VStack(spacing: 12) {
                        Text("Quick picks")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    goalText = Volume.number(displayValue: preset, metric: appState.useMetric)
                                    focused = false
                                } label: {
                                    Text("\(Volume.number(displayValue: preset, metric: appState.useMetric)) \(appState.currentUnitString)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .card(cornerRadius: 14)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }

                    if showsHighGoalNote {
                        Label("That's a high goal. Please check with a healthcare professional before drinking this much. \(LegalCopy.overhydration)",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.14)))
                    }

                    if let errorText {
                        Text(errorText).font(.footnote).foregroundColor(.red)
                    }

                    Text("Not sure what's right for you? \(LegalCopy.professional)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    Button("Save Goal", action: save)
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.water)
                }
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }

    private func save() {
        guard let ounces = enteredOunces else {
            errorText = "Enter a number for your daily goal."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard ounces >= Limits.minGoalOunces - 0.5, ounces <= Limits.maxGoalOunces + 0.5 else {
            errorText = "Choose a goal between \(Volume.number(displayValue: appState.minDisplayGoal, metric: appState.useMetric)) and \(Volume.number(displayValue: appState.maxDisplayGoal, metric: appState.useMetric)) \(appState.currentUnitString)."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        appState.dailyGoal = ounces
        appState.saveGoal()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
