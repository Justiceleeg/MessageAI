//
//  MessageModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-21.
//

import XCTest
@testable import MessageAI

final class MessageModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testMessageInit_WithDefaultValues_CreatesMessage() {
        // Act
        let message = Message(
            id: "msg123",
            messageId: "msg123",
            senderId: "user1",
            text: "Hello",
            timestamp: Date()
        )
        
        // Assert
        XCTAssertEqual(message.id, "msg123")
        XCTAssertEqual(message.messageId, "msg123")
        XCTAssertEqual(message.senderId, "user1")
        XCTAssertEqual(message.text, "Hello")
        XCTAssertEqual(message.status, "sending", "Default status should be 'sending'")
        XCTAssertTrue(message.readBy.isEmpty, "Default readBy should be empty array")
    }
    
    func testMessageInit_WithReadByArray_CreatesMessage() {
        // Act
        let message = Message(
            id: "msg123",
            messageId: "msg123",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Assert
        XCTAssertEqual(message.status, "read")
        XCTAssertEqual(message.readBy.count, 2)
        XCTAssertTrue(message.readBy.contains("user2"))
        XCTAssertTrue(message.readBy.contains("user3"))
    }
    
    // MARK: - Status Values Tests
    
    func testMessageStatus_SendingStatus_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "sending"
        )
        
        // Assert
        XCTAssertEqual(message.status, "sending")
    }
    
    func testMessageStatus_SentStatus_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "sent"
        )
        
        // Assert
        XCTAssertEqual(message.status, "sent")
    }
    
    func testMessageStatus_DeliveredStatus_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "delivered"
        )
        
        // Assert
        XCTAssertEqual(message.status, "delivered")
    }
    
    func testMessageStatus_ReadStatus_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "read"
        )
        
        // Assert
        XCTAssertEqual(message.status, "read")
    }
    
    // MARK: - ReadBy Array Tests
    
    func testMessageReadBy_EmptyArray_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: []
        )
        
        // Assert
        XCTAssertTrue(message.readBy.isEmpty)
    }
    
    func testMessageReadBy_SingleUser_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: ["user2"]
        )
        
        // Assert
        XCTAssertEqual(message.readBy.count, 1)
        XCTAssertTrue(message.readBy.contains("user2"))
    }
    
    func testMessageReadBy_MultipleUsers_IsValid() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: ["user2", "user3", "user4"]
        )
        
        // Assert
        XCTAssertEqual(message.readBy.count, 3)
        XCTAssertTrue(message.readBy.contains("user2"))
        XCTAssertTrue(message.readBy.contains("user3"))
        XCTAssertTrue(message.readBy.contains("user4"))
    }
    
    // MARK: - Helper Method Tests
    
    func testIsSentByCurrentUser_WhenMatchingUserId_ReturnsTrue() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date()
        )
        
        // Act & Assert
        XCTAssertTrue(message.isSentByCurrentUser(currentUserId: "user1"))
    }
    
    func testIsSentByCurrentUser_WhenDifferentUserId_ReturnsFalse() {
        // Arrange
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date()
        )
        
        // Act & Assert
        XCTAssertFalse(message.isSentByCurrentUser(currentUserId: "user2"))
    }
    
    // MARK: - Codable Tests
    
    func testMessageCodable_EncodesAndDecodes_WithReadBy() throws {
        // Arrange
        let originalMessage = Message(
            id: "msg123",
            messageId: "msg123",
            senderId: "user1",
            text: "Test message",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMessage)
        
        // Act - Decode
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(Message.self, from: data)
        
        // Assert
        XCTAssertEqual(decodedMessage.messageId, originalMessage.messageId)
        XCTAssertEqual(decodedMessage.senderId, originalMessage.senderId)
        XCTAssertEqual(decodedMessage.text, originalMessage.text)
        XCTAssertEqual(decodedMessage.status, originalMessage.status)
        XCTAssertEqual(decodedMessage.readBy, originalMessage.readBy)
    }
    
    func testMessageCodable_DecodesWithoutReadBy_DefaultsToEmptyArray() throws {
        // Arrange - JSON without readBy field
        let json = """
        {
            "messageId": "msg123",
            "senderId": "user1",
            "text": "Test message",
            "timestamp": 1697894400,
            "status": "sent"
        }
        """
        let data = json.data(using: .utf8)!
        
        // Act
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(Message.self, from: data)
        
        // Assert
        XCTAssertTrue(decodedMessage.readBy.isEmpty, "readBy should default to empty array when missing from JSON")
        XCTAssertEqual(decodedMessage.status, "sent")
    }
    
    func testMessageCodable_EncodesAllStatusValues() throws {
        // Arrange
        let statuses = ["sending", "sent", "delivered", "read"]
        
        for status in statuses {
            let message = Message(
                id: "msg1",
                messageId: "msg1",
                senderId: "user1",
                text: "Test",
                timestamp: Date(),
                status: status
            )
            
            // Act
            let encoder = JSONEncoder()
            let data = try encoder.encode(message)
            let decoder = JSONDecoder()
            let decodedMessage = try decoder.decode(Message.self, from: data)
            
            // Assert
            XCTAssertEqual(decodedMessage.status, status, "Status '\(status)' should encode and decode correctly")
        }
    }
    
    // MARK: - Equatable Tests
    
    func testMessageEquatable_SameValues_ReturnsTrue() {
        // Arrange
        let date = Date()
        let message1 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "read",
            readBy: ["user2"]
        )
        let message2 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "read",
            readBy: ["user2"]
        )
        
        // Act & Assert
        XCTAssertEqual(message1, message2)
    }
    
    func testMessageEquatable_DifferentReadBy_ReturnsFalse() {
        // Arrange
        let date = Date()
        let message1 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "read",
            readBy: ["user2"]
        )
        let message2 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act & Assert
        XCTAssertNotEqual(message1, message2, "Messages with different readBy arrays should not be equal")
    }
    
    func testMessageEquatable_DifferentStatus_ReturnsFalse() {
        // Arrange
        let date = Date()
        let message1 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "sent"
        )
        let message2 = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: date,
            status: "read"
        )
        
        // Act & Assert
        XCTAssertNotEqual(message1, message2, "Messages with different status should not be equal")
    }
}

