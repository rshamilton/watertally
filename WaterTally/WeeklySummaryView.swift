//
//  WeeklySummaryView.swift
//  Water Tally
//
//  A friendly recap shown once on Sundays.
//

import SwiftUI

struct WeeklySummaryView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let data = TrendsData(appState: appState, days: 7)
        let firstLog = appState.logs.keys.min() ?? appState.dateKey(for: Date())
        // Only count days since the user actually started, so a new user isn't "failing" days they never tracked.
        let countedDays = data.days.filter { appState.dateKey(for: $0.date) >= firstLog }
        let goalDays = countedDays.filter { Limits.isGoalMet(total: $0.ounces, goal: appState.dailyGoal) }.count
        let rate = countedDays.isEmpty ? 0 : Double(goalDays) / Double(countedDays.count) * 100
        let total = data.days.reduce(0) { $0 + $1.ounces }

        ZStack {
            AppBackground(themeColor: appState.themeColor)

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Your week")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text(weekRange(data))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 40)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        WeekBars(appState: appState, days: data.days)
                            .padding(16)
                            .card()

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            SummaryTile(title: "Total", value: appState.formatVolume(total))
                            SummaryTile(title: "Daily average",
                                        value: appState.formatVolume(total / Double(max(countedDays.count, 1))))
                            SummaryTile(title: "Goal reached", value: "\(goalDays) of \(countedDays.count) days")
                            SummaryTile(title: "Current streak",
                                        value: "\(appState.currentStreak) \(appState.currentStreak == 1 ? "day" : "days")")
                        }

                        Text(message(rate: rate))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }

                Button("Continue") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 480)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func weekRange(_ data: TrendsData) -> String {
        let start = data.start.formatted(.dateTime.month(.abbreviated).day())
        let end = data.end.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    private func message(rate: Double) -> String {
        switch rate {
        case 100...: return "A perfect week. Well done!"
        case 70..<100: return "A strong, consistent week."
        case 40..<70: return "Good progress. Keep building the habit."
        default: return "Every entry counts. Here's to a fresh week."
        }
    }
}

struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// Seven small bars, one per day, with the goal as a faint line.
struct WeekBars: View {
    @ObservedObject var appState: AppState
    let days: [TrendsData.Day]

    var body: some View {
        let peak = max(days.map(\.ounces).max() ?? 0, appState.dailyGoal) * 1.1
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let height = proxy.size.height
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Limits.isGoalMet(total: day.ounces, goal: appState.dailyGoal) ? Color.water : Color.water.opacity(0.45))
                                .frame(height: peak > 0 ? height * day.ounces / peak : 0)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.35))
                                .frame(height: 1)
                                .offset(y: -height * appState.dailyGoal / peak)
                        }
                    }
                    .frame(height: 96)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily amounts for the last seven days")
    }
}
