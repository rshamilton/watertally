//
//  TrendsView.swift
//  Water Tally
//
//  Streaks, an intake chart and a few statistics for a chosen time range.
//

import SwiftUI
import Charts

struct TrendsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var range: TimeRange = .week

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"

        var id: String { rawValue }
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }

    var body: some View {
        let data = TrendsData(appState: appState, days: range.days)

        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack(spacing: 14) {
                        streakCard(icon: "flame.fill", color: .orange, value: appState.currentStreak, title: "Current streak")
                        streakCard(icon: "trophy.fill", color: .yellow, value: appState.longestStreak, title: "Best streak")
                    }

                    Picker("Range", selection: $range) {
                        ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Time range")

                    if data.loggedDays == 0 {
                        emptyState
                    } else {
                        UsageChart(appState: appState, data: data, range: range)
                        StatsSection(appState: appState, data: data, range: range)
                    }

                    Text("Statistics describe your own logged entries only and are not medical information.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyan)
                }
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }

    private func streakCard(icon: String, color: Color, value: Int, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.6), radius: 6)
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .liquidGlassBackground(cornerRadius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value) \(value == 1 ? "day" : "days")")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 46))
                .foregroundColor(.cyan.opacity(0.4))
            Text("No entries in this range")
                .font(.headline)
                .foregroundColor(.white)
            Text("Log a few drinks and your trends will show up here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .liquidGlassBackground(cornerRadius: 20)
    }
}

// MARK: - Data

struct TrendsData {
    struct Day: Identifiable {
        let date: Date
        let ounces: Double
        var id: Date { date }
    }

    struct Bucket: Identifiable {
        let start: Date
        let averageOunces: Double
        var id: Date { start }
    }

    let days: [Day]                  // oldest → newest, zeros included
    let loggedDays: Int
    let averageOunces: Double        // per day that has entries
    let best: Day?
    let goalDays: Int
    let peakHour: Int?
    let bestWeekday: (name: String, average: Double)?
    let start: Date
    let end: Date

    init(appState: AppState, days count: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var days: [Day] = []
        var hourCounts: [Int: Int] = [:]
        var weekdayTotals: [Int: (total: Double, count: Int)] = [:]

        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let total = appState.totalFluidOunces(for: date)
            days.append(Day(date: date, ounces: total))
            guard total > 0 else { continue }

            let weekday = calendar.component(.weekday, from: date)
            let current = weekdayTotals[weekday] ?? (0, 0)
            weekdayTotals[weekday] = (current.total + total, current.count + 1)

            for log in appState.logs[appState.dateKey(for: date)] ?? [] {
                hourCounts[calendar.component(.hour, from: log.timestamp), default: 0] += 1
            }
        }

        let logged = days.filter { $0.ounces > 0 }
        self.days = days
        self.loggedDays = logged.count
        self.averageOunces = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.ounces } / Double(logged.count)
        self.best = logged.max { $0.ounces < $1.ounces }
        self.goalDays = logged.filter { Limits.isGoalMet(total: $0.ounces, goal: appState.dailyGoal) }.count
        self.peakHour = hourCounts.max { $0.value < $1.value }?.key
        if let top = weekdayTotals.max(by: { $0.value.total / Double($0.value.count) < $1.value.total / Double($1.value.count) }) {
            self.bestWeekday = (calendar.weekdaySymbols[top.key - 1], top.value.total / Double(top.value.count))
        } else {
            self.bestWeekday = nil
        }
        self.start = days.first?.date ?? today
        self.end = today
    }

    func buckets(by component: Calendar.Component) -> [Bucket] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: days.filter { $0.ounces > 0 }) {
            calendar.dateInterval(of: component, for: $0.date)?.start ?? $0.date
        }
        return grouped
            .map { Bucket(start: $0.key, averageOunces: $0.value.reduce(0) { $0 + $1.ounces } / Double($0.value.count)) }
            .sorted { $0.start < $1.start }
    }
}

// MARK: - Chart

struct UsageChart: View {
    @ObservedObject var appState: AppState
    let data: TrendsData
    let range: TrendsView.TimeRange

