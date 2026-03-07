//
//  WordBuffer.swift
//  TypeAhead
//

import Foundation

class WordBuffer {
    private var snippets: [Snippet] = []
    private(set) var buffer = ""

    var bufferLength: Int { buffer.count }

    /// Called on the main thread whenever the match list changes.
    var onMatchesChanged: (([Snippet], String) -> Void)?

    init(snippets: [Snippet] = []) {
        self.snippets = snippets
    }

    func updateSnippets(_ snippets: [Snippet]) {
        self.snippets = snippets
        reset()
    }

    func process(character: Character) {
        let scalar = character.unicodeScalars.first!.value

        if scalar < 32 {        // control characters
            reset(); return
        }
        if scalar == 127 {      // backspace
            if !buffer.isEmpty { buffer.removeLast() }
            notifyMatches(); return
        }
        if character.isWhitespace {
            reset(); return
        }
        if character == "@" {   // word-boundary trigger
            buffer = "@"
            notifyMatches(); return
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
        guard !buffer.isEmpty else { onMatchesChanged?([], ""); return }

        // A snippet matches if its trigger starts with what the user has typed so far.
        let matches = snippets
            .filter { $0.trigger.hasPrefix(buffer) }
            .sorted { $0.trigger == $1.trigger ? $0.name < $1.name : $0.trigger < $1.trigger }

        if !matches.isEmpty {
            print("[TypeAhead] Buffer: '\(buffer)' — \(matches.count) match(es): \(matches.map { "\($0.trigger)/\($0.displayName)" })")
        }

        onMatchesChanged?(matches, buffer)
    }
}
