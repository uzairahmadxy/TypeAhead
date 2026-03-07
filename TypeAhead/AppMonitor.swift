//
//  AppMonitor.swift
//  TypeAhead
//

import AppKit
import Combine

@MainActor
class AppMonitor: ObservableObject {

    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                keyboardMonitor.start()
            } else {
                keyboardMonitor.stop()
                suggestionPanel.hide()
                wordBuffer.reset()
            }
        }
    }

    /// True only when the CGEventTap is actually running.
    @Published var tapActive = false

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

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
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
        keyboardMonitor.onTapStateChanged = { [weak self] active in
            self?.tapActive = active
            // If tap failed to start, snap the toggle back off
            if !active { self?.isEnabled = false }
        }
    }

    // MARK: - Popup

    private func handleMatchesChanged(_ matches: [(key: String, value: String)]) {
        if matches.isEmpty {
            suggestionPanel.hide()
        } else {
            suggestionPanel.show(matches: matches, near: cursorTracker.getCursorRect())
        }
    }

    private func handleSpecialKey(_ key: SpecialKey) -> Bool {
        switch key {
        case .tab, .returnKey: acceptSuggestion(); return true
        case .escape:          wordBuffer.reset(); suggestionPanel.hide(); return true
        case .arrowDown:       suggestionPanel.selectNext(); return true
        case .arrowUp:         suggestionPanel.selectPrevious(); return true
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
