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
    @State private var selection = 0

    var body: some View {
        #if os(iOS)
        screen(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .leading, spacing: 0) {
                NavRail(selection: $selection)
                    .padding(.leading, 2)
            }
        #else
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
        .frame(minWidth: 720, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private func screen(for index: Int) -> some View {
        switch index {
        case 0:
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore
            )
            .id(touchMode)
        case 1:
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore
            )
        case 2:
            TunerView(viewModel: container.makeTunerViewModel())
        default:
            SettingsView()
        }
    }
}

#if os(iOS)
private struct NavRail: View {
    @Binding var selection: Int

    private let items: [(label: String, icon: String)] = [
        ("Drill", "guitars.fill"),
        ("Progress", "chart.bar.fill"),
        ("Tuner", "tuningfork"),
        ("Settings", "gearshape.fill")
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Image(systemName: items[index].icon)
                        .font(.footnote)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(selection == index ? Color.accentColor : Color.secondary)
                        .background(selection == index ? Color.accentColor.opacity(0.18) : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[index].label)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 8, y: 2)
    }
}
#endif

#Preview { ContentView() }
