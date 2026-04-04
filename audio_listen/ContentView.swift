//
//  ContentView.swift
//  audio_listen
//
//  Root view with tabs: Game | Tuner
//

import SwiftUI

struct ContentView: View {
    private let container = AppDependencyContainer.shared
    
    var body: some View {
        TabView {
            GameView(
                viewModel: container.makeGameViewModel(),
                allowedStringsStore: container.allowedStringsStore
            )
                .tabItem {
                    Label("Game", systemImage: "gamecontroller.fill")
                }
            TunerView(viewModel: container.makeTunerViewModel())
                .tabItem {
                    Label("Tuner", systemImage: "tuningfork")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
