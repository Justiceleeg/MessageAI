//
//  FirestoreService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import Combine
import FirebaseFirestore
import OSLog

/// Service responsible for Firestore database operations
@MainActor
class FirestoreService: ObservableObject {
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "FirestoreService")
    
    // MARK: - User Profile Methods
    
    /// Creates a new user profile in Firestore
    /// - Parameters:
    ///   - userId: Unique user identifier (Firebase Auth UID)
    ///   - displayName: User's display name
    ///   - email: User's email address (optional)
    /// - Throws: FirestoreError if the operation fails
    func createUserProfile(userId: String, displayName: String, email: String?) async throws {
        logger.info("Creating user profile for userId: \(userId)")
        
        // Create User model
        let user = User(
            userId: userId,
            displayName: displayName,
            email: email,
            presence: .offline,
            lastSeen: Date()
        )
        
        // Convert to Firestore data
        let userData = user.toFirestoreData()
        
        do {
            // Write to Firestore users collection
            try await db.collection("users").document(userId).setData(userData)
            logger.info("User profile created successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to create user profile: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    /// Fetches a user profile from Firestore
    /// - Parameter userId: Unique user identifier
    /// - Returns: User model if found
    /// - Throws: FirestoreError if the operation fails
    func getUserProfile(userId: String) async throws -> User {
        logger.info("Fetching user profile for userId: \(userId)")
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard let user = User(document: document) else {
                logger.error("Failed to parse user document for userId: \(userId)")
                throw FirestoreError.invalidData
            }
            
            logger.info("User profile fetched successfully for userId: \(userId)")
            return user
            
        } catch {
            logger.error("Failed to fetch user profile: \(error.localizedDescription)")
            throw FirestoreError.readFailed(error.localizedDescription)
        }
    }
    
    /// Updates user presence status
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - presence: New presence status
    /// - Throws: FirestoreError if the operation fails
    func updateUserPresence(userId: String, presence: PresenceStatus) async throws {
        logger.info("Updating presence for userId: \(userId) to \(presence.rawValue)")
        
        let data: [String: Any] = [
            "presence": presence.rawValue,
            "lastSeen": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("users").document(userId).updateData(data)
            logger.info("Presence updated successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to update presence: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    /// Updates user profile information
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - displayName: New display name (optional)
    ///   - email: New email (optional)
    /// - Throws: FirestoreError if the operation fails
    func updateUserProfile(userId: String, displayName: String? = nil, email: String? = nil) async throws {
        logger.info("Updating user profile for userId: \(userId)")
        
        var data: [String: Any] = [:]
        
        if let displayName = displayName {
            data["displayName"] = displayName
        }
        
        if let email = email {
            data["email"] = email
        }
        
        guard !data.isEmpty else {
            logger.warning("No data to update for userId: \(userId)")
            return
        }
        
        do {
            try await db.collection("users").document(userId).updateData(data)
            logger.info("User profile updated successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to update user profile: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Conversation Methods
    
    /// Listen to conversations for a specific user with real-time updates
    /// - Parameter userId: The user's unique identifier
    /// - Returns: AsyncThrowingStream that emits conversation arrays as they update
    open func listenToConversations(userId: String) -> AsyncThrowingStream<[Conversation], Error> {
        logger.info("Starting to listen to conversations for userId: \(userId)")
        
        return AsyncThrowingStream { continuation in
            let listener = db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .order(by: "lastMessageTimestamp", descending: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else {
                        continuation.finish()
                        return
                    }
                    
                    if let error = error {
                        self.logger.error("Failed to listen to conversations: \(error.localizedDescription)")
                        continuation.finish(throwing: FirestoreError.readFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.logger.warning("No conversation documents found")
                        continuation.yield([])
                        return
                    }
                    
                    let conversations = documents.compactMap { doc -> Conversation? in
                        guard let conversation = Conversation(document: doc) else {
                            self.logger.warning("Failed to parse conversation document: \(doc.documentID)")
                            return nil
                        }
                        return conversation
                    }
                    
                    self.logger.info("Fetched \(conversations.count) conversations for userId: \(userId)")
                    continuation.yield(conversations)
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Fetch a user by their user ID
    /// - Parameter userId: The user's unique identifier
    /// - Returns: User model
    /// - Throws: FirestoreError if user not found or fetch fails
    open func fetchUser(userId: String) async throws -> User {
        logger.info("Fetching user for userId: \(userId)")
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists else {
                logger.error("User not found: \(userId)")
                throw FirestoreError.userNotFound
            }
            
            guard let user = User(document: document) else {
                logger.error("Failed to parse user document for userId: \(userId)")
                throw FirestoreError.invalidData
            }
            
            logger.info("User fetched successfully for userId: \(userId)")
            return user
            
        } catch let error as FirestoreError {
            throw error
        } catch {
            logger.error("Failed to fetch user: \(error.localizedDescription)")
            throw FirestoreError.readFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Message Methods
    
    /// Listen to messages in a conversation with real-time updates
    /// - Parameter conversationId: The conversation's unique identifier
    /// - Returns: AsyncThrowingStream that emits message arrays as they update (ordered chronologically)
    open func listenToMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error> {
        logger.info("Starting to listen to messages for conversationId: \(conversationId)")
        
        return AsyncThrowingStream { continuation in
            let listener = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "timestamp", descending: false)  // Oldest first (chronological)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else {
                        continuation.finish()
                        return
                    }
                    
                    if let error = error {
                        self.logger.error("Failed to listen to messages: \(error.localizedDescription)")
                        continuation.finish(throwing: FirestoreError.readFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.logger.warning("No message documents found for conversationId: \(conversationId)")
                        continuation.yield([])
                        return
                    }
                    
                    let messages = documents.compactMap { doc -> Message? in
                        guard let messageId = doc.data()["messageId"] as? String,
                              let senderId = doc.data()["senderId"] as? String,
                              let text = doc.data()["text"] as? String,
                              let timestamp = (doc.data()["timestamp"] as? Timestamp)?.dateValue(),
                              let status = doc.data()["status"] as? String else {
                            self.logger.warning("Failed to parse message document: \(doc.documentID)")
                            return nil
                        }
                        
                        return Message(
                            id: messageId,
                            messageId: messageId,
                            senderId: senderId,
                            text: text,
                            timestamp: timestamp,
                            status: status
                        )
                    }
                    
                    self.logger.info("Fetched \(messages.count) messages for conversationId: \(conversationId)")
                    continuation.yield(messages)
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Send a message in an existing conversation
    /// - Parameters:
    ///   - conversationId: The conversation's unique identifier
    ///   - senderId: The sender's user ID
    ///   - text: Message text content
    /// - Returns: The created Message
    /// - Throws: FirestoreError if the operation fails
    open func sendMessage(conversationId: String, senderId: String, text: String) async throws -> Message {
        logger.info("Sending message to conversationId: \(conversationId)")
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        
        let message = Message(
            id: messageId,
            messageId: messageId,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            status: "sent"
        )
        
        do {
            // Use batch write for atomicity
            let batch = db.batch()
            
            // Write message to sub-collection
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            let messageData: [String: Any] = [
                "messageId": messageId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "sent"
            ]
            batch.setData(messageData, forDocument: messageRef)
            
            // Update parent conversation document
            let conversationRef = db.collection("conversations").document(conversationId)
            let conversationData: [String: Any] = [
                "lastMessageText": text,
                "lastMessageTimestamp": FieldValue.serverTimestamp()
            ]
            batch.updateData(conversationData, forDocument: conversationRef)
            
            // Commit batch
            try await batch.commit()
            
            logger.info("Message sent successfully: \(messageId)")
            return message
            
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    /// Create a new conversation with the first message atomically (Story 2.0 - Lazy Creation)
    /// - Parameters:
    ///   - participants: Array of user IDs (should be [currentUserId, otherUserId])
    ///   - senderId: The sender's user ID
    ///   - text: First message text content
    /// - Returns: Tuple containing the created conversation ID and message
    /// - Throws: FirestoreError if the operation fails
    open func createConversationWithMessage(participants: [String], senderId: String, text: String) async throws -> (conversationId: String, message: Message) {
        logger.info("Creating new conversation with first message from senderId: \(senderId)")
        
        let conversationId = UUID().uuidString
        let messageId = UUID().uuidString
        let timestamp = Date()
        
        let message = Message(
            id: messageId,
            messageId: messageId,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            status: "sent"
        )
        
        do {
            // Use batch write for atomicity (conversation + first message created together)
            let batch = db.batch()
            
            // Create conversation document
            let conversationRef = db.collection("conversations").document(conversationId)
            let conversationData: [String: Any] = [
                "conversationId": conversationId,
                "participants": participants,
                "lastMessageText": text,
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(conversationData, forDocument: conversationRef)
            
            // Create first message in sub-collection
            let messageRef = conversationRef.collection("messages").document(messageId)
            let messageData: [String: Any] = [
                "messageId": messageId,
                "senderId": senderId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "sent"
            ]
            batch.setData(messageData, forDocument: messageRef)
            
            // Commit batch
            try await batch.commit()
            
            logger.info("Conversation and first message created successfully: \(conversationId)")
            return (conversationId, message)
            
        } catch {
            logger.error("Failed to create conversation with message: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
}

// MARK: - FirestoreError

/// Custom error type for Firestore operations
enum FirestoreError: LocalizedError {
    case writeFailed(String)
    case readFailed(String)
    case invalidData
    case documentNotFound
    case userNotFound
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .writeFailed(let message):
            return "Failed to write to database: \(message)"
        case .readFailed(let message):
            return "Failed to read from database: \(message)"
        case .invalidData:
            return "Invalid data format received from database."
        case .documentNotFound:
            return "The requested document was not found."
        case .userNotFound:
            return "User information unavailable."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}

