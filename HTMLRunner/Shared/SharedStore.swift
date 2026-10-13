//
//  SharedStore.swift
//  HTML Runner
//
//  Persistence for the HTML library. The Share Extension writes here and the
//  app reads here, through an App Group container.
//
//  ⚠️ ONE THING TO CHANGE: `appGroupID` below must match the App Group you
//  enable for BOTH targets in Xcode (Signing & Capabilities → App Groups).
//  If you use your own bundle prefix, change it in the two .entitlements files
//  as well.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum SharedStore {

    /// ⬇️ Change to `group.<your-bundle-id>` and keep the entitlements in sync.
    static let appGroupID = "group.com.example.htmlrunner"

    /// Custom URL scheme (registered in the app's Info.plist).
    static let urlScheme = "htmlrunner"

    private static let fileName = "html-library.json"

    // MARK: - Locations

    /// The App Group container (shared by app + extension). `nil` when the
    /// capability is missing / misconfigured — we degrade instead of crashing.
    static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Fallback used by the app only (its own Documents folder).
    static var localFileURL: URL? {
        guard let docs = try? FileManager.default.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true) else { return nil }
        return docs.appendingPathComponent(fileName)
    }

    /// Where the library lives, preferring the shared container.
    static var storeURL: URL? {
        if let group = groupContainerURL {
            return group.appendingPathComponent(fileName)
        }
        return localFileURL
    }

    /// True when the app/extension can talk to each other through App Groups.
    static var isSharingAvailable: Bool { groupContainerURL != nil }

    // MARK: - Read / write

    static func load() -> [SharedHTMLItem] {
        var items: [SharedHTMLItem] = []
        if let url = storeURL, let data = try? Data(contentsOf: url) {
            items = (try? JSONDecoder().decode([SharedHTMLItem].self, from: data)) ?? []
        }
        // Also merge anything another target may have left in its own sandbox.
        if let local = localFileURL, storeURL != local, let data = try? Data(contentsOf: local) {
            let extra = (try? JSONDecoder().decode([SharedHTMLItem].self, from: data)) ?? []
            items.append(contentsOf: extra.filter { candidate in
                !items.contains(where: { $0.id == candidate.id })
            })
        }
        return items.sorted { $0.date > $1.date }
    }

    @discardableResult
    static func save(_ items: [SharedHTMLItem]) -> Bool {
        guard let url = storeURL else { return false }
        do { return try write(items, to: url) }
        catch { return false }
    }

    private static func write(_ items: [SharedHTMLItem], to url: URL) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(items)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return true
    }

    /// Adds one item to the top of the library. Returns `false` when nothing
    /// could be persisted to the shared container (extension then falls back to
    /// the clipboard hand-off below).
    @discardableResult
    static func add(_ item: SharedHTMLItem) -> Bool {
        var items = load()
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        // Keep the inbox from growing without bound.
        if items.count > 300 { items = Array(items.prefix(300)) }
        return save(items)
    }

    static func delete(id: UUID) {
        save(load().filter { $0.id != id })
    }

    static func clear() {
        save([])
    }

    // MARK: - URL-scheme hand-off
    //
    // Fallback channel used when the App Group container isn't available, which
    // is the normal case for sideloaded builds re-signed with a personal Apple
    // ID — those lose the App Group entitlement. The extension packs the items
    // into htmlrunner://import?payload=<base64url>, the app decodes them.

    /// Stays well clear of iOS URL limits; larger shares can't use this path.
    static let maximumPayloadLength = 100_000

    static func importURL(for items: [SharedHTMLItem]) -> URL? {
        guard let data = try? JSONEncoder().encode(items) else { return nil }
        let payload = base64URL(data)
        guard payload.count <= maximumPayloadLength else { return nil }
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "payload", value: payload)]
        return components.url
    }

    static func items(fromImportURL url: URL) -> [SharedHTMLItem]? {
        guard url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "payload" })?.value,
              let data = data(base64URL: value),
              let items = try? JSONDecoder().decode([SharedHTMLItem].self, from: data)
        else { return nil }
        return items
    }

    // base64url keeps “+”, “/” and “=” out of the URL.

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func data(base64URL string: String) -> Data? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }

    // MARK: - Clipboard import (app target only)

    #if !APP_EXTENSION && canImport(UIKit)

    private static let pasteboardMarker = "HTMLRUNNER-ITEM\n"

    /// The app calls this on launch/foreground: it lets an item be built
    /// elsewhere, copied, and have it appear in the library. Extension targets
    /// never touch the pasteboard, which keeps them App-Store-safe.
    static func importFromPasteboard() -> [SharedHTMLItem] {
        guard let string = UIPasteboard.general.string,
              string.hasPrefix(pasteboardMarker) else { return [] }
        let json = String(string.dropFirst(pasteboardMarker.count))
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([SharedHTMLItem].self, from: data) else { return [] }
        UIPasteboard.general.items = []
        return items
    }

    /// Encodes an item in the marker format accepted by `importFromPasteboard`.
    static func encodeForPasteboard(_ item: SharedHTMLItem) -> String? {
        guard let data = try? JSONEncoder().encode([item]) else { return nil }
        return pasteboardMarker + String(decoding: data, as: UTF8.self)
    }
    #endif
}
