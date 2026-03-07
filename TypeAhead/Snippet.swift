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

    init(id: UUID = UUID(), trigger: String, name: String = "", expansion: String) {
        self.id = id
        self.trigger = trigger
        self.name = name
        self.expansion = expansion
    }

    /// The label shown in the suggestion popup.
    var displayName: String {
        name.isEmpty ? trigger : name
    }
}
