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
            AppBackground(themeColor: "#0B4F8A", diagonal: true)

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
        .foregroundColor(.cyan)
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

struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.cyan : Color.white.opacity(0.28))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

// MARK: - 1. Welcome

private struct WelcomePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            TallyMark(size: 150)
                .offset(y: float ? -6 : 6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: float)
                .onAppear { float = true }

            VStack(spacing: 10) {
                Text("Welcome to \(AppInfo.name)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .glowingText()
                Text("Log your water in one tap.\nSee your day at a glance.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
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
                    .liquidGlassBackground(cornerRadius: 20)
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
                            .liquidGlassBackground(cornerRadius: 14)
                    }
                    .buttonStyle(FluidButtonStyle())
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
            ? [("Glass", "cup.and.saucer.fill", Volume.fromDisplay(250, metric: true)),
               ("Bottle", "waterbottle.fill", Volume.fromDisplay(500, metric: true)),
               ("Large", "drop.fill", Volume.fromDisplay(750, metric: true))]
            : [("Glass", "cup.and.saucer.fill", 8), ("Bottle", "waterbottle.fill", 16), ("Large", "drop.fill", 24)]
    }

    var body: some View {
        PageScaffold {
            PageTitle(text: "Try it out")
            PageSubtitle(text: "One tap logs a drink. You can make your own buttons later in Edit.")

            VStack(spacing: 2) {
                Text(Volume.number(total, metric: useMetric))
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                    .contentTransition(.numericText())
                Text("\(Volume.unit(metric: useMetric)) (practice, not saved)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                ForEach(buttons, id: \.0) { name, icon, ounces in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            total += ounces
                            hasLogged = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: icon).font(.system(size: 28)).foregroundColor(.cyan)
                            Text(name).font(.subheadline.bold()).foregroundColor(.white)
                            Text(Volume.string(ounces, metric: useMetric))
                                .font(.caption).foregroundColor(.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .liquidGlassBackground(cornerRadius: 16)
                    }
                    .buttonStyle(FluidButtonStyle())
                }
            }
            .frame(maxWidth: 460)

            if hasLogged {
                Label("Nice! That's all there is to it.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
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
            Image(systemName: icon).foregroundColor(.cyan).frame(width: 24)
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
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 76))
                .foregroundColor(.pink)
                .shadow(color: .pink.opacity(0.5), radius: 14)
                .accessibilityHidden(true)

            PageTitle(text: "Apple Health (optional)")
            PageSubtitle(text: "Save your water to Apple Health so it sits alongside your other health data and can be restored on a new phone.")

            VStack(alignment: .leading, spacing: 12) {
                bullet("Only water is read or written. Nothing else in Health is touched.")
                bullet("Your data goes to Apple Health on your device, never to us.")
                bullet("Turn it off any time in Settings.")
            }
            .padding(18)
            .frame(maxWidth: 460, alignment: .leading)
            .liquidGlassBackground(cornerRadius: 18)

            if connected {
                Label("Connected. You're all set.", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
            } else if appState.healthKitManager.isAvailable {
                Button {
                    isWorking = true
                    appState.setHealthKitEnabled(true) { _ in isWorking = false }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.black) }
                        Text("Connect Apple Health")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: .pink))
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
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - 5. Reminders

private struct RemindersPage: View {
    @ObservedObject var appState: AppState

    var body: some View {
        PageScaffold {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 70))
                .foregroundStyle(.yellow, .cyan)
                .accessibilityHidden(true)

            PageTitle(text: "Gentle reminders (optional)")
            PageSubtitle(text: "Get a nudge to log a drink during the hours you choose. Reminders are created on your device and stop for the day once you reach your goal.")

            if appState.remindersEnabled {
                Label("Reminders are on. Change the schedule in Settings.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            } else {
                Button("Turn On Reminders") { appState.setReminders(enabled: true) }
                    .buttonStyle(PrimaryButtonStyle(tint: .yellow))
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
                .liquidGlassBackground(cornerRadius: 18)
                .frame(maxWidth: 520)

            LegalConsentActions(onAccept: onAccept)
                .frame(maxWidth: 520)
        }
    }
}

#Preview {
    OnboardingView(appState: AppState())
}
