//
//  ContentView.swift
//  audio_listen
//
//  Root view with tabs: Drill | Progress | Tuner | Settings
//

import SwiftUI

struct ContentView: View {
    private let container = AppDependencyContainer.shared
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false

    var body: some View {
        TabView {
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore
            )
            .id(touchMode)
            .tabItem { Label("Drill", systemImage: "guitars.fill") }

            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore
            )
            .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            TunerView(viewModel: container.makeTunerViewModel())
                .tabItem { Label("Tuner", systemImage: "tuningfork") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 560)
        #endif
    }
}

#Preview { ContentView() }
