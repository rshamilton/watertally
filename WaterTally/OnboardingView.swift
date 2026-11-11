//
//  OnboardingView.swift
//  Water Tally
//
//  First-run flow: welcome → goal & units → try it → Apple Health (optional) →
//  reminders (optional) → legal acknowledgment (required).
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var page: Int = {
        #if DEBUG
        return Int(DebugLaunch.value(after: "-onboardingPage") ?? "") ?? 0
        #else
        return 0
        #endif
    }()
    @State private var useMetric = false
    @State private var goalText = "64"

    private let lastPage = 5

    var body: some View {
        ZStack {
            AppBackground(themeColor: AppState.defaultThemeColor)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                TabView(selection: $page) {
                    WelcomePage().tag(0)
                    GoalPage(useMetric: $useMetric, goalText: $goalText).tag(1)
                    TryItPage(useMetric: useMetric).tag(2)
                    HealthPage(appState: appState).tag(3)
                    RemindersPage(appState: appState).tag(4)
                    ConsentPage(onAccept: finish).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .clipped()
                .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)

                if page < lastPage {
                    VStack(spacing: 14) {
                        PageDots(current: page, total: lastPage + 1)
                        Button(page == 0 ? "Get Started" : "Continue") {
                            withAnimation(.easeInOut) { page += 1 }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 420)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else {
                    PageDots(current: page, total: lastPage + 1)
                        .padding(.bottom, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        HStack {
            if page > 0 {
                Button { withAnimation { page -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .accessibilityLabel("Back")
            }
            Spacer()
            if page < lastPage {
                Button("Skip") { withAnimation { page = lastPage } }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint("Skips to the final step")
            }
        }
        .foregroundColor(.water)
        .frame(height: 44)
    }

    private func finish() {
        appState.useMetric = useMetric
        appState.saveUnitPreference()
        if useMetric { appState.useMetricDefaultButtonsIfUntouched() }

        if let value = Double(goalText.replacingOccurrences(of: ",", with: ".")) {
            let ounces = Volume.fromDisplay(value, metric: useMetric)
            if ounces >= Limits.minGoalOunces - 0.5 && ounces <= Limits.maxGoalOunces + 0.5 {
                appState.dailyGoal = ounces
                appState.saveGoal()
            }
        }
        appState.acceptLegal()
        appState.completeOnboarding()
        appState.rescheduleReminders()
    }
}

// MARK: - Shared page chrome

private struct PageScaffold<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) { content }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct PageTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PageSubtitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PageIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .medium))
            .foregroundColor(.water)
            .frame(width: 72, height: 72)
            .background(Circle().fill(Color.cardFill))
            .accessibilityHidden(true)
    }
}

struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.water : Color.white.opacity(0.2))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

