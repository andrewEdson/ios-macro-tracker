//
//  NetworkMonitor.swift
//  Macro Tracker
//
//  Watches for network connectivity changes using NWPathMonitor.
//  When the device comes back online, triggers a full sync.
//

import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    /// Called on the main actor when the device transitions from offline → online.
    var onReconnect: (() -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                if !wasConnected && self.isConnected {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
