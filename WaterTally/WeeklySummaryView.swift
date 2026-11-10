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
            AppBackground(themeColor: appState.themeColor, diagonal: true)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 10)
                    Text("Your week")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("The last 7 days")
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
                .padding(.top, 36)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        SummaryCard(icon: "drop.fill", color: .cyan, title: "Total", value: appState.formatVolume(total),
                                    subtitle: "Logged this week")
                        SummaryCard(icon: "chart.bar.fill", color: .blue, title: "Daily average",
                                    value: appState.formatVolume(total / Double(max(countedDays.count, 1))),
                                    subtitle: "Per day tracked")
                        SummaryCard(icon: rate >= 100 ? "star.fill" : "target", color: rate >= 100 ? .yellow : .orange,
                                    title: "Goal reached", value: "\(goalDays) of \(countedDays.count) days",
                                    subtitle: rate >= 100 ? "Every day!" : "\(Int(rate.rounded()))% of days")
                        SummaryCard(icon: "flame.fill", color: .orange, title: "Current streak",
                                    value: "\(appState.currentStreak) \(appState.currentStreak == 1 ? "day" : "days")",
                                    subtitle: appState.currentStreak > 0 ? "Keep it going" : "Start a new one today")
                        if let best = data.best {
                            SummaryCard(icon: "trophy.fill", color: .yellow, title: "Best day",
                                        value: appState.formatVolume(best.ounces),
                                        subtitle: best.date.formatted(.dateTime.weekday(.wide)))
                        }
                        Text(message(rate: rate))
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(18)
                            .frame(maxWidth: .infinity)
                            .liquidGlassBackground(cornerRadius: 16)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }

                Button("Continue") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 480)
            }
        }
        .preferredColorScheme(.dark)
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

struct SummaryCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.footnote).foregroundColor(.white.opacity(0.7))
                Text(value).font(.title3.bold()).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.cyan.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .liquidGlassBackground(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
