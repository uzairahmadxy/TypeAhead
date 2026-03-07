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
    @FocusState private var focus: FocusField?

    enum FocusField { case trigger, name, expansion }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            snippetList
            Divider()
            addRow
            Divider()
            settingsRow
        }
        .frame(minWidth: 620, minHeight: 280)
    }

    // MARK: - Subviews

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
        if store.snippets.isEmpty {
            Spacer()
            Text("No snippets yet — add one below.")
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            List {
                ForEach($store.snippets) { $snippet in
                    snippetRow(snippet: $snippet)
                }
                .onDelete { store.delete(at: $0) }
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

            TextField("name (optional)", text: snippet.name)
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
            TextField("@trigger", text: $newTrigger)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120)
                .focused($focus, equals: .trigger)
                .onSubmit { focus = .name }

            TextField("name (optional)", text: $newName)
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
                .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty || newExpansion.isEmpty)
        }
        .padding(12)
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

