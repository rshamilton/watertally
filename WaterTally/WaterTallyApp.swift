//
//  WaterTallyApp.swift
//  Water Tally
//

import SwiftUI

@main
struct WaterTallyApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appState.handleBecameActive() }
        }
    }
}
