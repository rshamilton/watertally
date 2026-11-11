//
//  ContentView.swift
//  Water Tally
//
//  The main screen: today's ring, quick-log buttons, day navigation.
//

import SwiftUI
import StoreKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showWeeklySummary = false
    @State private var showSettings = false
    @State private var showGoalCelebration = false
    @Environment(\.requestReview) private var requestReview

    private var isIPadLayout: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    private var presentingCover: Bool { !appState.hasCompletedOnboarding || appState.needsLegalConsent }

    var body: some View {
        ZStack {
            AppBackground(themeColor: appState.themeColor)

            VStack(spacing: 0) {
                TopBar(appState: appState, showSettings: $showSettings)
                    .padding(.horizontal, isIPadLayout ? 30 : 20)
                    .padding(.top, 8)

                if appState.isEditMode {
                    EditModeView(appState: appState)
                        .frame(maxWidth: 700)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    GeometryReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: isIPadLayout ? 44 : 28) {
                                DayNavigator(appState: appState)
                                    .scaleEffect(isIPadLayout ? 1.25 : 1)
                                    .padding(.vertical, isIPadLayout ? 36 : 0)

                                ButtonGridView(appState: appState)
                            }
                            .padding(.vertical, 16)
                            .frame(maxWidth: 700)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollClipDisabled()
                    }
                    .simultaneousGesture(daySwipeGesture)
                    .transition(.opacity)

                    BottomBar(appState: appState, isIPadLayout: isIPadLayout)
                        .padding(.horizontal, isIPadLayout ? 40 : 20)
                        .padding(.bottom, isIPadLayout ? 32 : 12)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState.isEditMode)
        }
        .sheet(isPresented: $appState.showAddButtonModal) {
            AddButtonSheet(appState: appState).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.showCalendar) {
            CalendarView(appState: appState).presentationDetents([.large]).pageSizedSheet()
        }
        .sheet(isPresented: $appState.showHistory) {
            HistoryView(appState: appState).presentationDragIndicator(.visible).pageSizedSheet()
        }
        .sheet(isPresented: $appState.showTrends) {
            TrendsView(appState: appState).presentationDragIndicator(.visible).pageSizedSheet()
        }
        .sheet(isPresented: $showWeeklySummary) {
            WeeklySummaryView(appState: appState).pageSizedSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState).pageSizedSheet()
        }
        .fullScreenCover(isPresented: .constant(presentingCover)) {
            Group {
                if appState.hasCompletedOnboarding {
                    LegalConsentView(appState: appState)
                } else {
                    OnboardingView(appState: appState)
                }
            }
        }
        .alert(appState.errorMessage?.title ?? "Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage?.message ?? "")
        }
        .overlay {
            if showGoalCelebration {
                GoalCelebrationOverlay {
                    withAnimation { showGoalCelebration = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .overlay(alignment: .bottom) {
            if let entry = appState.undoEntry {
                UndoToast(
                    message: undoMessage(for: entry),
                    onUndo: {
                        appState.deleteLog(id: entry.id, date: entry.date)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    },
                    onDismiss: { appState.undoEntry = nil }
                )
                .padding(.bottom, appState.isEditMode ? 24 : 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(entry.id)
                .task(id: entry.id) {
                    try? await Task.sleep(for: .seconds(5))
                    if appState.undoEntry?.id == entry.id { appState.undoEntry = nil }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.undoEntry)
        .onChange(of: appState.goalJustReached) { _, reached in
            guard reached else { return }
            appState.goalJustReached = false
            withAnimation { showGoalCelebration = true }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { showGoalCelebration = false }
            }
        }
        .onAppear {
            checkForWeeklySummary()
            #if DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if DebugLaunch.has("-demoData") || DebugLaunch.has("-simulateLog") { appState.applyDebugLaunchArguments() }
                else { NSLog("DEBUGLAUNCH applied") }
                DebugLaunch.markReady()
                if DebugLaunch.value(after: "-showScreen") == "settings" { showSettings = true }
                if DebugLaunch.value(after: "-showScreen") == "weekly" { showWeeklySummary = true }
                if DebugLaunch.value(after: "-showScreen") == "celebrate" { showGoalCelebration = true }
            }
            #endif
        }
        .onChange(of: showGoalCelebration) { _, showing in
            // Reaching the goal is a good moment to ask for a review, once the overlay is gone.
            guard !showing, ReviewPrompter.shouldAsk(logs: appState.logs, version: AppInfo.version) else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                ReviewPrompter.recordPrompt(version: AppInfo.version)
                requestReview()
            }
        }
        .onChange(of: presentingCover) { _, isPresenting in
            if !isPresenting { checkForWeeklySummary() }
        }
    }

    /// "Logged 8 oz", or "Logged 8 oz to Yesterday" when logging into a past day.
    private func undoMessage(for entry: UndoEntry) -> String {
        let amount = appState.formatVolume(entry.ounces)
        guard !appState.isToday(entry.date) else { return "Logged \(amount)" }
        return "Logged \(amount) to \(appState.dateLabel(for: entry.date))"
    }

    // MARK: Swipe between days

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard !appState.isEditMode,
                      abs(value.translation.width) > 70,
                      abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                appState.shiftSelectedDate(by: value.translation.width > 0 ? -1 : 1)
            }
    }

    // MARK: Weekly summary (Sundays, once)

    private func checkForWeeklySummary() {
        guard !presentingCover else { return }
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: Date()) == 1,
              appState.logs.keys.count > 2 else { return }

        let key = "weeklySummaryShown_\(appState.dateKey(for: Date()))"
        let defaults = SharedStore.defaults
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showWeeklySummary = true }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @ObservedObject var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if appState.isEditMode {
                    withAnimation { appState.isEditMode = false }
                } else {
                    appState.showCalendar = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text(appState.isEditMode ? "Buttons" : title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if !appState.isEditMode {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .accessibilityLabel(appState.isEditMode ? "Manage buttons" : "\(appState.dateLabel(for: appState.selectedDate)). Open calendar")

            Spacer(minLength: 4)

            if appState.isEditMode {
                pill(title: "Done") {
                    withAnimation { appState.isEditMode = false }
                }
            } else {
                if !appState.isToday(appState.selectedDate) {
                    pill(title: "Today") {
                        withAnimation { appState.selectedDate = Date() }
                    }
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.cardFill))
                }
                .accessibilityLabel("Settings")

                pill(title: "Edit") {
                    withAnimation { appState.isEditMode = true }
                }
            }
        }
        .frame(minHeight: 44)
    }

    /// "Today", "Yesterday", or a short date ("Sat, Nov 7") so the buttons beside it always fit.
    private var title: String {
        let date = appState.selectedDate
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return appState.dateLabel(for: date)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func pill(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.water)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Capsule().fill(Color.cardFill))
        }
        .layoutPriority(1)
    }
}

