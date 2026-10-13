//
//  SettingsScreen.swift
//  HTML Runner — status, diagnostics and "how to enable the share sheet".
//

import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Share Extension") {
                    LabeledContent("Status") {
                        if SharedStore.isSharingAvailable {
                            Label("Ready", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .labelStyle(.titleAndIcon)
                        } else {
                            Label("App Group missing", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    if !SharedStore.isSharingAvailable {
                        Text("Enable the **App Groups** capability for both the app and the extension targets, using “\(SharedStore.appGroupID)”, then reinstall. Without it, shares are handed over via the clipboard instead.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Sideloaded builds re-signed with a personal Apple ID usually lose the App Group entitlement. HTML Runner notices and hands shared items over inside the `htmlrunner://` link instead — that covers snippets and small pages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Not seeing HTML Runner in the share sheet? Tap **More** in the share sheet's app row, then **Edit**, and switch HTML Runner on. Sharing the *page* (not just the link) works best — in Safari use **Options → Web Page**.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Library") {
                    LabeledContent("Saved items", value: "\(store.items.count)")
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear library", systemImage: "trash")
                    }
                    .disabled(store.items.isEmpty)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("HTML Runner renders shared HTML locally with WKWebView. Remote pages keep their real origin; local HTML is loaded from an empty base so it cannot read your files. Pages can still load whatever they normally would from the network.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete every saved item?",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible) {
                Button("Clear library", role: .destructive) { store.clearAll() }
            }
        }
    }
}
