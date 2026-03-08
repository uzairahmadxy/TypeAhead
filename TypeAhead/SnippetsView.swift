//
//  SnippetsView.swift
//  TypeAhead
//

import SwiftUI

struct SnippetsView: View {
    @EnvironmentObject var store: SnippetStore
    @AppStorage("triggerPrefix") private var triggerPrefix: String = "//"
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
    enum SortKey { case trigger, name, expansion }
    enum ListOrder { case alphabetical, recency }

    @State private var sortKey: SortKey? = nil
    @State private var sortAscending = true
    @AppStorage("sortByRecency") private var sortByRecency: Bool = false

    private var listOrder: ListOrder { sortByRecency ? .recency : .alphabetical }

    private var displayedIndices: [Int] {
        // Filter
        var indices: [Int]
        if searchText.isEmpty {
            indices = Array(store.snippets.indices)
        } else {
            let q = searchText.lowercased()
            indices = store.snippets.indices.filter { i in
                let s = store.snippets[i]
                return s.trigger.lowercased().contains(q)
                    || s.name.lowercased().contains(q)
                    || s.expansion.lowercased().contains(q)
            }
        }
        // Column sort overrides the base list order
        if let key = sortKey {
            return indices.sorted {
                let a = store.snippets[$0]
                let b = store.snippets[$1]
                let lhs: String
                let rhs: String
                switch key {
                case .trigger:   lhs = a.trigger;   rhs = b.trigger
                case .name:      lhs = a.name;       rhs = b.name
                case .expansion: lhs = a.expansion;  rhs = b.expansion
                }
                return sortAscending ? lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                                     : lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
            }
        }
        // Base list order
        switch listOrder {
        case .alphabetical:
            return indices.sorted {
                store.snippets[$0].trigger.localizedCaseInsensitiveCompare(store.snippets[$1].trigger) == .orderedAscending
            }
        case .recency:
            return indices.sorted { store.snippets[$0].createdAt > store.snippets[$1].createdAt }
        }
    }

    private func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }

    private func sortIndicator(_ key: SortKey) -> String? {
        guard sortKey == key else { return nil }
        return sortAscending ? "chevron.up" : "chevron.down"
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            headerRow
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
            Spacer()
            // Order toggle: alphabetical ↔ recency
            HStack(spacing: 0) {
                orderToggleButton(icon: "textformat", order: .alphabetical, tooltip: "Sort A–Z by trigger")
                orderToggleButton(icon: "clock", order: .recency, tooltip: "Sort by most recently added")
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func orderToggleButton(icon: String, order: ListOrder, tooltip: String) -> some View {
        let isActive = listOrder == order
        return Button {
            sortByRecency = (order == .recency)
            sortKey = nil   // clear column sort so base order takes effect
        } label: {
            Image(systemName: icon)
                .frame(width: 26, height: 20)
                .foregroundStyle(isActive ? .primary : .secondary)
                .background(isActive ? Color.primary.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortHeaderButton("Trigger", key: .trigger)
                .frame(width: 120, alignment: .leading)
                .padding(.leading, 16)
            sortHeaderButton("Name", key: .name)
                .frame(width: 120, alignment: .leading)
            sortHeaderButton("Expansion", key: .expansion)
            Spacer()
            Text("Exact trigger")
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .center)
                .padding(.trailing, 34)
        }
        .font(.caption)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func sortHeaderButton(_ label: String, key: SortKey) -> some View {
        Button {
            toggleSort(key)
        } label: {
            HStack(spacing: 3) {
                Text(label)
                    .foregroundStyle(sortKey == key ? .primary : .secondary)
                if let icon = sortIndicator(key) {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var snippetList: some View {
        let indices = displayedIndices
        let canReorder = searchText.isEmpty && sortKey == nil
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
                .onMove(perform: canReorder ? { store.move(from: $0, to: $1) } : nil)
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

            TextField("", text: snippet.name)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 120)

            Text("→")
                .foregroundStyle(.secondary)

            TextEditor(text: snippet.expansion)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 20, maxHeight: 80)
                .padding(.vertical, -4)

            Button {
                snippet.requiresExplicitTrigger.wrappedValue.toggle()
            } label: {
                Image(systemName: snippet.requiresExplicitTrigger.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(snippet.requiresExplicitTrigger.wrappedValue ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .frame(width: 96)
            .help(snippet.requiresExplicitTrigger.wrappedValue
                ? "Only shown when trigger is typed explicitly"
                : "Shown in show-all list when prefix is typed")

            Button {
                snippet.requiresExplicitTrigger.wrappedValue.toggle()
            } label: {
                Image(systemName: snippet.requiresExplicitTrigger.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(snippet.requiresExplicitTrigger.wrappedValue ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .frame(width: 96)
            .help(snippet.requiresExplicitTrigger.wrappedValue
                ? "Only shown when trigger is typed explicitly"
                : "Shown in show-all list when prefix is typed")

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

            TextField("expansion text", text: $newExpansion, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($focus, equals: .expansion)

            Button(action: commitAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty || newExpansion.isEmpty)
            .help("Add snippet")
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

