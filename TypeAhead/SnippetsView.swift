//
//  SnippetsView.swift
//  TypeAhead
//

import SwiftUI

struct SnippetsView: View {
    @EnvironmentObject var store: SnippetStore
    @AppStorage("triggerPrefix") private var triggerPrefix: String = "@"
    @AppStorage("showOnPrefix") private var showOnPrefix: Bool = true
    @AppStorage("searchExpansions") private var searchExpansions: Bool = true

    @State private var newTrigger = ""
    @State private var newName = ""
    @State private var newExpansion = ""
    @State private var searchText = ""
    @FocusState private var focus: FocusField?
    @State private var showingImporter = false
    @State private var showingExporter = false

    enum FocusField { case trigger, name, expansion }

    private var filteredIndices: [Int] {
        guard !searchText.isEmpty else { return Array(store.snippets.indices) }
        let q = searchText.lowercased()
        return store.snippets.indices.filter { i in
            let s = store.snippets[i]
            return s.trigger.lowercased().contains(q)
                || s.name.lowercased().contains(q)
                || s.expansion.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            searchBar
            Divider()
            snippetList
            Divider()
            addRow
            Divider()
            settingsRow
        }
        .frame(minWidth: 620, minHeight: 280)
        .toolbar {
            ToolbarItemGroup {
                Button("Import…") { showingImporter = true }
                Button("Export…") { showingExporter = true }
                    .disabled(store.snippets.isEmpty)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.importSnippets(from: url)
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: SnippetsDocument(snippets: store.snippets),
            contentType: .json,
            defaultFilename: "snippets"
        ) { result in
            if case .success(let url) = result {
                store.exportSnippets(to: url)
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search snippets…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Trigger")
                .frame(width: 120, alignment: .leading)
                .padding(.leading, 16)
            Text("Name")
                .frame(width: 120, alignment: .leading)
            Text("Expansion")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 7)
        .background(.bar)
    }

    @ViewBuilder
    private var snippetList: some View {
        let indices = filteredIndices
        if store.snippets.isEmpty {
            Spacer()
            Text("No snippets yet — add one below.")
                .foregroundStyle(.secondary)
            Spacer()
        } else if indices.isEmpty {
            Spacer()
            Text("No results for \"\(searchText)\".")
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            List {
                ForEach(indices, id: \.self) { i in
                    snippetRow(snippet: $store.snippets[i])
                }
                .onDelete { offsets in
                    let realIndices = offsets.map { indices[$0] }
                    realIndices.sorted(by: >).forEach { store.delete(at: IndexSet(integer: $0)) }
                }
                .onMove(perform: searchText.isEmpty ? { store.move(from: $0, to: $1) } : nil)
            }
            .listStyle(.plain)
        }
    }

    private func snippetRow(snippet: Binding<Snippet>) -> some View {
        HStack(spacing: 10) {
            TextField("@trigger", text: snippet.trigger)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120)

            TextField("(optional)", text: snippet.name)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 120)

            Text("→")
                .foregroundStyle(.secondary)

            TextField("expansion", text: snippet.expansion)
                .textFieldStyle(.plain)

            Button {
                store.delete(snippet.wrappedValue)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.5)
            .help("Delete snippet")
        }
        .padding(.vertical, 3)
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.accent)
                .imageScale(.medium)

            TextField("trigger", text: $newTrigger)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120)
                .focused($focus, equals: .trigger)
                .onSubmit { focus = .name }

            TextField("(optional)", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .focused($focus, equals: .name)
                .onSubmit { focus = .expansion }

            Text("→")
                .foregroundStyle(.secondary)

            TextField("expansion text", text: $newExpansion)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: .expansion)
                .onSubmit { commitAdd() }

            Button("Add", action: commitAdd)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty || newExpansion.isEmpty)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.06))
    }

    private var settingsRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Text("Trigger prefix:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $triggerPrefix)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 56)
                    .multilineTextAlignment(.center)
            }
            Toggle("Show all on prefix", isOn: $showOnPrefix)
                .toggleStyle(.switch)
                .font(.caption)
                .controlSize(.small)
            Toggle("Search expansions", isOn: $searchExpansions)
                .toggleStyle(.switch)
                .font(.caption)
                .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func commitAdd() {
        store.add(trigger: newTrigger, name: newName, expansion: newExpansion)
        newTrigger = ""
        newName = ""
        newExpansion = ""
        focus = .trigger
    }
}

// MARK: - FileDocument for export

import UniformTypeIdentifiers

struct SnippetsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var snippets: [Snippet]

    init(snippets: [Snippet]) { self.snippets = snippets }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        snippets = try JSONDecoder().decode([Snippet].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snippets)
        return FileWrapper(regularFileWithContents: data)
    }
}

