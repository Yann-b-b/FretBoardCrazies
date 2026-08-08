//
//  ContentView.swift
//  audio_listen
//
//  Root view over the destinations in ReleaseScope.shippingTabs.
//

import SwiftUI

struct ContentView: View {
    private let container = AppDependencyContainer.shared
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false
    @AppStorage(SelectedInstrumentStore.userDefaultsKey) private var selectedInstrumentId = "guitar"
    @State private var selection = ReleaseScope.shippingTabs[0]

    var body: some View {
        #if os(iOS)
        screen(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .leading, spacing: 0) {
                NavRail(selection: $selection)
                    .padding(.leading, 2)
            }
        #else
        TabView(selection: $selection) {
            ForEach(ReleaseScope.shippingTabs) { tab in
                screen(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        #endif
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .drill:
            DrillView(
                viewModel: container.makeDrillViewModel(),
                allowedStringsStore: container.allowedStringsStore,
                instrument: container.currentInstrument
            )
            .id("\(touchMode)-\(selectedInstrumentId)")
        case .chords:
            ChordProgressionView(
                session: container.makeProgressionSession(),
                instrument: Instruments.guitar,
                store: container.progressionSelectionStore
            )
        case .suggest:
            ChordSuggesterView(session: ChordSuggesterSession(), instrument: Instruments.guitar)
        case .progress:
            MasteryView(
                progressRepository: container.drillProgressRepository,
                dailyHistoryStore: container.dailyHistoryStore,
                instrument: container.currentInstrument
            )
            .id(selectedInstrumentId)
        case .tuner:
            TunerView(viewModel: container.makeTunerViewModel())
        case .settings:
            SettingsView()
        }
    }
}

#if os(iOS)
private struct NavRail: View {
    static let tapTargetSize: CGFloat = 44

    @Binding var selection: AppTab

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ReleaseScope.shippingTabs) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.footnote)
                        .frame(width: NavRail.tapTargetSize, height: NavRail.tapTargetSize)
                        .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                        .background(selection == tab ? Color.accentColor.opacity(0.18) : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 8, y: 2)
    }
}
#endif

#Preview { ContentView() }
