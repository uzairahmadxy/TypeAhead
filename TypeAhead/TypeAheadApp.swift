//
//  TypeAheadApp.swift
//  TypeAhead
//

import SwiftUI

@main
struct TypeAheadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appMonitor = AppMonitor()

    var body: some Scene {
        MenuBarExtra("TypeAhead", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance: terminate any older copies of this app
        let bundleID = Bundle.main.bundleIdentifier!
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        others.forEach { $0.terminate() }
    }
}
