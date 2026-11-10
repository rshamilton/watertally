//
//  WaterTallyWidget.swift
//  WaterTallyWidgets
//
//  Home-screen and Lock Screen widgets. Widgets read and write the same App Group data as
//  the app (see Shared/SharedModels.swift). Nothing here touches the network.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Quick-log intent

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Adds a drink to your log without opening the app.")

    @Parameter(title: "Amount (oz)")
    var amount: Double

    @Parameter(title: "Name")
    var name: String

    init(amount: Double, name: String) {
        self.amount = amount
        self.name = name
    }

    init() {
        self.amount = 0
        self.name = "Widget"
    }

    func perform() async throws -> some IntentResult {
        // Never log before the user has finished setup and acknowledged the legal terms.
        guard SharedStore.isSetUp,
              amount >= Limits.minLogOunces, amount <= Limits.maxLogOunces else { return .result() }

        let defaults = SharedStore.defaults
        var logs = SharedStore.loadLogs() ?? [:]
        // If stored history exists but couldn't be read, do nothing rather than risk overwriting it.
        if logs.isEmpty && defaults.data(forKey: SharedStore.Key.logs) != nil { return .result() }

        let key = DayKey.string(for: Date())
        guard (logs[key]?.count ?? 0) < Limits.maxLogsPerDay else { return .result() }

        logs[key, default: []].append(WaterLog(fluidOunces: amount, buttonName: name.isEmpty ? "Widget" : name))
        SharedStore.saveLogs(logs)

        var counts = SharedStore.loadUsageCounts()
        counts[name, default: 0] += 1
        SharedStore.saveUsageCounts(counts)

        let goal = SharedStore.storedGoal()
        let streaks = StreakCalculator.compute(logs: logs, goal: goal)
        defaults.set(streaks.current, forKey: SharedStore.Key.currentStreak)
        defaults.set(max(streaks.longest, defaults.integer(forKey: SharedStore.Key.longestStreak)),
                     forKey: SharedStore.Key.longestStreak)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline

struct WidgetButton: Identifiable {
    let id: UUID
    let name: String
    let ounces: Double
    let color: String
}

struct TallyEntry: TimelineEntry {
    let date: Date
    let isSetUp: Bool
    let todayTotal: Double
    let dailyGoal: Double
    let currentStreak: Int
    let buttons: [WidgetButton]
    let useMetric: Bool

    var progress: Double { dailyGoal > 0 ? min(todayTotal / dailyGoal, 1) : 0 }
    var goalMet: Bool { Limits.isGoalMet(total: todayTotal, goal: dailyGoal) }

    func number(_ ounces: Double) -> String { Volume.number(ounces, metric: useMetric) }
    var unit: String { Volume.unit(metric: useMetric) }

    /// Compact total for tight spaces: "1.2 L" style for large millilitre values.
    func compactTotal(_ ounces: Double) -> (value: String, unit: String) {
        if useMetric {
            let ml = ounces * Volume.mlPerOunce
            if ml >= 10_000 { return (String(format: "%.0f", ml / 1000), "L") }
            if ml >= 1000 { return (String(format: "%.1f", ml / 1000), "L") }
        }
        return (number(ounces), unit)
    }
}

struct TallyProvider: TimelineProvider {
    func placeholder(in context: Context) -> TallyEntry {
        TallyEntry(date: Date(), isSetUp: true, todayTotal: 32, dailyGoal: 64, currentStreak: 5,
                  buttons: [WidgetButton(id: UUID(), name: "Glass", ounces: 8, color: "#00A8CC"),
                            WidgetButton(id: UUID(), name: "Bottle", ounces: 16, color: "#0077B6")],
                  useMetric: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TallyEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TallyEntry>) -> Void) {
        let now = Date()
        var entries = [loadEntry(for: now)]

        // A second entry at midnight so the ring resets on time even if the app isn't opened.
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .nextTime) {
            var next = loadEntry(for: midnight)
            next = TallyEntry(date: midnight, isSetUp: next.isSetUp, todayTotal: 0, dailyGoal: next.dailyGoal,
                             currentStreak: next.currentStreak, buttons: next.buttons, useMetric: next.useMetric)
            entries.append(next)
        }
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func loadEntry(for date: Date) -> TallyEntry {
        let defaults = SharedStore.defaults
        let logs = SharedStore.loadLogs() ?? [:]
        let total = logs[DayKey.string(for: date)]?.reduce(0) { $0 + $1.fluidOunces } ?? 0

        let counts = SharedStore.loadUsageCounts()
        let buttons = (SharedStore.loadButtons() ?? [])
            .filter { !$0.isCustom && $0.fluidOunces > 0 }
            .sorted { (counts[$0.name] ?? 0, -$0.order) > (counts[$1.name] ?? 0, -$1.order) }
            .prefix(4)
            .map { WidgetButton(id: $0.id, name: $0.name, ounces: $0.fluidOunces, color: $0.color) }

        return TallyEntry(date: date, isSetUp: SharedStore.isSetUp, todayTotal: total,
                         dailyGoal: SharedStore.storedGoal(),
                         currentStreak: defaults.integer(forKey: SharedStore.Key.currentStreak),
                         buttons: Array(buttons), useMetric: defaults.bool(forKey: SharedStore.Key.useMetric))
    }
}

// MARK: - Shared styling

private let widgetBackground = LinearGradient(
    colors: [Color(hex: "#020B14"), Color(hex: "#0B4F8A").opacity(0.75), Color(hex: "#0AA5D6").opacity(0.45)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

private let ringGradient = LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
private let doneGradient = LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)

private struct SetupPrompt: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "drop.fill").font(.title2).foregroundStyle(.cyan)
            Text("Open Water Tally to get started")
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QuickLogButton: View {
    let entry: TallyEntry
    let button: WidgetButton
    var compact = false

    var body: some View {
        Button(intent: LogWaterIntent(amount: button.ounces, name: button.name)) {
            VStack(spacing: compact ? 2 : 4) {
                Text(button.name)
                    .font(.system(size: compact ? 14 : 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(Volume.string(button.ounces, metric: entry.useMetric))
                    .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
                    .opacity(0.85)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: button.color).opacity(0.38))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: button.color), lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressBar: View {
    let progress: Double
    let done: Bool
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.22))
                Capsule()
                    .fill(done ? doneGradient : ringGradient)
                    .frame(width: max(proxy.size.width * progress, progress > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Small

private struct SmallView: View {
    let entry: TallyEntry

    var body: some View {
        if !entry.isSetUp {
            SetupPrompt()
        } else {
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(entry.goalMet ? doneGradient : ringGradient,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        let total = entry.compactTotal(entry.todayTotal)
                        Text(total.value)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(total.unit)
                            .font(.system(size: 13, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                }
                .frame(width: 104, height: 104)

                Text("of \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today \(Volume.string(entry.todayTotal, metric: entry.useMetric)) of \(Volume.string(entry.dailyGoal, metric: entry.useMetric)) goal")
        }
    }
}

// MARK: - Medium

private struct MediumView: View {
    let entry: TallyEntry

    var body: some View {
        if !entry.isSetUp {
            SetupPrompt()
        } else {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    let total = entry.compactTotal(entry.todayTotal)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(total.value)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(total.unit)
                            .font(.system(size: 16, weight: .semibold))
                            .opacity(0.7)
                    }
                    Text("of \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    ProgressBar(progress: entry.progress, done: entry.goalMet)
                    Label("\(entry.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.buttons.isEmpty {
                    Text("Add buttons in the app")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 130)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entry.buttons.prefix(2)) { QuickLogButton(entry: entry, button: $0) }
                    }
                    .frame(width: 140)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Large

private struct LargeView: View {
    let entry: TallyEntry

    var body: some View {
        if !entry.isSetUp {
            SetupPrompt()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.system(size: 15, weight: .semibold))
                            .opacity(0.8)
                        let total = entry.compactTotal(entry.todayTotal)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(total.value)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text("/ \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
                                .font(.system(size: 18, weight: .medium))
                                .opacity(0.7)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Label("\(entry.currentStreak)", systemImage: "flame.fill")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("day streak").font(.system(size: 12)).opacity(0.7)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                }

                ProgressBar(progress: entry.progress, done: entry.goalMet, height: 16)

                Text("Quick log")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.75)
                    .padding(.top, 2)

                if entry.buttons.isEmpty {
                    Text("Add buttons in the app to log from here.")
                        .font(.footnote)
                        .opacity(0.7)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(entry.buttons) { QuickLogButton(entry: entry, button: $0) }
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Lock Screen

private struct CircularView: View {
    let entry: TallyEntry

    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(entry.compactTotal(entry.todayTotal).value)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel("Water today \(Volume.string(entry.todayTotal, metric: entry.useMetric)) of \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
    }
}

private struct RectangularView: View {
    let entry: TallyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Water", systemImage: "drop.fill").font(.headline)
            Text("\(Volume.string(entry.todayTotal, metric: entry.useMetric)) of \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
                .font(.subheadline)
            ProgressView(value: entry.progress)
        }
    }
}

// MARK: - Widget

struct WaterTallyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppInfo.widgetKind, provider: TallyProvider()) { entry in
            WaterTallyWidgetView(entry: entry)
                .widgetURL(URL(string: "\(AppInfo.urlScheme)://open"))
                .containerBackground(for: .widget) { widgetBackground }
        }
        .configurationDisplayName("Water Tally")
        .description("See today's progress and log a drink with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WaterTallyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TallyEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .systemLarge: LargeView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline:
            Text("\(Image(systemName: "drop.fill")) \(Volume.string(entry.todayTotal, metric: entry.useMetric)) / \(Volume.string(entry.dailyGoal, metric: entry.useMetric))")
        default: SmallView(entry: entry)
        }
    }
}

// MARK: - Colour helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard hex.count == 6, Scanner(string: hex).scanHexInt64(&int) else {
            self.init(.sRGB, red: 0, green: 0.66, blue: 0.8, opacity: 1)
            return
        }
        self.init(.sRGB, red: Double(int >> 16) / 255, green: Double(int >> 8 & 0xFF) / 255,
                  blue: Double(int & 0xFF) / 255, opacity: 1)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    WaterTallyWidget()
} timeline: {
    TallyEntry(date: .now, isSetUp: true, todayTotal: 32, dailyGoal: 64, currentStreak: 5,
              buttons: [WidgetButton(id: UUID(), name: "Glass", ounces: 8, color: "#00A8CC")], useMetric: false)
}
