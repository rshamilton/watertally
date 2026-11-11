//
//  ModalViews.swift
//  Water Tally
//
//  Button editor, calendar and history sheets.
//

import SwiftUI

// MARK: - Add / edit button

struct ButtonFormSheet: View {
    enum Mode {
        case add
        case edit(HydrationButton)
    }

    @ObservedObject var appState: AppState
    let mode: Mode
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amountText: String
    @State private var colorHex: String
    @State private var showAmount: Bool
    @State private var errorText: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, amount }

    private let maxNameLength = 20

    init(appState: AppState, mode: Mode) {
        self.appState = appState
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _amountText = State(initialValue: "")
            _colorHex = State(initialValue: "#00A8CC")
            _showAmount = State(initialValue: true)
        case .edit(let button):
            _name = State(initialValue: button.name)
            _amountText = State(initialValue: button.isCustom ? "" : Volume.number(button.fluidOunces, metric: appState.useMetric))
            _colorHex = State(initialValue: button.color)
            _showAmount = State(initialValue: button.showAmount)
        }
    }

    private var editingButton: HydrationButton? {
        if case .edit(let button) = mode { return button }
        return nil
    }
    private var isCustomButton: Bool { editingButton?.isCustom ?? false }
    private var title: String { editingButton == nil ? "New Button" : "Edit Button" }
    private var accent: Color { Color(hex: colorHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    preview

                    field("Name\(isCustomButton ? " (optional)" : "")") {
                        TextField(isCustomButton ? "Custom" : "e.g. Glass", text: $name)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > maxNameLength { name = String(newValue.prefix(maxNameLength)) }
                            }
                    }

                    if !isCustomButton {
                        field("Amount (\(appState.currentUnitString))") {
                            TextField(appState.useMetric ? "e.g. 250" : "e.g. 8", text: $amountText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)
                                .onChange(of: amountText) { _, newValue in
                                    if let value = NumberInput.parse(newValue), value > appState.maxDisplayAmount {
                                        amountText = Volume.number(displayValue: appState.maxDisplayAmount, metric: appState.useMetric)
                                    }
                                }
                        }

                        Toggle("Show amount on button", isOn: $showAmount)
                            .tint(accent)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colour")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                            ForEach(Color.buttonColors) { option in
                                Button { colorHex = option.hex } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 44, height: 44)
                                        .padding(4)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: colorHex == option.hex ? 2.5 : 0))
                                }
                                .accessibilityLabel(option.name)
                                .accessibilityAddTraits(colorHex == option.hex ? .isSelected : [])
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText).font(.footnote).foregroundColor(.red)
                    }

                    Button("Save", action: save)
                        .buttonStyle(PrimaryButtonStyle(tint: accent))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.water)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }

    private var preview: some View {
        let previewButton = HydrationButton(
            name: name, fluidOunces: appState.convertFromDisplayUnit(NumberInput.parse(amountText) ?? 0), order: 0,
            color: colorHex, showAmount: showAmount, isCustom: isCustomButton
        )
        return Button {} label: {
            HydrationButtonLabel(appState: appState, button: previewButton)
                .frame(width: 160, height: 90)
        }
        .buttonStyle(TileButtonStyle(color: accent))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .padding(.top, 12)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 6)
            content()
                .font(.body)
                .foregroundColor(.white)
                .padding(14)
                .card(cornerRadius: 14)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let button = editingButton, button.isCustom {
            appState.updateButton(id: button.id, name: trimmedName.isEmpty ? "Custom" : trimmedName,
                                  fluidOunces: 0, color: colorHex, showAmount: false)
            dismiss()
            return
        }

        guard !trimmedName.isEmpty else { errorText = "Give the button a name."; return }
        guard let value = NumberInput.parse(amountText), value > 0 else {
            errorText = "Enter an amount greater than 0."
            return
        }
        let ounces = appState.convertFromDisplayUnit(value)
        guard ounces <= Limits.maxLogOunces else {
            errorText = "The maximum is \(appState.formatVolume(Limits.maxLogOunces))."
            return
        }

        if let button = editingButton {
            let duplicate = appState.buttons.contains {
                $0.id != button.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            }
            guard !duplicate else { errorText = "A button with that name already exists."; return }
            appState.updateButton(id: button.id, name: trimmedName, fluidOunces: ounces, color: colorHex, showAmount: showAmount)
        } else {
            guard appState.addButton(name: trimmedName, fluidOunces: ounces, color: colorHex, showAmount: showAmount) else {
                errorText = "A button with that name already exists, or you've reached the limit of \(appState.maxButtons)."
                return
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

struct AddButtonSheet: View {
    @ObservedObject var appState: AppState
    var body: some View { ButtonFormSheet(appState: appState, mode: .add) }
}

struct EditButtonSheet: View {
    let button: HydrationButton
    @ObservedObject var appState: AppState
    var body: some View { ButtonFormSheet(appState: appState, mode: .edit(button)) }
}

// MARK: - Calendar

struct CalendarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth = Date()

    private let calendar = Calendar.current

    private var canGoForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: visibleMonth) else { return false }
        return calendar.startOfDay(for: next) <= Date() ||
            calendar.isDate(next, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous month")

                    Spacer()
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Spacer()

                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoForward)
                    .opacity(canGoForward ? 1 : 0.3)
                    .accessibilityLabel("Next month")
                }
                .foregroundColor(.water)

                HStack(spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 50)
                        }
                    }
                }

                legend

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.water)
                }
            }
            .appScreen(themeColor: appState.themeColor)
        }
        .onAppear { visibleMonth = appState.selectedDate }
    }

    private func dayCell(_ date: Date) -> some View {
        let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
        let total = appState.totalFluidOunces(for: date)
        let selected = calendar.isDate(date, inSameDayAs: appState.selectedDate)
        return Button {
            appState.selectedDate = date
            dismiss()
        } label: {
            CalendarDayView(
                date: date,
                hasLogs: total > 0,
                isSelected: selected,
                isToday: calendar.isDateInToday(date),
                goalProgress: appState.goalProgress(for: date),
                goalMet: Limits.isGoalMet(total: total, goal: appState.dailyGoal)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.3 : 1)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(total > 0
            ? "\(appState.formatVolume(total))\(Limits.isGoalMet(total: total, goal: appState.dailyGoal) ? ", goal reached" : "")"
            : "No entries")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(.water, "Goal reached")
            legendItem(.water.opacity(0.4), "Some logged")
        }
        .font(.caption2)
        .foregroundColor(.white.opacity(0.7))
        .accessibilityHidden(true)
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private func changeMonth(_ value: Int) {
        if let month = calendar.date(byAdding: .month, value: value, to: visibleMonth) {
            visibleMonth = month
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: visibleMonth)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            days.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return days
    }
}