    private var metric: Bool { appState.useMetric }
    private var goal: Double { appState.convertToDisplayUnit(appState.dailyGoal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(range == .threeMonths ? "Weekly average" : range == .year ? "Monthly average" : "Daily intake")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(appState.currentUnitString)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            chart
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Bar chart of your water intake")
                .accessibilityValue("Average \(appState.formatVolume(data.averageOunces)) on days with entries. Goal reached on \(data.goalDays) of \(data.loggedDays) days.")

            HStack(spacing: 16) {
                legend(.cyan, "Goal reached")
                legend(.orange, "Below goal")
                legend(.white.opacity(0.6), "Goal line", dashed: true)
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .liquidGlassBackground(cornerRadius: 20)
    }

    @ViewBuilder
    private var chart: some View {
        switch range {
        case .week, .month:
            Chart {
                ForEach(data.days) { day in
                    if day.ounces > 0 {
                        BarMark(x: .value("Date", day.date, unit: .day),
                                y: .value("Amount", appState.convertToDisplayUnit(day.ounces)),
                                width: range == .week ? .fixed(22) : .ratio(0.7))
                            .foregroundStyle(Limits.isGoalMet(total: day.ounces, goal: appState.dailyGoal) ? Color.cyan : Color.orange)
                            .cornerRadius(4)
                    }
                }
                goalRule
            }
            .chartXScale(domain: data.start...Calendar.current.date(byAdding: .day, value: 1, to: data.end)!)
            .chartXAxis { xAxis(stride: range == .week ? .day : .weekOfYear, format: range == .week ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day()) }
            .chartYAxis { yAxis }

        case .threeMonths:
            bucketChart(component: .weekOfYear, stride: .month, width: .fixed(14))
        case .year:
            bucketChart(component: .month, stride: .month, width: .ratio(0.6))
        }
    }

    private func bucketChart(component: Calendar.Component, stride: Calendar.Component, width: MarkDimension) -> some View {
        Chart {
            ForEach(data.buckets(by: component)) { bucket in
                BarMark(x: .value("Date", bucket.start, unit: component),
                        y: .value("Amount", appState.convertToDisplayUnit(bucket.averageOunces)),
                        width: width)
                    .foregroundStyle(Limits.isGoalMet(total: bucket.averageOunces, goal: appState.dailyGoal) ? Color.cyan : Color.orange)
                    .cornerRadius(3)
            }
            goalRule
        }
        .chartXAxis { xAxis(stride: stride, format: .dateTime.month(.abbreviated)) }
        .chartYAxis { yAxis }
    }

    @ChartContentBuilder
    private var goalRule: some ChartContent {
        RuleMark(y: .value("Goal", goal))
            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            .foregroundStyle(Color.white.opacity(0.55))
    }

    private func xAxis(stride component: Calendar.Component, format: Date.FormatStyle) -> some AxisContent {
        AxisMarks(values: .stride(by: component)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.cyan.opacity(0.2))
            AxisTick()
            AxisValueLabel(format: format).foregroundStyle(Color.white.opacity(0.8))
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.cyan.opacity(0.2))
            AxisValueLabel().foregroundStyle(Color.white.opacity(0.8))
        }
    }

    private func legend(_ color: Color, _ text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            if dashed {
                Rectangle().fill(color).frame(width: 14, height: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            }
            Text(text)
        }
    }
}

// MARK: - Stats

struct StatsSection: View {
    @ObservedObject var appState: AppState
    let data: TrendsData
    let range: TrendsView.TimeRange

    var body: some View {
        VStack(spacing: 12) {
            StatCard(title: "Average per day", value: appState.formatVolume(data.averageOunces),
                     subtitle: "Across \(data.loggedDays) \(data.loggedDays == 1 ? "day" : "days") with entries", icon: "drop.fill")

            StatCard(title: "Goal reached", value: "\(data.goalDays) of \(data.loggedDays) \(data.loggedDays == 1 ? "day" : "days")",
                     subtitle: "Goal: \(appState.formatVolume(appState.dailyGoal))", icon: "target")

            if let best = data.best {
                StatCard(title: "Highest day", value: appState.formatVolume(best.ounces),
                         subtitle: best.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), icon: "star.fill")
            }
            if let hour = data.peakHour {
                StatCard(title: "Most active time", value: hourLabel(hour), subtitle: "When you log most often", icon: "clock.fill")
            }
            if let weekday = data.bestWeekday, data.loggedDays >= 7 {
                StatCard(title: "Highest average weekday", value: weekday.name,
                         subtitle: "Average \(appState.formatVolume(weekday.average))", icon: "calendar")
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.cyan)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.cyan)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .liquidGlassBackground(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
