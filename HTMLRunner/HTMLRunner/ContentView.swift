//
//  ContentView.swift
//  HTML Runner
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, library, settings }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "square.grid.2x2") }
                .tag(Tab.home)

            LibraryListView()
                .tabItem { Label("Library", systemImage: "list.bullet.rectangle") }
                .tag(Tab.library)

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        // Opened via htmlrunner://open?id=… from the Share Extension, no matter
        // which tab is showing. Dismissing automatically clears `pendingOpen`.
        .sheet(item: $store.pendingOpen) { item in
            ViewerScreen(item: item)
        }
    }
}

#Preview {
    ContentView().environmentObject(LibraryStore())
}
