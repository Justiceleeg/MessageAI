//
//  NetworkMonitor.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//  Story 2.3: Offline Persistence & Optimistic UI
//

import Foundation
import Network
import Combine
import OSLog

/// Monitors network connectivity status using NWPathMonitor
@MainActor
final class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    /// True if device has active network connection
    @Published private(set) var isConnected: Bool = true
    
    /// Current connection type (wifi, cellular, etc.)
    @Published private(set) var connectionType: NWInterface.InterfaceType?
    
    /// True if connection is expensive (cellular data)
    @Published private(set) var isExpensive: Bool = false
    
    // MARK: - Private Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.jpw.message-ai.NetworkMonitor")
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "NetworkMonitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network status
    func startMonitoring() {
        logger.info("Starting network monitoring")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            Task { @MainActor in
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.connectionType = path.availableInterfaces.first?.type
                
                // Log connection changes
                if wasConnected != self.isConnected {
                    if self.isConnected {
                        self.logger.info("Network connected - Type: \(String(describing: self.connectionType))")
                    } else {
                        self.logger.warning("Network disconnected")
                    }
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network status
    nonisolated func stopMonitoring() {
        logger.info("Stopping network monitoring")
        monitor.cancel()
    }
    
    /// Check if currently connected to WiFi
    var isConnectedViaWiFi: Bool {
        return isConnected && connectionType == .wifi
    }
    
    /// Check if currently connected to cellular
    var isConnectedViaCellular: Bool {
        return isConnected && connectionType == .cellular
    }
}

