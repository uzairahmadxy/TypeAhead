//
//  MenuBarView.swift
//  TypeAhead
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appMonitor: AppMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable TypeAhead", isOn: $appMonitor.isEnabled)
                .toggleStyle(.switch)

            Divider()

            Button("Quit TypeAhead") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 220)
    }
}
