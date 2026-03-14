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

    func showFill(placeholder: String, typed: String, index: Int,
                  expansion: String, placeholders: [String], collected: [String],
                  near cursorRect: CGRect) {
        currentMatches = []
        matchHostingView = nil
        let view = FillView(placeholder: placeholder, typed: typed, index: index,
                            expansion: expansion, placeholders: placeholders, collected: collected)
        if let hv = fillHostingView {
            hv.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            fillHostingView = hv
            contentView = hv
        }
        let size = fillHostingView?.fittingSize ?? CGSize(width: 280, height: 80)
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
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame   // excludes menu bar / Dock
        let screenH = screen.frame.height       // full height for flipped-coord conversion

        let panelW = max(size.width, preferredWidth)
        let panelH = size.height

        // Convert flipped AX coords → screen coords (Y=0 at bottom)
        let cursorScreenBottom = screenH - cursorRect.maxY
        let cursorScreenTop    = screenH - cursorRect.minY

        // Prefer below; flip above if not enough room
        let belowY = cursorScreenBottom - 6 - panelH
        let aboveY = cursorScreenTop + 6
        let panelY = belowY >= screenFrame.minY ? belowY : aboveY

        // Clamp X so panel doesn't go off the right edge
        let maxX = screenFrame.maxX - panelW
        let panelX = min(cursorRect.minX, maxX)

        setFrame(NSRect(x: panelX, y: panelY, width: panelW, height: panelH), display: true)
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

            typeIcons(for: snippet)

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

    @ViewBuilder
    private func typeIcons(for snippet: Snippet) -> some View {
        HStack(spacing: 4) {
            if snippet.isKeystroke {
                Image(systemName: "command")
                    .font(.caption2)
                    .foregroundStyle(Color.purple.opacity(0.85))
            } else {
                if snippet.isShellCommand {
                    Image(systemName: "terminal")
                        .font(.caption2)
                        .foregroundStyle(Color.orange.opacity(0.85))
                }
                if snippet.hasPlaceholders {
                    Image(systemName: "curlybraces")
                        .font(.caption2)
                        .foregroundStyle(Color.cyan.opacity(0.85))
                }
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Fill View

struct FillView: View {
    let placeholder: String
    let typed: String
    let index: Int
    let expansion: String
    let placeholders: [String]
    let collected: [String]   // filled values for indices 0..<index

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Current placeholder input row
            HStack(spacing: 6) {
                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize()
                HStack(spacing: 0) {
                    Text(typed)
                        .foregroundStyle(Color.white)
                        .fixedSize()
                    Rectangle()
                        .frame(width: 1.5, height: 13)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                if placeholders.count > 1 {
                    Spacer()
                    Text("\(index + 1)/\(placeholders.count)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            // Live preview of the assembled expansion
            Divider().background(Color.white.opacity(0.12))
            previewText
                .font(.caption)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 260, maxWidth: 380)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .padding(4)
    }

    /// Builds a mixed-style AttributedString preview by walking the expansion template.
    private var previewText: Text {
        var attrStr = AttributedString()

        func segment(_ s: String, color: Color) -> AttributedString {
            var a = AttributedString(s)
            a.foregroundColor = color
            return a
        }

        var remaining = expansion[expansion.startIndex...]
        for (i, ph) in placeholders.enumerated() {
            let marker = "{\(ph)}"
            guard let range = remaining.range(of: marker) else { continue }
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                attrStr += segment(before, color: Color.white.opacity(0.55))
            }
            if i < index {
                attrStr += segment(collected[i], color: Color.white)
            } else if i == index {
                attrStr += segment(typed.isEmpty ? "_" : typed, color: Color.accentColor)
            } else {
                attrStr += segment(marker, color: Color.white.opacity(0.25))
            }
            remaining = remaining[range.upperBound...]
        }
        if !remaining.isEmpty {
            attrStr += segment(String(remaining), color: Color.white.opacity(0.55))
        }
        return Text(attrStr)
    }
}
