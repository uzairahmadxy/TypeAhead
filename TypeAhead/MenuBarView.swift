//
//  MenuBarView.swift
//  TypeAhead
//

import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @EnvironmentObject var appMonitor: AppMonitor
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Status row
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable TypeAhead", isOn: $appMonitor.isEnabled)
                    .toggleStyle(.switch)

                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)

                Button("Manage Snippets…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "snippets")
                }
                .buttonStyle(.plain)

                Divider()

                Button("Open Accessibility Settings…") {
                    appMonitor.openAccessibilitySettings()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

                Button("Open Input Monitoring Settings…") {
                    appMonitor.openInputMonitoringSettings()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

                Divider()

                Button("Quit TypeAhead") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 240)
        .onReceive(NotificationCenter.default.publisher(for: .openManageSnippets)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "snippets")
        }
        .onAppear { checkAndOpenOnboarding() }
        .onChange(of: appMonitor.tapActive) {
            if !appMonitor.tapActive && appMonitor.isEnabled {
                checkAndOpenOnboarding()
            }
        }
    }

    private func checkAndOpenOnboarding() {
        let needsOnboarding = !KeyboardMonitor.isAccessibilityGranted()
            || !KeyboardMonitor.isInputMonitoringGranted()
        if needsOnboarding {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "onboarding")
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                if enabled { try? SMAppService.mainApp.register() }
                else { try? SMAppService.mainApp.unregister() }
            }
        )
    }

    private var statusColor: Color {
        appMonitor.tapActive ? .green : (appMonitor.isEnabled ? .orange : .secondary)
    }

    private var statusText: String {
        if appMonitor.tapActive { return "Active" }
        if appMonitor.isEnabled { return "Tap failed — see console" }
        return "Inactive"
    }
}