// MARK: - Bottom bar

struct BottomBar: View {
    @ObservedObject var appState: AppState
    let isIPadLayout: Bool

    var body: some View {
        HStack(spacing: isIPadLayout ? 24 : 12) {
            item(title: "History", icon: "list.bullet", hint: "Shows the entries for the selected day") {
                appState.showHistory = true
            }
            item(title: "Trends", icon: "chart.bar", hint: "Shows charts and statistics") {
                appState.showTrends = true
            }
        }
        .frame(maxWidth: 560)
    }

    private func item(title: String, icon: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.water)
                Text(title).fontWeight(.semibold)
            }
            .font(.system(size: isIPadLayout ? 20 : 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isIPadLayout ? 64 : 50)
            .card(cornerRadius: 14)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint(hint)
    }
}

// MARK: - Day navigator (ring with previous/next day controls)

struct DayNavigator: View {
    @ObservedObject var appState: AppState

    private var canGoForward: Bool { !appState.isToday(appState.selectedDate) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                chevron("chevron.left", label: "Previous day", enabled: true) {
                    appState.shiftSelectedDate(by: -1)
                }
                ProgressRing(appState: appState)
                chevron("chevron.right", label: "Next day", enabled: canGoForward) {
                    appState.shiftSelectedDate(by: 1)
                }
            }

            GoalCaption(appState: appState)
        }
    }

    private func chevron(_ name: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(enabled ? 0.55 : 0.12))
                .frame(width: 44, height: 88)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct ProgressRing: View {
    @ObservedObject var appState: AppState

    private let size: CGFloat = 220
    private var total: Double { appState.totalFluidOunces(for: appState.selectedDate) }
    private var goalMet: Bool { Limits.isGoalMet(total: total, goal: appState.dailyGoal) }
    private var progress: Double { appState.goalProgress(for: appState.selectedDate) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(goalMet ? Color.goalGreen : Color.water,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: progress)

            VStack(spacing: 0) {
                Text(appState.formatNumber(total))
                    .font(.system(size: appState.useMetric ? 56 : 68, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: total))
                    .animation(.snappy, value: total)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: size - 40)

                Text("\(appState.currentUnitString)\(appState.isToday(appState.selectedDate) ? " today" : "")")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.dateLabel(for: appState.selectedDate)) total")
        .accessibilityValue("\(appState.formatVolume(total)) of \(appState.formatVolume(appState.dailyGoal)) goal, \(Int((progress * 100).rounded())) percent")
    }
}

struct GoalCaption: View {
    @ObservedObject var appState: AppState

    var body: some View {
        let total = appState.totalFluidOunces(for: appState.selectedDate)
        let remaining = max(appState.dailyGoal - total, 0)
        let met = Limits.isGoalMet(total: total, goal: appState.dailyGoal)

        HStack(spacing: 10) {
            Text(met
                 ? "Goal reached · \(appState.formatVolume(appState.dailyGoal))"
                 : "\(appState.formatVolume(remaining)) to go · Goal \(appState.formatVolume(appState.dailyGoal))")
                .font(.subheadline.weight(.medium))
                .foregroundColor(met ? .goalGreen : .white.opacity(0.7))

            if appState.currentStreak > 0 {
                Label("\(appState.currentStreak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                    .accessibilityLabel("\(appState.currentStreak) day streak")
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .padding(.horizontal, 20)
    }
}

// MARK: - Celebration

/// Shown briefly when today's goal is reached. A tap anywhere dismisses it early; the tap is
/// absorbed by the overlay, so it never presses a button underneath.
struct GoalCelebrationOverlay: View {
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.night)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.goalGreen))
                Text("Goal reached")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Nice work today.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.night))
            .card(cornerRadius: 24)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal reached")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "Dismiss", onDismiss)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Undo toast

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.water)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#1A2A3C"))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardEdge))
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
    }
}
