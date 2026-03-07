//
//  WordBuffer.swift
//  TypeAhead
//

import Foundation

class WordBuffer {
    private var snippets: [String: String]
    private(set) var buffer = ""

    var bufferLength: Int { buffer.count }

    /// Called on the main thread whenever the match list changes.
    /// Receives the sorted matches and the current buffer string.
    var onMatchesChanged: (([( key: String, value: String)], String) -> Void)?

    init(snippets: [String: String]) {
        self.snippets = snippets
    }

    func updateSnippets(_ snippets: [String: String]) {
        self.snippets = snippets
        reset()
    }

    func process(character: Character) {
        let scalar = character.unicodeScalars.first!.value

        // Skip our own injected Unicode characters (should already be filtered by
        // the event tap marker, but belt-and-suspenders).
        // Control characters reset the buffer.
        if scalar < 32 {
            reset()
            return
        }

        // Backspace (DEL U+007F) — trim one character
        if scalar == 127 {
            if !buffer.isEmpty { buffer.removeLast() }
            notifyMatches()
            return
        }

        // Whitespace — reset
        if character.isWhitespace {
            reset()
            return
        }

        // '@' is a word-boundary trigger: always starts a fresh word
        if character == "@" {
            buffer = "@"
            notifyMatches()
            return
        }

        buffer.append(character)
        notifyMatches()
    }

    func reset() {
        buffer = ""
        onMatchesChanged?([], "")
    }

    // MARK: - Private

    private func notifyMatches() {
        guard !buffer.isEmpty else {
            onMatchesChanged?([], "")
            return
        }

        let matches = snippets
            .filter { $0.key.hasPrefix(buffer) }
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }

        // Console logging (Phase 1 behaviour, still useful for debugging)
        if !matches.isEmpty {
            print("[TypeAhead] Buffer: '\(buffer)' — prefix matches: \(matches.map(\.key))")
        }
        if let expansion = snippets[buffer] {
            print("[TypeAhead] ✅ Exact match: '\(buffer)' → '\(expansion)'")
        }

        onMatchesChanged?(matches, buffer)
    }
}
