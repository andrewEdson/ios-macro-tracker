//
//  Macro_TrackerApp.swift
//  Macro Tracker
//

import SwiftUI
import FirebaseCore
import SwiftData

@main
struct Macro_TrackerApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var syncService: SyncService
    @StateObject private var barcodeAPIService = BarcodeAPIService()
    @StateObject private var networkMonitor = NetworkMonitor()

    init() {
        FirebaseApp.configure()
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        _syncService = StateObject(wrappedValue: SyncService(authService: auth))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MacroGoals.self,
            LogEntry.self,
            CachedFood.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService)
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(barcodeAPIService)
                .environmentObject(networkMonitor)
                .modelContainer(sharedModelContainer)
        }
    }
}
