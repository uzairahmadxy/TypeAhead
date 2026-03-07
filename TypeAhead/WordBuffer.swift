//
//  WordBuffer.swift
//  TypeAhead
//

import Foundation

class WordBuffer {
    private let snippets: [String: String]
    private var buffer = ""

    init(snippets: [String: String]) {
        self.snippets = snippets
    }

    func process(character: Character) {
        let scalar = character.unicodeScalars.first!.value

        // Backspace (DEL U+007F or BS U+0008): trim the buffer
        if scalar == 127 || scalar == 8 {
            if !buffer.isEmpty { buffer.removeLast() }
            if !buffer.isEmpty { checkMatches() }
            return
        }

        // Control characters (tab, escape, return, etc.): reset
        if scalar < 32 {
            buffer = ""
            return
        }

        // Whitespace: reset
        if character.isWhitespace {
            buffer = ""
            return
        }

        // '@' starts a fresh word (acts as a word-boundary trigger)
        if character == "@" {
            buffer = "@"
            checkMatches()
            return
        }

        buffer.append(character)
        checkMatches()
    }

    private func checkMatches() {
        guard !buffer.isEmpty else { return }

        // Find snippet keys that start with the current buffer (prefix match)
        let prefixMatches = snippets.keys.filter { $0.hasPrefix(buffer) }

        if !prefixMatches.isEmpty {
            print("[TypeAhead] Buffer: '\(buffer)' — prefix matches: \(prefixMatches.sorted())")
        }

        // Exact match: the buffer IS a snippet key
        if let expansion = snippets[buffer] {
            print("[TypeAhead] ✅ Exact match: '\(buffer)' → '\(expansion)'")
        }
    }
}
