//
//  EditModeView.swift
//  Water Tally
//
//  "Edit" mode: manage quick-log buttons, ordering, theme and goal.
//

import SwiftUI

struct EditModeView: View {
    @ObservedObject var appState: AppState
    @State private var showThemePicker = false
    @State private var showGoalSettings = false
    @State private var buttonToDelete: HydrationButton?

    private var atLimit: Bool { appState.buttons.count >= appState.maxButtons }

    var body: some View {
        VStack(spacing: 0) {
            if appState.buttons.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.cyan.opacity(0.6))
                    Text("No buttons yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tap Add below to create your first button.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.buttons) { button in
                        ButtonEditRow(button: button, appState: appState) {
                            buttonToDelete = button
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            controls
        }
        .sheet(isPresented: $appState.isRearrangeMode) { RearrangeView(appState: appState) }
        .sheet(isPresented: $showThemePicker) { ThemeColorPicker(appState: appState) }
        .sheet(isPresented: $showGoalSettings) { GoalSettingsView(appState: appState) }
        .confirmationDialog("Delete this button?", isPresented: Binding(
            get: { buttonToDelete != nil }, set: { if !$0 { buttonToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let button = buttonToDelete {
                    withAnimation { appState.deleteButton(id: button.id) }
                }
                buttonToDelete = nil
            }
            Button("Cancel", role: .cancel) { buttonToDelete = nil }
        } message: {
            Text("\"\(buttonToDelete?.name ?? "")\" will be removed. Entries you've already logged are not affected.")
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                control("Add", icon: "plus.circle.fill", disabled: atLimit) { appState.showAddButtonModal = true }
                control("Order", icon: "arrow.up.arrow.down", disabled: appState.buttons.count < 2) { appState.isRearrangeMode = true }
                control("Theme", icon: "paintpalette.fill") { showThemePicker = true }
                control("Goal", icon: "target") { showGoalSettings = true }
            }

            Toggle(isOn: Binding(
                get: { appState.hasCustomButton() },
                set: { appState.setCustomButton(enabled: $0) }
            )) {
                Label("Custom amount button", systemImage: "keyboard")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
            .tint(.cyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .liquidGlassBackground(cornerRadius: 14)
            .disabled(atLimit && !appState.hasCustomButton())
            .opacity(atLimit && !appState.hasCustomButton() ? 0.5 : 1)

            if atLimit {
                Text("You've reached the limit of \(appState.maxButtons) buttons.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func control(_ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .liquidGlassBackground(cornerRadius: 16)
        }
        .buttonStyle(FluidButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

// MARK: - Row

struct ButtonEditRow: View {
    let button: HydrationButton
    @ObservedObject var appState: AppState
    let onDelete: () -> Void
    @State private var showEdit = false

    var body: some View {
        Button { showEdit = true } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: button.color))
                    .frame(width: 16, height: 16)
                    .shadow(color: Color(hex: button.color).opacity(0.7), radius: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(button.name.isEmpty ? "Custom" : button.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(button.isCustom ? "Asks for an amount" : appState.formatVolume(button.fluidOunces))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "pencil")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(height: 68)
            .liquidGlassBackground(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .accessibilityAction(named: "Delete", onDelete)
        .accessibilityHint("Double tap to edit")
        .sheet(isPresented: $showEdit) { EditButtonSheet(button: button, appState: appState) }
    }
}

// MARK: - Rearrange

struct RearrangeView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.buttons) { button in
                    HStack(spacing: 14) {
                        Circle().fill(Color(hex: button.color)).frame(width: 14, height: 14)
                        Text(button.name.isEmpty ? "Custom" : button.name)
                            .foregroundColor(.white)
                        Spacer()
                        Text(button.isCustom ? "Custom" : appState.formatVolume(button.fluidOunces))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .onMove { appState.moveButton(from: $0, to: $1) }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Buttons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyan)
                }
            }
            .appScreen(themeColor: appState.themeColor)
        }
    }
}

// MARK: - Theme

struct ThemeColorPicker: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String

    init(appState: AppState) {
        self.appState = appState
        _selected = State(initialValue: appState.themeColor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    Text("Pick the tint used for backgrounds throughout the app.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                        ForEach(Color.themeColors, id: \.0) { hex, color in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selected = hex }
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 64, height: 64)
                                    .overlay(Circle().stroke(Color.white, lineWidth: selected == hex ? 4 : 0))
                                    .overlay(Image(systemName: "checkmark").fontWeight(.bold)
                                        .foregroundColor(.white).opacity(selected == hex ? 1 : 0))
                                    .scaleEffect(selected == hex ? 1.1 : 1)
                                    .shadow(color: color.opacity(0.6), radius: selected == hex ? 12 : 6)
                            }
                            .accessibilityLabel("Theme colour")
                            .accessibilityAddTraits(selected == hex ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 30)

                    Button("Apply") {
                        appState.setThemeColor(selected)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.cyan)
                }
            }
            .appScreen(themeColor: selected)
        }
        .presentationDetents([.medium, .large])
    }
}
