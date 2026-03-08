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
    /// When this snippet was created — used for recency sorting.
    var createdAt: Date = Date()

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
