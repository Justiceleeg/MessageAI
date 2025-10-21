//
//  OfflineMessageQueue.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//  Story 2.3: Offline Persistence & Optimistic UI
//

import Foundation
import Combine
import OSLog

/// Manages queue of messages to be sent when offline
@MainActor
final class OfflineMessageQueue: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OfflineMessageQueue()
    
    // MARK: - Published Properties
    
    @Published private(set) var queuedMessages: [QueuedMessage] = []
    
    // MARK: - Private Properties
    
    private let storage = UserDefaults.standard
    private let storageKey = "com.jpw.message-ai.offlineMessageQueue"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "OfflineMessageQueue")
    private let maxRetryAttempts = 3
    
    // MARK: - Queued Message Model
    
    struct QueuedMessage: Codable, Identifiable {
        let id: String
        let messageId: String
        let conversationId: String
        let senderId: String
        let text: String
        let timestamp: Date
        var retryCount: Int = 0
        
        init(messageId: String, conversationId: String, senderId: String, text: String, timestamp: Date, retryCount: Int = 0) {
            self.id = messageId  // Use messageId as id for Identifiable
            self.messageId = messageId
            self.conversationId = conversationId
            self.senderId = senderId
            self.text = text
            self.timestamp = timestamp
            self.retryCount = retryCount
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Queue Management
    
    /// Add a message to the offline queue
    func enqueue(_ message: QueuedMessage) {
        logger.info("Enqueuing message: \(message.messageId)")
        queuedMessages.append(message)
        saveToStorage()
    }
    
    /// Remove and return the next message from the queue (FIFO)
    func dequeue() -> QueuedMessage? {
        guard !queuedMessages.isEmpty else {
            logger.info("Queue is empty, nothing to dequeue")
            return nil
        }
        
        let message = queuedMessages.removeFirst()
        saveToStorage()
        logger.info("Dequeued message: \(message.messageId)")
        return message
    }
    
    /// Remove a specific message from the queue by messageId
    func remove(messageId: String) {
        self.queuedMessages.removeAll { $0.messageId == messageId }
        saveToStorage()
        logger.info("Removed message from queue: \(messageId)")
    }
    
    /// Update retry count for a message
    func incrementRetryCount(messageId: String) {
        if let index = self.queuedMessages.firstIndex(where: { $0.messageId == messageId }) {
            self.queuedMessages[index].retryCount += 1
            saveToStorage()
            logger.info("Incremented retry count for message: \(messageId) to \(self.queuedMessages[index].retryCount)")
        }
    }
    
    /// Check if retry limit is reached for a message
    func hasReachedRetryLimit(messageId: String) -> Bool {
        guard let message = self.queuedMessages.first(where: { $0.messageId == messageId }) else {
            return false
        }
        return message.retryCount >= maxRetryAttempts
    }
    
    /// Clear all queued messages
    func clearQueue() {
        logger.info("Clearing entire queue")
        queuedMessages.removeAll()
        saveToStorage()
    }
    
    /// Get count of queued messages
    var count: Int {
        return queuedMessages.count
    }
    
    /// Check if queue is empty
    var isEmpty: Bool {
        return queuedMessages.isEmpty
    }
    
    // MARK: - Queue Processing
    
    /// Process all queued messages using the provided send function
    /// - Parameter sendFunction: Async function that attempts to send a message
    /// - Returns: Number of successfully sent messages
    func processQueue(using sendFunction: @escaping (QueuedMessage) async throws -> Void) async -> Int {
        guard !isEmpty else {
            logger.info("No messages to process in queue")
            return 0
        }
        
        logger.info("Processing queue with \(self.count) messages")
        var successCount = 0
        var failedMessages: [QueuedMessage] = []
        
        // Process all queued messages
        while let message = dequeue() {
            do {
                // Attempt to send the message
                try await sendFunction(message)
                successCount += 1
                logger.info("Successfully sent queued message: \(message.messageId)")
                
            } catch {
                // Increment retry count
                var updatedMessage = message
                updatedMessage.retryCount += 1
                
                // Check if retry limit reached
                if updatedMessage.retryCount >= maxRetryAttempts {
                    logger.error("Message \(message.messageId) reached max retry attempts, removing from queue")
                    // Don't re-add to queue, it will be marked as failed
                } else {
                    logger.warning("Failed to send queued message: \(message.messageId), will retry. Error: \(error.localizedDescription)")
                    failedMessages.append(updatedMessage)
                }
            }
        }
        
        // Re-add failed messages that haven't reached retry limit
        for message in failedMessages {
            queuedMessages.append(message)
        }
        
        saveToStorage()
        logger.info("Queue processing complete. Sent: \(successCount), Remaining: \(self.count)")
        return successCount
    }
    
    // MARK: - Persistence
    
    /// Save queue to UserDefaults
    private func saveToStorage() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self.queuedMessages)
            storage.set(data, forKey: storageKey)
            logger.debug("Queue saved to storage with \(self.queuedMessages.count) messages")
        } catch {
            logger.error("Failed to save queue to storage: \(error.localizedDescription)")
        }
    }
    
    /// Load queue from UserDefaults
    private func loadFromStorage() {
        guard let data = storage.data(forKey: storageKey) else {
            logger.info("No saved queue found in storage")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.queuedMessages = try decoder.decode([QueuedMessage].self, from: data)
            logger.info("Loaded \(self.queuedMessages.count) messages from storage")
        } catch {
            logger.error("Failed to load queue from storage: \(error.localizedDescription)")
            self.queuedMessages = []
        }
    }
}

