//
//  WordBuffer.swift
//  TypeAhead
//

import Foundation

class WordBuffer {
    private var snippets: [Snippet] = []
    private(set) var buffer = ""

    /// The character that resets the buffer and starts a new trigger (default: "@").
    var triggerPrefix: String = "@"

    /// When true, show all snippets immediately on trigger prefix alone.
    var showOnPrefix: Bool = false

    /// When true, also match snippets whose expansion contains the query.
    var searchExpansions: Bool = false

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
        buffer.append(character)
        // If buffer ends with the trigger prefix, reset to just the prefix
        if buffer.hasSuffix(triggerPrefix) {
            buffer = triggerPrefix
        }
        notifyMatches()
    }

    func reset() {
        buffer = ""
        onMatchesChanged?([], "")
    }

    // MARK: - Private

    private func snippetMatches(_ snippet: Snippet, query: String) -> Bool {
        if query.isEmpty { return true } // showOnPrefix case — show all
        let trigger = String(snippet.trigger.drop(while: { !$0.isLetter && !$0.isNumber }))
        if trigger.lowercased().hasPrefix(query.lowercased()) { return true }
        if searchExpansions && snippet.expansion.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    private func notifyMatches() {
        // Buffer must start with the prefix, and have at least one more character after it.
        guard buffer.hasPrefix(triggerPrefix) else { onMatchesChanged?([], ""); return }
        let query = String(buffer.dropFirst(triggerPrefix.count))
        guard !query.isEmpty || showOnPrefix else { onMatchesChanged?([], ""); return }

        let matches = snippets
            .filter { snippetMatches($0, query: query) }
            .sorted { $0.trigger == $1.trigger ? $0.name < $1.name : $0.trigger < $1.trigger }

        if !matches.isEmpty {
            print("[TypeAhead] Buffer: '\(buffer)' — \(matches.count) match(es): \(matches.map { "\($0.trigger)/\($0.displayName)" })")
        }

        onMatchesChanged?(matches, buffer)
    }
}
