//
//  HTMLRunnerApp.swift
//  HTML Runner
//

import SwiftUI

@main
struct HTMLRunnerApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in store.open(url: url) }
        }
    }
}
