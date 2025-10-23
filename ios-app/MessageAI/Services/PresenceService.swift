//
//  PresenceService.swift
//  MessageAI
//
//  Created by Dev Agent on 10/21/25.
//  Manages user presence tracking using Firebase Realtime Database
//  Extended for typing indicators using Firestore
//

import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore
import Foundation
import OSLog
import Combine

/// Service for managing user presence (online/offline status) using Firebase Realtime Database
/// Uses RTDB instead of Firestore for automatic disconnect detection via onDisconnect()
/// Extended for typing indicators using Firestore
class PresenceService {
    // MARK: - Properties
    
    // Lazy database reference - initialized on first use (after Firebase.configure())
    private lazy var database = Database.database().reference()
    private lazy var firestore = Firestore.firestore()
    private let logger = Logger(subsystem: "com.messageai", category: "Presence")
    
    /// Debounce interval to prevent rapid presence updates (3 seconds)
    private let debounceInterval: TimeInterval = 3.0
    
    /// Timestamp of last presence update for debouncing
    private var lastPresenceUpdate: Date?
    
    /// Timer for debouncing rapid app lifecycle transitions
    private var debounceTimer: Timer?
    
    // Typing indicator properties
    private var typingTimers: [String: Timer] = [:]  // conversationId -> Timer
    private var lastTypingUpdate: [String: Date] = [:]  // conversationId -> Date
    private let typingThrottle: TimeInterval = 1.0  // Max 1 update/second
    private let typingInactivityTimeout: TimeInterval = 2.0  // Auto-stop after 2 seconds
    
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
    
    // MARK: - Typing Indicators
    
    /// Start typing indicator for a conversation
    /// - Parameter conversationId: The conversation ID
    func startTyping(in conversationId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            logger.warning("Cannot start typing: No authenticated user")
            return
        }
        
        // Throttle updates
        if let lastUpdate = lastTypingUpdate[conversationId],
           Date().timeIntervalSince(lastUpdate) < typingThrottle {
            logger.debug("Throttling typing update for conversation \(conversationId)")
            return
        }
        
        logger.debug("Starting typing indicator for user \(userId) in conversation \(conversationId)")
        
        // Update Firestore
        let presenceRef = firestore.collection("conversations")
            .document(conversationId)
            .collection("presence")
            .document(userId)
        
        presenceRef.setData([
            "userId": userId,
            "isTyping": true,
            "typingAt": FieldValue.serverTimestamp()
        ], merge: true) { [weak self] error in
            if let error = error {
                self?.logger.error("Error starting typing indicator: \(error.localizedDescription)")
            } else {
                self?.logger.debug("Typing indicator started successfully")
            }
        }
        
        lastTypingUpdate[conversationId] = Date()
        
        // Set up auto-stop timer (2 seconds of inactivity)
        typingTimers[conversationId]?.invalidate()
        typingTimers[conversationId] = Timer.scheduledTimer(
            withTimeInterval: typingInactivityTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.stopTyping(in: conversationId)
        }
    }
    
    /// Stop typing indicator for a conversation
    /// - Parameter conversationId: The conversation ID
    func stopTyping(in conversationId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        logger.debug("Stopping typing indicator for user \(userId) in conversation \(conversationId)")
        
        typingTimers[conversationId]?.invalidate()
        typingTimers[conversationId] = nil
        
        let presenceRef = firestore.collection("conversations")
            .document(conversationId)
            .collection("presence")
            .document(userId)
        
        presenceRef.setData([
            "isTyping": false
        ], merge: true) { [weak self] error in
            if let error = error {
                self?.logger.error("Error stopping typing indicator: \(error.localizedDescription)")
            } else {
                self?.logger.debug("Typing indicator stopped successfully")
            }
        }
    }
    
    /// Observe typing users in a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: A publisher that emits arrays of user IDs who are currently typing
    func observeTypingUsers(in conversationId: String) -> AnyPublisher<[String], Never> {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            logger.warning("Cannot observe typing: No authenticated user")
            return Just([]).eraseToAnyPublisher()
        }
        
        logger.debug("Starting typing listener for conversation \(conversationId)")
        
        let presenceRef = firestore.collection("conversations")
            .document(conversationId)
            .collection("presence")
        
        return presenceRef
            .whereField("isTyping", isEqualTo: true)
            .snapshotPublisher()
            .map { [weak self] snapshot in
                let typingUserIds = snapshot.documents.compactMap { doc -> String? in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          userId != currentUserId,
                          let isTyping = data["isTyping"] as? Bool,
                          isTyping == true else { return nil }
                    
                    // Check timestamp is recent (< 10 seconds)
                    if let typingAt = data["typingAt"] as? Timestamp {
                        let age = Date().timeIntervalSince(typingAt.dateValue())
                        if age > 10 {
                            self?.logger.debug("Filtering out stale typing indicator for user \(userId)")
                            return nil
                        }
                    }
                    
                    return userId
                }
                
                self?.logger.debug("Typing users in conversation \(conversationId): \(typingUserIds)")
                return typingUserIds
            }
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
    
    /// Stop all typing indicators (e.g., on app background)
    func stopAllTyping() {
        logger.info("Stopping all typing indicators")
        
        // Invalidate all timers
        typingTimers.values.forEach { $0.invalidate() }
        typingTimers.removeAll()
        
        // Stop typing in all conversations
        lastTypingUpdate.keys.forEach { conversationId in
            stopTyping(in: conversationId)
        }
        
        lastTypingUpdate.removeAll()
    }
}

// MARK: - Firestore Snapshot Publisher Extension
extension Query {
    func snapshotPublisher() -> AnyPublisher<QuerySnapshot, Error> {
        let subject = PassthroughSubject<QuerySnapshot, Error>()
        
        let listener = addSnapshotListener { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(error))
            } else if let snapshot = snapshot {
                subject.send(snapshot)
            }
        }
        
        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }
}

