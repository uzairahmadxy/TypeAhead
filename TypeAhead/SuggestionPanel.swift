//
//  SuggestionPanel.swift
//  TypeAhead
//

import AppKit
import SwiftUI

// MARK: - Panel

final class SuggestionPanel: NSPanel {

    private var hostingView: NSHostingView<SuggestionView>?
    private(set) var currentMatches: [Snippet] = []
    private(set) var selectedIndex: Int = 0

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Force dark appearance so the popup is always a dark HUD regardless
        // of the underlying window's color scheme.
        appearance = NSAppearance(named: .darkAqua)
    }

    // MARK: - Public API

    func show(matches: [Snippet], near cursorRect: CGRect) {
        guard !matches.isEmpty else { hide(); return }

        if matches.map(\.id) != currentMatches.map(\.id) {
            selectedIndex = 0
        }
        currentMatches = matches
        updateContent()

        let panelSize = hostingView?.fittingSize ?? CGSize(width: 320, height: 44)
        let screenH = NSScreen.main?.frame.height ?? 0
        let cursorBottomNSY = screenH - cursorRect.maxY
        let panelY = cursorBottomNSY - 6 - panelSize.height

        setFrame(NSRect(
            x: cursorRect.minX,
            y: panelY,
            width: max(panelSize.width, 260),
            height: panelSize.height
        ), display: true)

        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
        currentMatches = []
        selectedIndex = 0
    }

    func selectNext() {
        guard !currentMatches.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentMatches.count
        updateContent()
    }

    func selectPrevious() {
        guard !currentMatches.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + currentMatches.count) % currentMatches.count
        updateContent()
    }

    var selectedMatch: Snippet? {
        guard !currentMatches.isEmpty, selectedIndex < currentMatches.count else { return nil }
        return currentMatches[selectedIndex]
    }

    // MARK: - Private

    private func updateContent() {
        let view = SuggestionView(matches: currentMatches, selectedIndex: selectedIndex)
        if let hv = hostingView {
            hv.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hostingView = hv
            contentView = hv
        }
    }
}

// MARK: - SwiftUI View

struct SuggestionView: View {
    let matches: [Snippet]
    let selectedIndex: Int

    private static let bg = Color(red: 0.13, green: 0.13, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.offset) { index, snippet in
                row(snippet: snippet, index: index)
                if index < matches.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 8)
                }
            }
        }
        .background(Self.bg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(4)
    }

    @ViewBuilder
    private func row(snippet: Snippet, index: Int) -> some View {
        let selected = index == selectedIndex
        HStack(spacing: 6) {
            Text(snippet.displayName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.45))

            Text(snippet.expansion)
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if index == 0 {
                Text("⇥")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
