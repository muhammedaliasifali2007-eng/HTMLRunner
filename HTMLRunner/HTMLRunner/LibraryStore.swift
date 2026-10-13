//
//  LibraryStore.swift
//  HTML Runner
//
//  Single source of truth for the HTML library. Talks to `SharedStore`
//  (App Group) so items shared from other apps appear here automatically.
//

import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {

    @Published var items: [SharedHTMLItem] = []
    @Published var lastError: String?

    /// Item the UI should open right away (set by `htmlrunner://open?id=…`
    /// from the Share Extension).
    @Published var pendingOpen: SharedHTMLItem?

    private var refreshTimer: Timer?

    init() {
        items = SharedStore.load()
        importPasteboardHandoff()
        // While the app is in the foreground, the extension may write to the
        // shared container at any moment — poll quietly so the list stays live.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Data

    func refresh() {
        let loaded = SharedStore.load()
        if loaded != items { items = loaded }
        let imported = SharedStore.importFromPasteboard()
        if !imported.isEmpty {
            for item in imported { SharedStore.add(item) }
            items = SharedStore.load()
        }
    }

    private func importPasteboardHandoff() {
        let imported = SharedStore.importFromPasteboard()
        guard !imported.isEmpty else { return }
        for item in imported { SharedStore.add(item) }
        items = SharedStore.load()
    }

    // MARK: - Mutations

    func delete(_ item: SharedHTMLItem) {
        SharedStore.delete(id: item.id)
        refresh()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets { SharedStore.delete(id: items[index].id) }
        refresh()
    }

    func clearAll() {
        SharedStore.clear()
        refresh()
    }

    func addSnippet(title: String, html: String) {
        let item = SharedHTMLItem(title: title.isEmpty ? HTMLTools.title(from: html) : title,
                                  html: html,
                                  baseURLString: nil)
        SharedStore.add(item)
        refresh()
    }

    // MARK: - Deep links
    //   htmlrunner://open?id=<uuid>            item is already in the shared store
    //   htmlrunner://import?payload=<base64url> items arrive inside the URL itself

    /// Alias for `open(url:)`. Inside `.onOpenURL { url in ... }` the closure
    /// parameter shadows the `URL` type, so an explicit name reads better —
    /// both spellings are kept so either call site compiles.
    func openURL(_ url: URL) { open(url: url) }

    func open(url: URL) {
        guard url.scheme == SharedStore.urlScheme else { return }
        refresh()

        if url.host == "import", let incoming = SharedStore.items(fromImportURL: url) {
            for item in incoming { SharedStore.add(item) }
            items = SharedStore.load()
            let ids = Set(incoming.map(\.id))
            pendingOpen = items.first { ids.contains($0.id) } ?? items.first
            return
        }

        if url.host == "open",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
           let id = UUID(uuidString: idString),
           let match = items.first(where: { $0.id == id }) {
            pendingOpen = match
        } else if let newest = items.first {
            pendingOpen = newest
        }
    }
}
