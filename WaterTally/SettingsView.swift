//
//  SettingsView.swift
//  Water Tally
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showGoal = false
    @State private var exportFormatDialog = false
    @State private var exportFile: ExportFile?
    @State private var isRestoring = false
    @State private var restoreResult: String?
    @State private var showDeleteDialog = false

    private struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var healthConnected: Bool {
        appState.healthKitEnabled && appState.healthKitManager.isAuthorized
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                goalAndUnits
                reminders
                health
                data
                statistics
                about
            }
            .scrollContentBackground(.hidden)
            .listRowSpacing(2)
            .onChange(of: appState.reminderStartHour) { _, start in
                if appState.reminderEndHour < start { appState.reminderEndHour = start }
                appState.saveReminderPreferences()
            }
            .onChange(of: appState.reminderEndHour) { _, end in
                if end < appState.reminderStartHour { appState.reminderStartHour = end }
                appState.saveReminderPreferences()
            }
            .onChange(of: appState.reminderIntervalHours) { _, _ in appState.saveReminderPreferences() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.water)
                }
            }
            .sheet(isPresented: $showGoal) { GoalSettingsView(appState: appState) }
            .sheet(item: $exportFile) { file in ShareSheet(url: file.url) }
            .confirmationDialog("Export format", isPresented: $exportFormatDialog, titleVisibility: .visible) {
                Button("CSV (spreadsheet)") { export(.csv) }
                Button("JSON") { export(.json) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete all data?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
                Button("Delete Data on This Device", role: .destructive) { wipe(includingHealth: false) }
                if healthConnected {
                    Button("Also Delete \(AppInfo.name) Entries in Apple Health", role: .destructive) { wipe(includingHealth: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your entries, buttons and settings from this device and can't be undone. Export first if you want a copy.")
            }
            .alert("Restore complete", isPresented: Binding(
                get: { restoreResult != nil }, set: { if !$0 { restoreResult = nil } }
            )) {
                Button("OK") { restoreResult = nil }
            } message: {
                Text(restoreResult ?? "")
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }

    // MARK: Sections

    private var goalAndUnits: some View {
        Section {
            Button { showGoal = true } label: {
                HStack {
                    Label("Daily goal", systemImage: "target").foregroundColor(.primary)
                    Spacer()
                    Text(appState.formatVolume(appState.dailyGoal)).foregroundColor(.white.opacity(0.6))
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(.secondary)
                }
            }

            Picker("Units", selection: $appState.useMetric) {
                Text("Ounces").tag(false)
                Text("Millilitres").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: appState.useMetric) { _, _ in appState.saveUnitPreference() }
        } header: {
            Text("Goal & units")
        } footer: {
            Text("Your goal is a personal target for tracking, not a medical recommendation.")
        }
        .listRowBackground(rowBackground)
    }

    private var reminders: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appState.remindersEnabled },
                set: { appState.setReminders(enabled: $0) }
            )) {
                Label("Drink reminders", systemImage: "bell.fill")
            }
            .tint(.water)

            if appState.remindersEnabled {
                Picker("From", selection: $appState.reminderStartHour) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                Picker("Until", selection: $appState.reminderEndHour) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                Picker("Every", selection: $appState.reminderIntervalHours) {
                    ForEach([1, 2, 3, 4], id: \.self) { Text($0 == 1 ? "hour" : "\($0) hours").tag($0) }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Reminders are scheduled on this device and pause for the day once you reach your goal.")
        }
        .listRowBackground(rowBackground)
    }

    private var health: some View {
        Section {
            Toggle(isOn: Binding(
                get: { healthConnected },
                set: { appState.setHealthKitEnabled($0) }
            )) {
                Label("Save to Apple Health", systemImage: "heart.text.square.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .tint(.pink)
            .disabled(!appState.healthKitManager.isAvailable)

            if healthConnected {
                HStack {
                    Label(appState.isSyncingHealthKit ? "Syncing…" : "Up to date", systemImage: appState.isSyncingHealthKit ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                        .foregroundColor(appState.isSyncingHealthKit ? .water : .goalGreen)
                    Spacer()
                    if appState.isSyncingHealthKit { ProgressView() }
                }

                Button {
                    isRestoring = true
                    appState.restoreFromHealthKit { result in
                        isRestoring = false
                        switch result {
                        case .success(let added):
                            restoreResult = added == 0
                                ? "Everything in Apple Health is already in \(AppInfo.name)."
                                : "Added \(added) \(added == 1 ? "entry" : "entries") from Apple Health."
                        case .failure(let error):
                            restoreResult = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        Label("Restore from Apple Health", systemImage: "arrow.down.circle")
                            .foregroundColor(.primary)
                        Spacer()
                        if isRestoring { ProgressView() }
                    }
                }
                .disabled(isRestoring)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text(appState.healthKitManager.isAvailable
                 ? "When on, \(AppInfo.name) saves each entry to Apple Health and keeps edits and deletions in step. Only Water is accessed. Restore adds water entries from the past year that are missing here; it never deletes or overwrites anything."
                 : "Apple Health isn't available on this device.")
        }
        .listRowBackground(rowBackground)
    }

    private var data: some View {
        Section {
            Button { exportFormatDialog = true } label: {
                Label("Export my data", systemImage: "square.and.arrow.up").foregroundColor(.primary)
            }
            Button(role: .destructive) { showDeleteDialog = true } label: {
                Label("Delete all data", systemImage: "trash")
                    .foregroundColor(.red)
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Your data is stored only on this device. Uninstalling \(AppInfo.name) removes it.")
        }
        .listRowBackground(rowBackground)
    }

    private var statistics: some View {
        let allLogs = appState.logs.values.flatMap { $0 }
        return Section {
            row("Entries logged", "\(allLogs.count)")
            row("Days tracked", "\(appState.daysWithLogs().count)")
            row("Total logged", appState.formatVolume(allLogs.reduce(0) { $0 + $1.fluidOunces }))
            row("Current streak", "\(appState.currentStreak) \(appState.currentStreak == 1 ? "day" : "days")")
            row("Best streak", "\(appState.longestStreak) \(appState.longestStreak == 1 ? "day" : "days")")
        } header: {
            Text("Statistics")
        }
        .listRowBackground(rowBackground)
    }

    private var about: some View {
        Section {
            row("Version", version)
            Link(destination: AppLinks.privacy) { linkLabel("Privacy Policy", "hand.raised.fill") }
            Link(destination: AppLinks.terms) { linkLabel("Terms of Use", "doc.text.fill") }
            Link(destination: AppLinks.medical) { linkLabel("Medical Disclaimer", "cross.case.fill") }
            Link(destination: AppLinks.support) { linkLabel("Help & Support", "questionmark.circle.fill") }
            Link(destination: AppLinks.mailto) { linkLabel("Contact", "envelope.fill") }
        } header: {
            Text("About")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(LegalCopy.short)
                Text("\(LegalCopy.professional) \(LegalCopy.emergency)")
            }
            .padding(.top, 4)
        }
        .listRowBackground(rowBackground)
    }

    // MARK: Helpers

    private var rowBackground: some View { Color.cardFill }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.white.opacity(0.6))
        }
        .accessibilityElement(children: .combine)
    }

    private func linkLabel(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.35))
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private enum ExportFormat { case csv, json }

    private func export(_ format: ExportFormat) {
        let (text, name): (String?, String) = {
            switch format {
            case .csv: return (appState.exportDataAsCSV(), "\(AppInfo.name)-data.csv")
            case .json: return (appState.exportDataAsJSON(), "\(AppInfo.name)-data.json")
            }
        }()
        guard let text else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            exportFile = ExportFile(url: url)
        } catch {
            appState.errorMessage = (title: "Export Failed", message: "The file couldn't be created. \(error.localizedDescription)")
        }
    }

    private func wipe(includingHealth: Bool) {
        appState.deleteAllData(includingHealth: includingHealth) { dismiss() }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
