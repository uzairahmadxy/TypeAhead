//
//  SnippetStore.swift
//  TypeAhead
//

import Combine
import Foundation

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

    func add(trigger: String, expansion: String) {
        let t = trigger.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !expansion.isEmpty else { return }
        snippets.append(Snippet(trigger: t, expansion: expansion))
    }

    func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
    }

    func delete(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
    }

    var asDict: [String: String] {
        Dictionary(snippets.map { ($0.trigger, $0.expansion) },
                   uniquingKeysWith: { _, last in last })
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = saved
        } else {
            // Seed defaults on first launch
            snippets = [
                Snippet(trigger: "@email", expansion: "uzair@gmail.com"),
                Snippet(trigger: "@addr",  expansion: "123 Fake St Montreal"),
                Snippet(trigger: "@name",  expansion: "Uzair Ahmad"),
            ]
            save()
        }
    }

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
