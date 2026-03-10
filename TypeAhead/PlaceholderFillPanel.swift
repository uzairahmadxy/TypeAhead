//
//  PlaceholderFillPanel.swift
//  TypeAhead
//

import AppKit
import SwiftUI

@MainActor
class PlaceholderFillPanel {
    private var panel: NSPanel?

    func show(snippetName: String,
              placeholders: [String],
              near rect: CGRect,
              onComplete: @escaping ([String]) -> Void) {
        hide()

        let rootView = PlaceholderFillView(
            snippetName: snippetName,
            placeholders: placeholders,
            onComplete: { [weak self] values in
                self?.hide()
                onComplete(values)
            },
            onCancel: { [weak self] in self?.hide() }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = .preferredContentSize

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.backgroundColor = NSColor.windowBackgroundColor
        p.contentView = hosting
        p.hasShadow = true
        p.level = .popUpMenu

        let size = hosting.fittingSize
        let origin = NSPoint(x: rect.minX, y: rect.minY - size.height - 6)
        p.setFrameOrigin(origin)

        self.panel = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Fill View

private struct PlaceholderFillView: View {
    let snippetName: String
    let placeholders: [String]
    let onComplete: ([String]) -> Void
    let onCancel: () -> Void

    @State private var currentIndex = 0
    @State private var currentValue = ""
    @State private var collected: [String] = []
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snippetName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("\(placeholders[currentIndex]):")
                    .font(.body.weight(.medium))
                    .fixedSize()
                TextField("", text: $currentValue)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(advance)
            }

            if placeholders.count > 1 {
                Text("\(currentIndex + 1) of \(placeholders.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(minWidth: 260)
        .onAppear {
            collected = Array(repeating: "", count: placeholders.count)
            focused = true
        }
        .background {
            Button("") { onCancel() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        }
    }

    private func advance() {
        collected[currentIndex] = currentValue
        currentValue = ""
        if currentIndex + 1 < placeholders.count {
            currentIndex += 1
            focused = true
        } else {
            onComplete(collected)
        }
    }
}
