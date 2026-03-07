//
//  AppMonitor.swift
//  TypeAhead
//

import AppKit
import Combine

@MainActor
class AppMonitor: ObservableObject {

    @Published var isEnabled = false {
        didSet { isEnabled ? keyboardMonitor.start() : keyboardMonitor.stop() }
    }

    private let wordBuffer: WordBuffer
    private let keyboardMonitor: KeyboardMonitor
    private let suggestionPanel = SuggestionPanel()
    private let cursorTracker = CursorTracker()
    private let textInjector = TextInjector()

    init() {
        let snippets: [String: String] = [
            "@email": "uzair@gmail.com",
            "@addr":  "123 Fake St Montreal",
            "@name":  "Uzair Ahmad"
        ]
        let buffer = WordBuffer(snippets: snippets)
        let monitor = KeyboardMonitor(wordBuffer: buffer)
        self.wordBuffer = buffer
        self.keyboardMonitor = monitor

        setupCallbacks()
    }

    // MARK: - Wiring

    private func setupCallbacks() {
        wordBuffer.onMatchesChanged = { [weak self] matches, _ in
            self?.handleMatchesChanged(matches)
        }

        keyboardMonitor.isPopupVisible = { [weak self] in
            self?.suggestionPanel.isVisible ?? false
        }

        keyboardMonitor.onSpecialKey = { [weak self] key in
            self?.handleSpecialKey(key) ?? false
        }
    }

    // MARK: - Popup management

    private func handleMatchesChanged(_ matches: [(key: String, value: String)]) {
        if matches.isEmpty {
            suggestionPanel.hide()
        } else {
            let cursorRect = cursorTracker.getCursorRect()
            suggestionPanel.show(matches: matches, near: cursorRect)
        }
    }

    /// Returns true if the event should be consumed.
    private func handleSpecialKey(_ key: SpecialKey) -> Bool {
        switch key {
        case .tab, .returnKey:
            acceptSuggestion()
            return true
        case .escape:
            wordBuffer.reset()
            suggestionPanel.hide()
            return true
        case .arrowDown:
            suggestionPanel.selectNext()
            return true
        case .arrowUp:
            suggestionPanel.selectPrevious()
            return true
        }
    }

    private func acceptSuggestion() {
        guard let match = suggestionPanel.selectedMatch else { return }
        let prefixLen = wordBuffer.bufferLength
        wordBuffer.reset()
        suggestionPanel.hide()
        textInjector.inject(expansion: match.value, replacingPrefixOfLength: prefixLen)
    }
}
