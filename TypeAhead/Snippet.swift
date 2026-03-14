//
//  Snippet.swift
//  TypeAhead
//

import Foundation

struct Snippet: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: String
    var name: String        // optional label shown in the popup; empty = use trigger
    var expansion: String
    /// When true, this snippet is excluded from the "show all on prefix" list.
    /// It only appears once the user has started typing its trigger explicitly.
    var requiresExplicitTrigger: Bool = false
    /// When true, the expansion is executed as a shell command and its stdout is inserted.
    var isShellCommand: Bool = false
    /// When true, {placeholder} tokens in the expansion are filled interactively before insertion.
    var hasPlaceholders: Bool = false
    /// When true, selecting this snippet fires a keyboard shortcut instead of inserting text.
    /// The shortcut key code and modifiers are stored below; `expansion` holds the display label.
    var isKeystroke: Bool = false
    var keystrokeKeyCode: Int = -1
    var keystrokeModifiers: Int = 0
    /// When this snippet was created — used for recency sorting.
    /// Defaults to .distantPast so snippets decoded without this field are detectable.
    var createdAt: Date = .distantPast

    init(id: UUID = UUID(), trigger: String, name: String = "", expansion: String, requiresExplicitTrigger: Bool = false) {
        self.id = id
        self.trigger = trigger
        self.name = name
        self.expansion = expansion
        self.requiresExplicitTrigger = requiresExplicitTrigger
        self.createdAt = Date()
    }

    /// The label shown in the suggestion popup.
    var displayName: String {
        name.isEmpty ? trigger : name
    }
}
