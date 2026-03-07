//
//  SuggestionPanel.swift
//  TypeAhead
//

import AppKit
import SwiftUI

// MARK: - Panel

final class SuggestionPanel: NSPanel {

    private var hostingView: NSHostingView<SuggestionView>?
    private(set) var currentMatches: [(key: String, value: String)] = []
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
    }

    // MARK: - Public API

    /// Show the popup near cursorRect (top-left origin screen coordinates from AX API).
    func show(matches: [(key: String, value: String)], near cursorRect: CGRect) {
        guard !matches.isEmpty else { hide(); return }

        // Reset selection when match list changes
        if matches.map(\.key) != currentMatches.map(\.key) {
            selectedIndex = 0
        }
        currentMatches = matches

        updateContent()

        let panelSize = hostingView?.fittingSize ?? CGSize(width: 320, height: 44)

        // Convert cursor rect from AX top-left origin to NSWindow bottom-left origin
        let screenH = NSScreen.main?.frame.height ?? 0
        let cursorBottomNSY = screenH - cursorRect.maxY   // cursor bottom in NSWindow coords
        let panelY = cursorBottomNSY - 6 - panelSize.height

        setFrame(NSRect(
            x: cursorRect.minX,
            y: panelY,
            width: max(panelSize.width, 240),
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

    var selectedMatch: (key: String, value: String)? {
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
    let matches: [(key: String, value: String)]
    let selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.offset) { index, match in
                row(match: match, index: index)
                if index < matches.count - 1 {
                    Divider().padding(.horizontal, 8)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(4)   // room for shadow
    }

    @ViewBuilder
    private func row(match: (key: String, value: String), index: Int) -> some View {
        let selected = index == selectedIndex
        HStack(spacing: 6) {
            Text(match.key)
                .fontWeight(.semibold)
                .foregroundStyle(selected ? Color.white : Color.primary)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(selected ? Color.white.opacity(0.75) : Color.secondary)

            Text(match.value)
                .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if index == 0 {
                Text("⇥")
                    .font(.caption)
                    .foregroundStyle(selected ? Color.white.opacity(0.7) : Color.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
