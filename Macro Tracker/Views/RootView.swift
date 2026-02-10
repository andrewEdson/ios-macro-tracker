//
//  RootView.swift
//  Macro Tracker
//

import SwiftUI

struct RootView: View {
    @ObservedObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authService.isSignedIn {
                MainTabView()
                    .task {
                        await syncService.fullSync(modelContext: modelContext)
                    }
                    .onAppear {
                        networkMonitor.onReconnect = { [weak syncService] in
                            guard let syncService else { return }
                            Task {
                                await syncService.fullSync(modelContext: modelContext)
                            }
                        }
                    }
            } else {
                AuthView(authService: authService)
            }
        }
        .animation(.default, value: authService.isSignedIn)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
            AddTabView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(authService: AuthService())
    }
}
