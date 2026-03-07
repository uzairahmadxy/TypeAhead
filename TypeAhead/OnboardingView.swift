//
//  OnboardingView.swift
//  TypeAhead
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Environment(\.dismissWindow) var dismissWindow

    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false
    @State private var bothGranted = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("Welcome to TypeAhead")
                    .font(.title2.bold())
                Text("Two permissions are required for TypeAhead to monitor keypresses system-wide.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            // Permission rows
            VStack(spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    detail: "Allows TypeAhead to read cursor position.",
                    granted: accessibilityGranted,
                    action: {
                        KeyboardMonitor.requestAccessibilityPermission()
                    },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                permissionRow(
                    title: "Input Monitoring",
                    detail: "Allows TypeAhead to detect keypresses globally.",
                    granted: inputMonitoringGranted,
                    action: { CGRequestListenEventAccess() },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Footer
            Group {
                if bothGranted {
                    Label("All set — TypeAhead is ready.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.callout.bold())
                } else {
                    VStack(spacing: 8) {
                        Text("Grant both permissions above, then TypeAhead enables automatically.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Re-check Permissions") { checkPermissions() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .frame(width: 440)
        .onReceive(timer) { _ in checkPermissions() }
        .onAppear { checkPermissions() }
    }

    // MARK: - Permission row

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        action: (() -> Void)?,
        settingsURL: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(granted ? .green : .red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Open Settings") {
                    action?()
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Polling

    private func checkPermissions() {
        accessibilityGranted = KeyboardMonitor.isAccessibilityGranted()
        inputMonitoringGranted = KeyboardMonitor.isInputMonitoringGranted()

        if accessibilityGranted && inputMonitoringGranted && !bothGranted {
            bothGranted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismissWindow(id: "onboarding")
            }
        }
    }
}
