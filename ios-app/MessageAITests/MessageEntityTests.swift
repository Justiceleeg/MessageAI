//
//  MessageEntityTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-21.
//

import XCTest
import SwiftData
@testable import MessageAI

final class MessageEntityTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create an in-memory model container for testing
        let schema = Schema([MessageEntity.self, ConversationEntity.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testMessageEntityInit_WithDefaultValues_CreatesEntity() {
        // Act
        let entity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Hello",
            timestamp: Date()
        )
        
        // Assert
        XCTAssertEqual(entity.messageId, "msg123")
        XCTAssertEqual(entity.senderId, "user1")
        XCTAssertEqual(entity.text, "Hello")
        XCTAssertEqual(entity.status, "sending", "Default status should be 'sending'")
        XCTAssertTrue(entity.readBy.isEmpty, "Default readBy should be empty array")
        XCTAssertNil(entity.conversation)
    }
    
    func testMessageEntityInit_WithReadByArray_CreatesEntity() {
        // Act
        let entity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Assert
        XCTAssertEqual(entity.status, "read")
        XCTAssertEqual(entity.readBy.count, 2)
        XCTAssertTrue(entity.readBy.contains("user2"))
        XCTAssertTrue(entity.readBy.contains("user3"))
    }
    
    // MARK: - Status Values Tests
    
    func testMessageEntityStatus_AllStatusValues_AreValid() {
        // Arrange
        let statuses = ["sending", "sent", "delivered", "read"]
        
        for status in statuses {
            // Act
            let entity = MessageEntity(
                messageId: "msg\(status)",
                senderId: "user1",
                text: "Test",
                timestamp: Date(),
                status: status
            )
            
            // Assert
            XCTAssertEqual(entity.status, status, "Status '\(status)' should be valid")
        }
    }
    
    // MARK: - ReadBy Array Tests
    
    func testMessageEntityReadBy_EmptyArray_IsValid() {
        // Act
        let entity = MessageEntity(
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: []
        )
        
        // Assert
        XCTAssertTrue(entity.readBy.isEmpty)
    }
    
    func testMessageEntityReadBy_MultipleUsers_IsValid() {
        // Act
        let entity = MessageEntity(
            messageId: "msg1",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: ["user2", "user3", "user4"]
        )
        
        // Assert
        XCTAssertEqual(entity.readBy.count, 3)
        XCTAssertTrue(entity.readBy.contains("user2"))
        XCTAssertTrue(entity.readBy.contains("user3"))
        XCTAssertTrue(entity.readBy.contains("user4"))
    }
    
    // MARK: - SwiftData Persistence Tests
    
    func testMessageEntity_CanBeSavedToSwiftData() throws {
        // Arrange
        let entity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Test message",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act
        modelContext.insert(entity)
        try modelContext.save()
        
        // Assert
        let descriptor = FetchDescriptor<MessageEntity>()
        let fetchedEntities = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetchedEntities.count, 1)
        
        let fetchedEntity = fetchedEntities[0]
        XCTAssertEqual(fetchedEntity.messageId, "msg123")
        XCTAssertEqual(fetchedEntity.status, "read")
        XCTAssertEqual(fetchedEntity.readBy, ["user2", "user3"])
    }
    
    func testMessageEntity_ReadByArrayPersists() throws {
        // Arrange
        let entity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            readBy: ["user2", "user3", "user4"]
        )
        
        // Act - Save
        modelContext.insert(entity)
        try modelContext.save()
        
        // Act - Fetch
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: #Predicate { $0.messageId == "msg123" }
        )
        let fetchedEntities = try modelContext.fetch(descriptor)
        
        // Assert
        XCTAssertEqual(fetchedEntities.count, 1)
        let fetchedEntity = fetchedEntities[0]
        XCTAssertEqual(fetchedEntity.readBy.count, 3)
        XCTAssertTrue(fetchedEntity.readBy.contains("user2"))
        XCTAssertTrue(fetchedEntity.readBy.contains("user3"))
        XCTAssertTrue(fetchedEntity.readBy.contains("user4"))
    }
    
    func testMessageEntity_UniqueMessageIdConstraint() throws {
        // Arrange
        let entity1 = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "First message",
            timestamp: Date()
        )
        let entity2 = MessageEntity(
            messageId: "msg123",
            senderId: "user2",
            text: "Second message",
            timestamp: Date()
        )
        
        // Act
        modelContext.insert(entity1)
        try modelContext.save()
        
        modelContext.insert(entity2)
        
        // Assert - Should handle duplicate messageId gracefully
        // SwiftData's @Attribute(.unique) ensures uniqueness
        do {
            try modelContext.save()
            // Fetch to verify only one entity exists
            let descriptor = FetchDescriptor<MessageEntity>()
            let entities = try modelContext.fetch(descriptor)
            XCTAssertEqual(entities.count, 1, "Only one entity should exist with unique messageId")
        } catch {
            // SwiftData may throw an error on duplicate unique attribute
            XCTAssertNotNil(error, "Expected error for duplicate unique messageId")
        }
    }
    
    // MARK: - Conversion Tests
    
    func testMessageEntityFromMessage_ConvertsCorrectly() {
        // Arrange
        let message = Message(
            id: "msg123",
            messageId: "msg123",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act
        let entity = MessageEntity.from(message: message)
        
        // Assert
        XCTAssertEqual(entity.messageId, message.messageId)
        XCTAssertEqual(entity.senderId, message.senderId)
        XCTAssertEqual(entity.text, message.text)
        XCTAssertEqual(entity.status, message.status)
        XCTAssertEqual(entity.readBy, message.readBy)
    }
    
    func testMessageEntityToMessage_ConvertsCorrectly() {
        // Arrange
        let entity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act
        let message = entity.toMessage()
        
        // Assert
        XCTAssertEqual(message.messageId, entity.messageId)
        XCTAssertEqual(message.senderId, entity.senderId)
        XCTAssertEqual(message.text, entity.text)
        XCTAssertEqual(message.status, entity.status)
        XCTAssertEqual(message.readBy, entity.readBy)
    }
    
    func testMessageEntityConversion_RoundTrip_PreservesData() {
        // Arrange
        let originalMessage = Message(
            id: "msg123",
            messageId: "msg123",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]
        )
        
        // Act - Convert to Entity and back to Message
        let entity = MessageEntity.from(message: originalMessage)
        let convertedMessage = entity.toMessage()
        
        // Assert
        XCTAssertEqual(convertedMessage.messageId, originalMessage.messageId)
        XCTAssertEqual(convertedMessage.senderId, originalMessage.senderId)
        XCTAssertEqual(convertedMessage.text, originalMessage.text)
        XCTAssertEqual(convertedMessage.status, originalMessage.status)
        XCTAssertEqual(convertedMessage.readBy, originalMessage.readBy)
    }
    
    // MARK: - Relationship Tests
    
    func testMessageEntity_CanHaveConversationRelationship() throws {
        // Arrange
        let conversationEntity = ConversationEntity(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        let messageEntity = MessageEntity(
            messageId: "msg123",
            senderId: "user1",
            text: "Test",
            timestamp: Date(),
            conversation: conversationEntity
        )
        
        // Act
        modelContext.insert(conversationEntity)
        modelContext.insert(messageEntity)
        try modelContext.save()
        
        // Assert
        XCTAssertNotNil(messageEntity.conversation)
        XCTAssertEqual(messageEntity.conversation?.conversationId, "conv123")
    }
}

