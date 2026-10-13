//
//  HomeView.swift
//  HTML Runner — "Cards" home screen: quick captured HTML at a glance.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: LibraryStore
    @Binding var selection: ContentView.Tab
    @State private var selected: SharedHTMLItem?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(store.items.prefix(24)) { item in
                                Button { selected = item } label: {
                                    HTMLCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("HTML Runner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SnippetEditor() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selected) { item in
                ViewerScreen(item: item)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Send HTML to HTML Runner")
                .font(.title2.bold())
            Text("In any app — Safari, Mail, Messages, Files, Notes — tap **Share**, then choose **HTML Runner**. The page opens right here, and stays in your library.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                selection = .library
            } label: {
                Label("Open Library", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// A single HTML "card" in the grid: icon, title, teaser, metadata.
struct HTMLCard: View {
    let item: SharedHTMLItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.isRemoteOnly ? "globe" : "doc.richtext")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                Text(item.date, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(item.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(item.previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text(item.isRemoteOnly ? "Web page" : "\(item.characterCount.formatted()) chars")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Simple composer so you can paste HTML/text by hand too.
struct SnippetEditor: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body_ = "<h1>Hello</h1>\n<p>Write or paste HTML here.</p>"

    var body: some View {
        NavigationStack {
            Form {
                Section("Title (optional)") {
                    TextField("Untitled HTML", text: $title)
                }
                Section("HTML") {
                    TextEditor(text: $body_)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Button {
                        if let clipboard = UIPasteboard.general.string { body_ = clipboard }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                } footer: {
                    Text("HTML is rendered inside a WKWebView. Fragments and plain text are wrapped in a page automatically.")
                }
            }
            .navigationTitle("New Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addSnippet(title: title, html: body_)
                        dismiss()
                    }
                    .disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
