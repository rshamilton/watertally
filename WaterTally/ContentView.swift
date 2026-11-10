//
//  ContentView.swift
//  Water Tally
//
//  The main screen: today's ring, quick-log buttons, day navigation.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showWeeklySummary = false
    @State private var showSettings = false
    @State private var showGoalCelebration = false

    private var isIPadLayout: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    private var presentingCover: Bool { !appState.hasCompletedOnboarding || appState.needsLegalConsent }

    var body: some View {
        ZStack {
            AppBackground(themeColor: appState.themeColor, diagonal: true)

            VStack(spacing: 0) {
                TopBar(appState: appState, showSettings: $showSettings)
                    .padding(.horizontal, isIPadLayout ? 30 : 20)
                    .padding(.top, 8)

                if appState.isEditMode {
                    EditModeView(appState: appState)
                        .frame(maxWidth: 700)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isIPadLayout ? 36 : 18) {
                            DayNavigator(appState: appState)
                                .padding(.top, 24)
                                .scaleEffect(isIPadLayout ? 1.25 : 1)
                                .padding(.vertical, isIPadLayout ? 36 : 0)

                            ButtonGridView(appState: appState)
                        }
                        .padding(.bottom, 12)
                        .frame(maxWidth: 700)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollClipDisabled()
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
                GoalCelebrationOverlay().transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let entry = appState.undoEntry {
                UndoToast(
                    message: "Logged \(appState.formatVolume(entry.ounces))",
                    onUndo: {
                        appState.deleteLog(id: entry.id, date: entry.date)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    },
                    onDismiss: { appState.undoEntry = nil }
                )
                .padding(.bottom, appState.isEditMode ? 24 : 96)
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
                try? await Task.sleep(for: .seconds(2.2))
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
            }
            #endif
        }
        .onChange(of: presentingCover) { _, isPresenting in
            if !isPresenting { checkForWeeklySummary() }
        }
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
                    Text(appState.isEditMode ? "Buttons" : appState.dateLabel(for: appState.selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .glowingText()
                    if !appState.isEditMode {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .accessibilityLabel(appState.isEditMode ? "Manage buttons" : "\(appState.dateLabel(for: appState.selectedDate)). Open calendar")
            .layoutPriority(1)

            Spacer(minLength: 4)

            if appState.isEditMode {
                pill(title: "Done", icon: "checkmark") {
                    withAnimation { appState.isEditMode = false }
                }
            } else {
                if !appState.isToday(appState.selectedDate) {
                    pill(title: "Today", icon: "arrow.uturn.forward") {
                        withAnimation { appState.selectedDate = Date() }
                    }
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.cyan)
                        .frame(width: 40, height: 36)
                        .liquidGlassBackground(cornerRadius: 12)
                }
                .accessibilityLabel("Settings")

                pill(title: "Edit", icon: nil) {
                    withAnimation { appState.isEditMode = true }
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func pill(title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.cyan)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .liquidGlassBackground(cornerRadius: 14)
        }
    }
}

// MARK: - Bottom bar

struct BottomBar: View {
    @ObservedObject var appState: AppState
    let isIPadLayout: Bool

    var body: some View {
        HStack(spacing: isIPadLayout ? 30 : 14) {
            item(title: "History", icon: "list.bullet", hint: "Shows the entries for the selected day") {
                appState.showHistory = true
            }
            item(title: "Trends", icon: "chart.line.uptrend.xyaxis", hint: "Shows charts and statistics") {
                appState.showTrends = true
            }
        }
        .frame(maxWidth: 560)
    }

    private func item(title: String, icon: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .font(.system(size: isIPadLayout ? 22 : 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isIPadLayout ? 72 : 50)
            .liquidGlassBackground(cornerRadius: isIPadLayout ? 30 : 25)
        }
        .buttonStyle(FluidButtonStyle())
        .accessibilityHint(hint)
    }
}

// MARK: - Day navigator (ring with previous/next day controls)

struct DayNavigator: View {
    @ObservedObject var appState: AppState

    private var canGoForward: Bool { !appState.isToday(appState.selectedDate) }

    var body: some View {
        VStack(spacing: 14) {
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
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.cyan.opacity(enabled ? 0.9 : 0.2))
                .frame(width: 44, height: 88)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct ProgressRing: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false
    @State private var bump = false

    private let size: CGFloat = 220
    private var total: Double { appState.totalFluidOunces(for: appState.selectedDate) }
    private var goalMet: Bool { Limits.isGoalMet(total: total, goal: appState.dailyGoal) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)

            Circle()
                .trim(from: 0, to: appState.goalProgress(for: appState.selectedDate))
                .stroke(
                    AngularGradient(colors: goalMet ? [.green, .mint, .green] : [.cyan, .blue, .cyan],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (goalMet ? Color.green : Color.cyan).opacity(0.6), radius: 8)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: appState.goalProgress(for: appState.selectedDate))

            VStack(spacing: 2) {
                Text(appState.formatNumber(total))
                    .font(.system(size: appState.useMetric ? 56 : 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(glow ? 0.8 : 0.4), radius: glow ? 18 : 8)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: total)
                    .scaleEffect(bump ? 1.08 : 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: size - 40)

                Text("\(appState.currentUnitString)\(appState.isToday(appState.selectedDate) ? " today" : "")")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.dateLabel(for: appState.selectedDate)) total")
        .accessibilityValue("\(appState.formatVolume(total)) of \(appState.formatVolume(appState.dailyGoal)) goal, \(Int((appState.goalProgress(for: appState.selectedDate) * 100).rounded())) percent")
        .onChange(of: total) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bump = true; glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { bump = false } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { withAnimation(.easeOut(duration: 0.5)) { glow = false } }
        }
    }
}

struct GoalCaption: View {
    @ObservedObject var appState: AppState

    var body: some View {
        let total = appState.totalFluidOunces(for: appState.selectedDate)
        let remaining = max(appState.dailyGoal - total, 0)

        HStack(spacing: 10) {
            Text(Limits.isGoalMet(total: total, goal: appState.dailyGoal)
                 ? "Goal reached · \(appState.formatVolume(appState.dailyGoal))"
                 : "\(appState.formatVolume(remaining)) to go · Goal \(appState.formatVolume(appState.dailyGoal))")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.85))

            if appState.currentStreak > 0 {
                Label("\(appState.currentStreak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .accessibilityLabel("\(appState.currentStreak) day streak")
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .padding(.horizontal, 20)
    }
}

// MARK: - Celebration

struct GoalCelebrationOverlay: View {
    private struct Dot: Identifiable {
        let id: Int
        let color: Color
        let size: CGFloat
        let x: CGFloat
        let endY: CGFloat
    }

    @State private var animate = false
    private let dots: [Dot] = (0..<40).map { i in
        Dot(id: i,
            color: [Color.yellow, .orange, .green, .cyan, .blue, .purple, .pink].randomElement()!,
            size: .random(in: 7...16),
            x: .random(in: -170...170),
            endY: .random(in: -260...320))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            ForEach(dots) { dot in
                Circle()
                    .fill(dot.color)
                    .frame(width: dot.size, height: dot.size)
                    .offset(x: animate ? dot.x : 0, y: animate ? dot.endY : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 1.6).delay(Double(dot.id) * 0.01), value: animate)
            }

            VStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .yellow.opacity(0.6), radius: 18)
                    .scaleEffect(animate ? 1 : 0.4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animate)

                Text("Goal reached!")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("Nice work today.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal reached")
        .onAppear {
            animate = true
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
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.cyan)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cyan.opacity(0.4), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
    }
}