// MARK: - 1. Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            BrandMark(size: 112)

            VStack(spacing: 12) {
                Text(AppInfo.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Log your water in one tap.\nSee your day at a glance.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 2. Goal & units

private struct GoalPage: View {
    @Binding var useMetric: Bool
    @Binding var goalText: String
    @FocusState private var focused: Bool

    private var presets: [Double] { useMetric ? [1500, 2000, 2500, 3000] : [48, 64, 80, 96] }

    var body: some View {
        PageScaffold {
            PageTitle(text: "Set your daily goal")
            PageSubtitle(text: "Pick your units and a target you'd like to aim for. You can change both any time.")

            Picker("Units", selection: $useMetric) {
                Text("Ounces (oz)").tag(false)
                Text("Millilitres (ml)").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: useMetric) { _, metric in convertGoal(toMetric: metric) }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("Goal", text: $goalText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 190)
                    .padding(.vertical, 8)
                    .card(cornerRadius: 20)
                    .focused($focused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focused = false }
                        }
                    }
                    .accessibilityLabel("Daily goal in \(Volume.unit(metric: useMetric))")
                Text(Volume.unit(metric: useMetric))
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        goalText = Volume.number(displayValue: preset, metric: useMetric)
                        focused = false
                    } label: {
                        Text("\(Volume.number(displayValue: preset, metric: useMetric)) \(Volume.unit(metric: useMetric))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .card(cornerRadius: 14)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: 420)

            Text("This is a personal target for tracking, not a recommendation. \(LegalCopy.professional)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    private func convertGoal(toMetric metric: Bool) {
        guard let value = Double(goalText.replacingOccurrences(of: ",", with: ".")) else {
            goalText = Volume.number(displayValue: metric ? 2000 : 64, metric: metric)
            return
        }
        let ounces = Volume.fromDisplay(value, metric: !metric)
        let converted = Volume.toDisplay(ounces, metric: metric)
        // Round to friendly numbers: whole ounces, or the nearest 50 ml.
        let rounded = metric ? (converted / 50).rounded() * 50 : converted.rounded()
        goalText = Volume.number(displayValue: rounded, metric: metric)
    }
}

// MARK: - 3. Try it

private struct TryItPage: View {
    let useMetric: Bool
    @State private var total: Double = 0   // ounces
    @State private var hasLogged = false

    private var buttons: [(String, String, Double)] {
        useMetric
            ? [("Glass", "#00A8CC", Volume.fromDisplay(250, metric: true)),
               ("Bottle", "#0077B6", Volume.fromDisplay(500, metric: true)),
               ("Large", "#1565C0", Volume.fromDisplay(750, metric: true))]
            : [("Glass", "#00A8CC", 8), ("Bottle", "#0077B6", 16), ("Large", "#1565C0", 24)]
    }

    var body: some View {
        PageScaffold {
            PageTitle(text: "Try it out")
            PageSubtitle(text: "One tap logs a drink. You can make your own buttons later in Edit.")

            VStack(spacing: 2) {
                Text(Volume.number(total, metric: useMetric))
                    .font(.system(size: 68, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("\(Volume.unit(metric: useMetric)) (practice, not saved)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                ForEach(buttons, id: \.0) { name, color, ounces in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            total += ounces
                            hasLogged = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Text(name).font(.system(size: 17, weight: .semibold))
                            Text(Volume.string(ounces, metric: useMetric))
                                .font(.system(size: 14, weight: .medium)).opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                    }
                    .buttonStyle(TileButtonStyle(color: Color(hex: color)))
                }
            }
            .frame(maxWidth: 460)

            if hasLogged {
                Text("That's all there is to it.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.goalGreen)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 10) {
                tip("calendar", "Tap the date to jump to any day")
                tip("hand.draw", "Swipe left or right to change days")
                tip("arrow.uturn.backward", "Made a mistake? Tap Undo right after logging")
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.water).frame(width: 24)
            Text(text).font(.footnote).foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 4. Apple Health

private struct HealthPage: View {
    @ObservedObject var appState: AppState
    @State private var isWorking = false

    private var connected: Bool { appState.healthKitEnabled && appState.healthKitManager.isAuthorized }

    var body: some View {
        PageScaffold {
            PageIcon(systemName: "heart")

            PageTitle(text: "Apple Health (optional)")
            PageSubtitle(text: "Save your water to Apple Health so it sits alongside your other health data and can be restored on a new phone.")

            VStack(alignment: .leading, spacing: 12) {
                bullet("Only water is read or written. Nothing else in Health is touched.")
                bullet("Your data goes to Apple Health on your device, never to us.")
                bullet("Turn it off any time in Settings.")
            }
            .padding(18)
            .frame(maxWidth: 460, alignment: .leading)
            .card(cornerRadius: 18)

            if connected {
                Label("Connected", systemImage: "checkmark")
                    .font(.headline)
                    .foregroundColor(.goalGreen)
            } else if appState.healthKitManager.isAvailable {
                Button {
                    isWorking = true
                    appState.setHealthKitEnabled(true) { _ in isWorking = false }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.night) }
                        Text("Connect Apple Health")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 420)
                .disabled(isWorking)

                Text("Not now? Just tap Continue.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
            } else {
                Text("Apple Health isn't available on this device.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundColor(.water).padding(.top, 3)
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - 5. Reminders

private struct RemindersPage: View {
    @ObservedObject var appState: AppState

    var body: some View {
        PageScaffold {
            PageIcon(systemName: "bell")

            PageTitle(text: "Gentle reminders (optional)")
            PageSubtitle(text: "Get a nudge to log a drink during the hours you choose. Reminders are created on your device and stop for the day once you reach your goal.")

            if appState.remindersEnabled {
                Label("Reminders are on. Change the schedule in Settings.", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.goalGreen)
                    .multilineTextAlignment(.center)
            } else {
                Button("Turn On Reminders") { appState.setReminders(enabled: true) }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 420)
                Text("Not now? Just tap Continue.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }
}

// MARK: - 6. Consent

private struct ConsentPage: View {
    let onAccept: () -> Void

    var body: some View {
        PageScaffold {
            PageTitle(text: "One last thing")
            PageSubtitle(text: "Please read this short summary.")

            LegalPoints()
                .padding(18)
                .card(cornerRadius: 18)
                .frame(maxWidth: 520)

            LegalConsentActions(onAccept: onAccept)
                .frame(maxWidth: 520)
        }
    }
}

#Preview {
    OnboardingView(appState: AppState())
}
