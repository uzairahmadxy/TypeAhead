//
//  WordBuffer.swift
//  TypeAhead
//

import Foundation

class WordBuffer {
    private var snippets: [Snippet] = []
    private(set) var buffer = ""

    /// The string that resets the buffer and starts a new trigger (default: "//").
    var triggerPrefix: String = "//"

    /// When true, show all snippets immediately on trigger prefix alone.
    var showOnPrefix: Bool = false

    /// When true, also match snippets whose expansion contains the query.
    var searchExpansions: Bool = false

    /// When true, sort popup results by most recently added instead of alphabetically.
    var sortByRecency: Bool = false

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
        if query.isEmpty {
            // showOnPrefix case — show all except snippets that require an explicit trigger
            return !snippet.requiresExplicitTrigger
        }
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

        let indexed = Array(snippets.enumerated())
        let matches = indexed
            .filter { snippetMatches($0.element, query: query) }
            .sorted { a, b in
                if sortByRecency {
                    if a.element.createdAt != b.element.createdAt {
                        return a.element.createdAt > b.element.createdAt
                    }
                    return a.offset < b.offset  // stable tiebreaker: preserve insertion order
                }
                let t0 = a.element.trigger, t1 = b.element.trigger
                if t0 != t1 { return t0.localizedCaseInsensitiveCompare(t1) == .orderedAscending }
                return a.element.name.localizedCaseInsensitiveCompare(b.element.name) == .orderedAscending
            }
            .map(\.element)

        if !matches.isEmpty {
            print("[TypeAhead] Buffer: '\(buffer)' — \(matches.count) match(es): \(matches.map { "\($0.trigger)/\($0.displayName)" })")
        }

        onMatchesChanged?(matches, buffer)
    }
}
