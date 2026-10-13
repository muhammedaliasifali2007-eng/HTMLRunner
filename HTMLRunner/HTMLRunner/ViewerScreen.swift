//
//  ViewerScreen.swift
//  HTML Runner — the actual "run the HTML" screen.
//

import SwiftUI
import UIKit

struct ViewerScreen: View {
    @Environment(\.dismiss) private var dismiss
    let item: SharedHTMLItem

    @State private var reloadToken = UUID()
    @State private var showSource = false

    var body: some View {
        NavigationStack {
            HTMLRenderer(item: item)
                .id(reloadToken)                       // relaunch the web view on reload
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showSource) {
                    SourceView(item: item)
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                reloadToken = UUID()
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            if let url = item.baseURL {
                Link(destination: url) { Image(systemName: "safari") }
            }

            Menu {
                Button {
                    showSource = true
                } label: {
                    Label("View source", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                if let url = item.baseURL {
                    Button {
                        UIPasteboard.general.url = url
                    } label: {
                        Label("Copy page URL", systemImage: "link")
                    }
                }

                Button {
                    UIPasteboard.general.string = item.html
                } label: {
                    Label("Copy HTML", systemImage: "doc.on.doc")
                }
                .disabled(item.html.isEmpty)

                ShareLink(item: item.isRemoteOnly ? (item.baseURL?.absoluteString ?? "") : item.html) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

/// Raw source inspector for what is on screen.
struct SourceView: View {
    @Environment(\.dismiss) private var dismiss
    let item: SharedHTMLItem

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(item.html.isEmpty ? "No local HTML — this is a live web page." : item.html)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = item.html
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(item.html.isEmpty)
                }
            }
        }
    }
}
