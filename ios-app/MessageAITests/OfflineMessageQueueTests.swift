//
//  OfflineMessageQueueTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-21.
//  Story 2.3: Offline Persistence & Optimistic UI
//

import XCTest
@testable import MessageAI

/// Tests for OfflineMessageQueue service
@MainActor
final class OfflineMessageQueueTests: XCTestCase {
    
    var offlineQueue: OfflineMessageQueue!
    
    override func setUp() async throws {
        try await super.setUp()
        offlineQueue = OfflineMessageQueue()
        offlineQueue.clearQueue() // Start with empty queue
    }
    
    override func tearDown() async throws {
        offlineQueue.clearQueue() // Clean up after tests
        offlineQueue = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Queue Operations
    
    func testQueue_EnqueueMessage() {
        // Arrange
        let message = createTestMessage(id: "msg1", text: "Test message")
        
        // Act
        offlineQueue.enqueue(message)
        
        // Assert
        XCTAssertEqual(offlineQueue.count, 1, "Queue should contain 1 message")
        XCTAssertEqual(offlineQueue.queuedMessages.first?.text, "Test message")
        XCTAssertFalse(offlineQueue.isEmpty, "Queue should not be empty")
    }
    
    func testQueue_DequeueMessage() {
        // Arrange
        let message1 = createTestMessage(id: "msg1", text: "First")
        let message2 = createTestMessage(id: "msg2", text: "Second")
        offlineQueue.enqueue(message1)
        offlineQueue.enqueue(message2)
        
        // Act
        let dequeuedMessage = offlineQueue.dequeue()
        
        // Assert
        XCTAssertEqual(dequeuedMessage?.text, "First", "Should dequeue in FIFO order")
        XCTAssertEqual(offlineQueue.count, 1, "Queue should have 1 message remaining")
    }
    
    func testQueue_DequeueEmptyQueue() {
        // Act
        let dequeuedMessage = offlineQueue.dequeue()
        
        // Assert
        XCTAssertNil(dequeuedMessage, "Dequeue from empty queue should return nil")
    }
    
    func testQueue_RemoveSpecificMessage() {
        // Arrange
        let message1 = createTestMessage(id: "msg1", text: "First")
        let message2 = createTestMessage(id: "msg2", text: "Second")
        let message3 = createTestMessage(id: "msg3", text: "Third")
        offlineQueue.enqueue(message1)
        offlineQueue.enqueue(message2)
        offlineQueue.enqueue(message3)
        
        // Act
        offlineQueue.remove(messageId: "msg2")
        
        // Assert
        XCTAssertEqual(offlineQueue.count, 2, "Queue should have 2 messages after removal")
        XCTAssertNil(offlineQueue.queuedMessages.first { $0.messageId == "msg2" }, "Removed message should not exist")
    }
    
    func testQueue_ClearAll() {
        // Arrange
        offlineQueue.enqueue(createTestMessage(id: "msg1", text: "First"))
        offlineQueue.enqueue(createTestMessage(id: "msg2", text: "Second"))
        XCTAssertEqual(offlineQueue.count, 2)
        
        // Act
        offlineQueue.clearQueue()
        
        // Assert
        XCTAssertEqual(offlineQueue.count, 0, "Queue should be empty after clear")
        XCTAssertTrue(offlineQueue.isEmpty, "isEmpty should return true")
    }
    
    // MARK: - Retry Count Management
    
    func testQueue_IncrementRetryCount() {
        // Arrange
        let message = createTestMessage(id: "msg1", text: "Test")
        offlineQueue.enqueue(message)
        
        // Act
        offlineQueue.incrementRetryCount(messageId: "msg1")
        
        // Assert
        XCTAssertEqual(offlineQueue.queuedMessages.first?.retryCount, 1, "Retry count should increment")
    }
    
    func testQueue_CheckRetryLimit() {
        // Arrange
        var message = createTestMessage(id: "msg1", text: "Test")
        message.retryCount = 3 // Set to max retries
        offlineQueue.enqueue(message)
        
        // Act
        let hasReachedLimit = offlineQueue.hasReachedRetryLimit(messageId: "msg1")
        
        // Assert
        XCTAssertTrue(hasReachedLimit, "Should detect retry limit reached")
    }
    
    func testQueue_CheckRetryLimitNotReached() {
        // Arrange
        let message = createTestMessage(id: "msg1", text: "Test")
        offlineQueue.enqueue(message)
        
        // Act
        let hasReachedLimit = offlineQueue.hasReachedRetryLimit(messageId: "msg1")
        
        // Assert
        XCTAssertFalse(hasReachedLimit, "Should not detect retry limit for new message")
    }
    
    // MARK: - Queue Processing
    
    func testQueue_ProcessSuccessfulMessages() async throws {
        // Arrange
        offlineQueue.enqueue(createTestMessage(id: "msg1", text: "First"))
        offlineQueue.enqueue(createTestMessage(id: "msg2", text: "Second"))
        
        var processedMessages: [String] = []
        
        // Act
        let sentCount = await offlineQueue.processQueue { message in
            // Simulate successful send
            processedMessages.append(message.text)
        }
        
        // Assert
        XCTAssertEqual(sentCount, 2, "Should process 2 messages")
        XCTAssertEqual(processedMessages.count, 2, "Should call send function twice")
        XCTAssertTrue(offlineQueue.isEmpty, "Queue should be empty after successful processing")
    }
    
    func testQueue_ProcessWithFailures() async throws {
        // Arrange
        offlineQueue.enqueue(createTestMessage(id: "msg1", text: "Success"))
        offlineQueue.enqueue(createTestMessage(id: "msg2", text: "Fail"))
        
        // Act
        let sentCount = await offlineQueue.processQueue { message in
            if message.text == "Fail" {
                throw NSError(domain: "TestError", code: -1, userInfo: nil)
            }
            // Success case - do nothing
        }
        
        // Assert
        XCTAssertEqual(sentCount, 1, "Should successfully send 1 message")
        XCTAssertEqual(offlineQueue.count, 1, "Failed message should remain in queue")
        XCTAssertEqual(offlineQueue.queuedMessages.first?.text, "Fail")
        XCTAssertEqual(offlineQueue.queuedMessages.first?.retryCount, 1, "Retry count should increment")
    }
    
    func testQueue_RemoveMessagesAtRetryLimit() async throws {
        // Arrange
        var message = createTestMessage(id: "msg1", text: "MaxRetries")
        message.retryCount = 2 // Will reach 3 after one more failure
        offlineQueue.enqueue(message)
        
        // Act - Process and fail
        _ = await offlineQueue.processQueue { _ in
            throw NSError(domain: "TestError", code: -1, userInfo: nil)
        }
        
        // Assert - Message should be removed after reaching retry limit
        XCTAssertTrue(offlineQueue.isEmpty, "Message should be removed after reaching max retries")
    }
    
    // MARK: - Persistence Tests
    
    func testQueue_PersistsToStorage() {
        // Arrange
        let message = createTestMessage(id: "msg1", text: "Persistent")
        offlineQueue.enqueue(message)
        
        // Act - Create new queue instance (should load from storage)
        let newQueue = OfflineMessageQueue()
        
        // Assert
        XCTAssertEqual(newQueue.count, 1, "Queue should persist across instances")
        XCTAssertEqual(newQueue.queuedMessages.first?.text, "Persistent")
    }
    
    func testQueue_UpdatesStorageOnChanges() {
        // Arrange
        let message1 = createTestMessage(id: "msg1", text: "First")
        let message2 = createTestMessage(id: "msg2", text: "Second")
        offlineQueue.enqueue(message1)
        offlineQueue.enqueue(message2)
        
        // Act - Remove one message
        offlineQueue.remove(messageId: "msg1")
        
        // Create new instance
        let newQueue = OfflineMessageQueue()
        
        // Assert - Change should persist
        XCTAssertEqual(newQueue.count, 1, "Storage should reflect removal")
        XCTAssertEqual(newQueue.queuedMessages.first?.text, "Second")
    }
    
    // MARK: - Helper Methods
    
    private func createTestMessage(id: String, text: String) -> OfflineMessageQueue.QueuedMessage {
        return OfflineMessageQueue.QueuedMessage(
            messageId: id,
            conversationId: "conv123",
            senderId: "user123",
            text: text,
            timestamp: Date(),
            retryCount: 0
        )
    }
}

