//
//  audio_listenApp.swift
//  audio_listen
//
//  Created by Yann Baglin-Bunod on 2/24/26.
//

import SwiftUI

@main
struct audio_listenApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