struct CalendarDayView: View {
    let date: Date
    let hasLogs: Bool
    let isSelected: Bool
    let isToday: Bool
    let goalProgress: Double
    let goalMet: Bool

    private var dotColor: Color { goalMet ? .water : .water.opacity(0.4) }

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                .foregroundColor(.white)
            Circle()
                .fill(hasLogs ? dotColor : .clear)
                .frame(width: 7, height: 7)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.water.opacity(0.25) : Color.white.opacity(hasLogs ? 0.05 : 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isToday ? Color.water.opacity(0.8) : .clear, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - History

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editingLog: WaterLog?

    var body: some View {
        NavigationStack {
            let logs = appState.logsForDate(appState.selectedDate)

            Group {
                if logs.isEmpty {
                    VStack(spacing: 14) {
                        Text("No entries")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        Text(appState.isToday(appState.selectedDate)
                             ? "Tap a button on the main screen to log your first drink."
                             : "Nothing was logged on this day.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(logs) { log in
                                HistoryLogRow(appState: appState, log: log)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingLog = log }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation { appState.deleteLog(id: log.id, date: log.timestamp) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button { editingLog = log } label: { Label("Edit", systemImage: "pencil") }
                                            .tint(.blue)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityHint("Double tap to edit. Swipe up or down for the delete action.")
                                    .accessibilityAction(named: "Delete") {
                                        appState.deleteLog(id: log.id, date: log.timestamp)
                                    }
                            }
                        } header: {
                            HStack {
                                Text("Total")
                                Spacer()
                                Text(appState.formatVolume(appState.totalFluidOunces(for: appState.selectedDate)))
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .textCase(nil)
                            .padding(.horizontal, 4)
                        }

                        Text("Tap an entry to edit it, or swipe to delete.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(appState.dateLabel(for: appState.selectedDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.water)
                }
            }
            .sheet(item: $editingLog) { log in
                EditLogView(appState: appState, log: log)
                    .presentationDetents([.medium])
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }
}

struct HistoryLogRow: View {
    @ObservedObject var appState: AppState
    let log: WaterLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.buttonName)
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    if appState.healthKitEnabled && log.syncedToHealthKit {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.white.opacity(0.45))
                            .font(.caption2)
                            .accessibilityLabel("Saved to Apple Health")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text(appState.formatVolume(log.fluidOunces))
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .padding(16)
        .card(cornerRadius: 16)
    }
}

// MARK: - Edit log

struct EditLogView: View {
    @ObservedObject var appState: AppState
    let log: WaterLog
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var errorText: String?
    @FocusState private var focused: Bool

    init(appState: AppState, log: WaterLog) {
        self.appState = appState
        self.log = log
        _amountText = State(initialValue: Volume.number(log.fluidOunces, metric: appState.useMetric))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text("Edit entry").font(.title2.bold()).foregroundColor(.white)
                    Text("\(log.buttonName) · \(log.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline).foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 150)
                        .padding(.vertical, 8)
                        .card(cornerRadius: 16)
                        .focused($focused)
                        .onChange(of: amountText) { _, newValue in
                            if let value = NumberInput.parse(newValue), value > appState.maxDisplayAmount {
                                amountText = Volume.number(displayValue: appState.maxDisplayAmount, metric: appState.useMetric)
                            }
                        }
                    Text(appState.currentUnitString)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                if let errorText { Text(errorText).font(.footnote).foregroundColor(.red) }

                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.water)
                }
            }
            .appScreen(themeColor: appState.themeColor)
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard let value = NumberInput.parse(amountText) else {
            errorText = "Enter an amount."
            return
        }
        let ounces = appState.convertFromDisplayUnit(value)
        guard ounces >= Limits.minLogOunces else {
            errorText = "Enter at least \(appState.formatVolume(Limits.minLogOunces))."
            return
        }
        guard ounces <= Limits.maxLogOunces else {
            errorText = "The maximum is \(appState.formatVolume(Limits.maxLogOunces))."
            return
        }
        appState.updateLog(id: log.id, newAmount: ounces, date: log.timestamp)
        dismiss()
    }
}
