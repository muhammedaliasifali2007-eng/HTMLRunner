//
//  LibraryListView.swift
//  HTML Runner — every captured HTML / text, with search.
//

import SwiftUI

struct LibraryListView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var query = ""
    @State private var selected: SharedHTMLItem?

    private var filtered: [SharedHTMLItem] {
        guard !query.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.previewText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { item in
                    Button { selected = item } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "Search titles and content")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("No HTML yet", systemImage: "tray")
                    } description: {
                        Text("Share a web page or HTML snippet from another app, or tap + on Home to paste one in.")
                    }
                }
            }
            .navigationTitle("Library")
            .sheet(item: $selected) { item in
                ViewerScreen(item: item)
            }
        }
    }

    private func row(_ item: SharedHTMLItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isRemoteOnly ? "globe" : "doc.richtext")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(item.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
