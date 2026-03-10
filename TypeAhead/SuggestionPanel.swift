//
//  SuggestionPanel.swift
//  TypeAhead
//

import AppKit
import SwiftUI

// MARK: - Shared styling

let panelBackground = Color(red: 0.13, green: 0.13, blue: 0.15)

// MARK: - Panel

final class SuggestionPanel: NSPanel {

    private var matchHostingView: NSHostingView<SuggestionView>?
    private var fillHostingView: NSHostingView<FillView>?
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
        fillHostingView = nil
        updateMatchContent()
        position(near: cursorRect, preferredWidth: 260)
        orderFront(nil)
    }

    func showFill(placeholder: String, typed: String, index: Int, total: Int, near cursorRect: CGRect) {
        currentMatches = []
        matchHostingView = nil
        let view = FillView(placeholder: placeholder, typed: typed, index: index, total: total)
        if let hv = fillHostingView {
            hv.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            fillHostingView = hv
            contentView = hv
        }
        let size = fillHostingView?.fittingSize ?? CGSize(width: 260, height: 60)
        position(near: cursorRect, preferredWidth: size.width)
        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
        currentMatches = []
        selectedIndex = 0
        fillHostingView = nil
    }

    func selectNext() {
        guard !currentMatches.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentMatches.count
        updateMatchContent()
    }

    func selectPrevious() {
        guard !currentMatches.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + currentMatches.count) % currentMatches.count
        updateMatchContent()
    }

    var selectedMatch: Snippet? {
        guard !currentMatches.isEmpty, selectedIndex < currentMatches.count else { return nil }
        return currentMatches[selectedIndex]
    }

    // MARK: - Private

    private func updateMatchContent() {
        let view = SuggestionView(matches: currentMatches, selectedIndex: selectedIndex)
        if let hv = matchHostingView {
            hv.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            matchHostingView = hv
            contentView = hv
        }
    }

    private func position(near cursorRect: CGRect, preferredWidth: CGFloat) {
        let size = contentView?.fittingSize ?? CGSize(width: preferredWidth, height: 44)
        let screenH = NSScreen.main?.frame.height ?? 0
        let panelY = screenH - cursorRect.maxY - 6 - size.height
        setFrame(NSRect(
            x: cursorRect.minX,
            y: panelY,
            width: max(size.width, preferredWidth),
            height: size.height
        ), display: true)
    }
}

// MARK: - SwiftUI View

struct SuggestionView: View {
    let matches: [Snippet]
    let selectedIndex: Int

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
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(4)
    }

    @ViewBuilder
    private func row(snippet: Snippet, index: Int) -> some View {
        let selected = index == selectedIndex
        HStack(alignment: .top, spacing: 6) {
            Text(snippet.displayName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .fixedSize()

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.top, 3)

            ScrollView(.vertical, showsIndicators: true) {
                Text(snippet.expansion)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 72) // ~4 lines

            if index == 0 {
                Text("⇥")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 1)
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

// MARK: - Fill View

struct FillView: View {
    let placeholder: String
    let typed: String
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(placeholder)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.5))
                .fixedSize()

            HStack(spacing: 0) {
                Text(typed.isEmpty ? "" : typed)
                    .foregroundStyle(Color.white)
                    .fixedSize()
                Rectangle()
                    .frame(width: 1.5, height: 14)
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            if total > 1 {
                Spacer()
                Text("\(index + 1)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 200)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(4)
    }
}
