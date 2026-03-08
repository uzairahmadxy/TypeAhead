//
//  SnippetStore.swift
//  TypeAhead
//

import Combine
import Foundation
import SwiftUI

@MainActor
class SnippetStore: ObservableObject {

    @Published var snippets: [Snippet] = [] {
        didSet { scheduleSnippetsSave() }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("TypeAhead")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("snippets.json")
        load()
    }

    // MARK: - Public API

    func add(trigger: String, name: String = "", expansion: String) {
        let t = trigger.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !expansion.isEmpty else { return }
        snippets.append(Snippet(trigger: t, name: name.trimmingCharacters(in: .whitespaces), expansion: expansion))
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
    }

    func delete(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        snippets.move(fromOffsets: source, toOffset: destination)
    }

    func importSnippets(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder().decode([Snippet].self, from: data)
        else { return }
        let existingIDs = Set(snippets.map(\.id))
        let newSnippets = imported.filter { !existingIDs.contains($0.id) }
        snippets.append(contentsOf: newSnippets)
    }

    func exportSnippets(to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(snippets) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = saved
        } else {
            snippets = Self.defaultSnippets
            save()
        }
    }

    private static let defaultSnippets: [Snippet] = [
        Snippet(
            trigger: "//email",
            name: "My Email",
            expansion: "myemail@domain.com",
            requiresExplicitTrigger: true
        ),
        Snippet(
            trigger: "//omw",
            name: "On My Way",
            expansion: "On My Way!"
        ),
    ]

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(snippets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Debounces saves so rapid inline edits don't hammer the disk.
    private func scheduleSnippetsSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }
}
