//
//  MenuBarView.swift
//  TypeAhead
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appMonitor: AppMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if !appMonitor.hasPermission {
                permissionBanner
                Divider()
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable TypeAhead", isOn: $appMonitor.isEnabled)
                    .toggleStyle(.switch)
                    .disabled(!appMonitor.hasPermission)

                Divider()

                Button("Quit TypeAhead") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 240)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility access required", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Button("Open System Settings…") {
                appMonitor.openAccessibilitySettings()
            }
            .font(.caption)

            Button("I've granted access — recheck") {
                appMonitor.recheckPermission()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
