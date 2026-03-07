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
        MenuBarExtra("TA") {
            MenuBarView()
                .environmentObject(appMonitor)
        }
        .menuBarExtraStyle(.window)

        Window("Snippets — TypeAhead", id: "snippets") {
            SnippetsView()
                .environmentObject(appMonitor.snippetStore)
        }
        .defaultSize(width: 560, height: 380)
        .defaultPosition(.center)

        Window("Welcome to TypeAhead", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier!
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .forEach { $0.terminate() }
    }
}
