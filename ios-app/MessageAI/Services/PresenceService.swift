//
//  PresenceService.swift
//  MessageAI
//
//  Created by Dev Agent on 10/21/25.
//  Manages user presence tracking using Firebase Realtime Database
//

import FirebaseAuth
import FirebaseDatabase
import Foundation
import OSLog

/// Service for managing user presence (online/offline status) using Firebase Realtime Database
/// Uses RTDB instead of Firestore for automatic disconnect detection via onDisconnect()
class PresenceService {
    // MARK: - Properties
    
    // Lazy database reference - initialized on first use (after Firebase.configure())
    private lazy var database = Database.database().reference()
    private let logger = Logger(subsystem: "com.messageai", category: "Presence")
    
    /// Debounce interval to prevent rapid presence updates (3 seconds)
    private let debounceInterval: TimeInterval = 3.0
    
    /// Timestamp of last presence update for debouncing
    private var lastPresenceUpdate: Date?
    
    /// Timer for debouncing rapid app lifecycle transitions
    private var debounceTimer: Timer?
    
    // MARK: - Public Methods
    
    /// Set user online with automatic disconnect handling
    /// - Parameters:
    ///   - userId: The user ID to mark as online
    ///   - immediate: If true, bypasses debouncing for immediate update (default: false)
    /// - Note: Uses onDisconnect() to automatically set offline on crashes, force-quits, or network drops
    func goOnline(userId: String, immediate: Bool = false) {
        // Skip debouncing if immediate update requested
        if immediate {
            logger.debug("Immediate online update for user \(userId)")
            performGoOnline(userId: userId)
            return
        }
        
        // Debounce: If we just updated recently, schedule delayed update
        if let lastUpdate = lastPresenceUpdate,
           Date().timeIntervalSince(lastUpdate) < debounceInterval {
            logger.debug("Debouncing online update for user \(userId)")
            
            // Cancel existing debounce timer
            debounceTimer?.invalidate()
            
            // Schedule new debounced update
            debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
                self?.performGoOnline(userId: userId)
            }
            return
        }
        
        // Execute immediately if not debounced
        performGoOnline(userId: userId)
    }
    
    /// Set user offline (manual call, e.g., on app background)
    /// - Parameter userId: The user ID to mark as offline
    func goOffline(userId: String) {
        logger.info("Setting user \(userId) offline")
        lastPresenceUpdate = Date()
        
        // Cancel any pending debounced online updates
        debounceTimer?.invalidate()
        
        let presenceRef = database.child("users").child(userId).child("presence")
        
        presenceRef.setValue([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ]) { [weak self] error, _ in
            if let error = error {
                self?.logger.error("Error setting user offline: \(error.localizedDescription)")
            } else {
                self?.logger.debug("User \(userId) set to offline successfully")
            }
        }
    }
    
    /// Observe presence changes for a specific user
    /// - Parameters:
    ///   - userId: The user ID to observe
    ///   - completion: Callback with (isOnline, lastSeen) when presence changes
    /// - Returns: DatabaseHandle for cleanup (use with stopObservingPresence)
    func observePresence(userId: String, completion: @escaping (Bool, Date) -> Void) -> DatabaseHandle {
        logger.debug("Starting presence listener for user \(userId)")
        
        let presenceRef = database.child("users").child(userId).child("presence")
        
        let handle = presenceRef.observe(.value) { [weak self] snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                self?.logger.warning("Invalid presence data for user \(userId)")
                // Default to offline if data is invalid
                completion(false, Date())
                return
            }
            
            let isOnline = value["online"] as? Bool ?? false
            
            // Handle timestamp (RTDB returns milliseconds as number)
            let lastSeenMs = value["lastSeen"] as? Double ?? 0
            let lastSeen = Date(timeIntervalSince1970: lastSeenMs / 1000.0)
            
            self?.logger.debug("Presence update: \(userId) is \(isOnline ? "online" : "offline"), last seen \(lastSeen)")
            
            completion(isOnline, lastSeen)
        } withCancel: { [weak self] error in
            self?.logger.error("Presence listener error for user \(userId): \(error.localizedDescription)")
        }
        
        return handle
    }
    
    /// Stop observing presence for a specific user
    /// - Parameters:
    ///   - userId: The user ID to stop observing
    ///   - handle: The DatabaseHandle returned from observePresence
    func stopObservingPresence(userId: String, handle: DatabaseHandle) {
        logger.debug("Stopping presence listener for user \(userId)")
        
        let presenceRef = database.child("users").child(userId).child("presence")
        presenceRef.removeObserver(withHandle: handle)
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual go online operation (after debouncing)
    private func performGoOnline(userId: String) {
        logger.info("Setting user \(userId) online")
        lastPresenceUpdate = Date()
        
        let presenceRef = database.child("users").child(userId).child("presence")
        
        // Set user online with server timestamp
        presenceRef.setValue([
            "online": true,
            "lastSeen": ServerValue.timestamp()
        ]) { [weak self] error, _ in
            if let error = error {
                self?.logger.error("Error setting user online: \(error.localizedDescription)")
                return
            }
            
            self?.logger.debug("User \(userId) set to online successfully")
            
            // Set up automatic offline on disconnect (crashes, force-quits, network drops)
            presenceRef.onDisconnectSetValue([
                "online": false,
                "lastSeen": ServerValue.timestamp()
            ]) { disconnectError, _ in
                if let disconnectError = disconnectError {
                    self?.logger.error("Error setting onDisconnect handler: \(disconnectError.localizedDescription)")
                } else {
                    self?.logger.debug("onDisconnect handler set for user \(userId)")
                }
            }
        }
    }
}

