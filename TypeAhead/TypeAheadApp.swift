//
//  TypeAheadApp.swift
//  TypeAhead
//

import SwiftUI

@main
struct TypeAheadApp: App {
    @StateObject private var appMonitor = AppMonitor()

    var body: some Scene {
        MenuBarExtra("TypeAhead", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}
