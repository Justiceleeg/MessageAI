//
//  ConversationModelTests.swift
//  MessageAITests
//
//  Created by Justice Perez White on 10/21/25.
//

import XCTest
import FirebaseFirestore
@testable import MessageAI

final class ConversationModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testConversationInit_WithValidData_CreatesConversation() {
        // Act
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            lastMessageText: "Hello",
            lastMessageTimestamp: Date(),
            isGroupChat: false
        )
        
        // Assert
        XCTAssertEqual(conversation.conversationId, "conv123")
        XCTAssertEqual(conversation.participants.count, 2)
        XCTAssertEqual(conversation.lastMessageText, "Hello")
        XCTAssertFalse(conversation.isGroupChat)
    }
    
    func testConversationId_ReturnsConversationId() {
        // Arrange
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        
        // Act & Assert
        XCTAssertEqual(conversation.id, "conv123", "ID should match conversationId")
    }
    
    // MARK: - Helper Method Tests
    
    func testOtherParticipantId_In1to1Chat_ReturnsOtherId() {
        // Arrange
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        
        // Act
        let otherId = conversation.otherParticipantId(currentUserId: "user1")
        
        // Assert
        XCTAssertEqual(otherId, "user2", "Should return the other participant's ID")
    }
    
    func testOtherParticipantId_InGroupChat_ReturnsNil() {
        // Arrange
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true
        )
        
        // Act
        let otherId = conversation.otherParticipantId(currentUserId: "user1")
        
        // Assert
        XCTAssertNil(otherId, "Should return nil for group chats")
    }
    
    func testOtherParticipantId_WhenCurrentUserNotInList_ReturnsFirstParticipant() {
        // Arrange
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user2", "user3"],
            isGroupChat: false
        )
        
        // Act
        let otherId = conversation.otherParticipantId(currentUserId: "user1")
        
        // Assert
        XCTAssertEqual(otherId, "user2", "Should return first participant if current user not in list")
    }
    
    // MARK: - Codable Tests
    
    func testConversationCodable_EncodesAndDecodes() throws {
        // Arrange
        let originalConversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            lastMessageText: "Test message",
            lastMessageTimestamp: Date(),
            isGroupChat: false
        )
        
        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConversation)
        
        // Act - Decode
        let decoder = JSONDecoder()
        let decodedConversation = try decoder.decode(Conversation.self, from: data)
        
        // Assert
        XCTAssertEqual(decodedConversation.conversationId, originalConversation.conversationId)
        XCTAssertEqual(decodedConversation.participants, originalConversation.participants)
        XCTAssertEqual(decodedConversation.lastMessageText, originalConversation.lastMessageText)
        XCTAssertEqual(decodedConversation.isGroupChat, originalConversation.isGroupChat)
    }
    
    // MARK: - Firestore Conversion Tests
    
    func testToFirestoreData_ConvertsAllFields() {
        // Arrange
        let date = Date()
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            lastMessageText: "Hello",
            lastMessageTimestamp: date,
            isGroupChat: false
        )
        
        // Act
        let firestoreData = conversation.toFirestoreData()
        
        // Assert
        XCTAssertEqual(firestoreData["participants"] as? [String], ["user1", "user2"])
        XCTAssertEqual(firestoreData["lastMessageText"] as? String, "Hello")
        XCTAssertEqual(firestoreData["isGroupChat"] as? Bool, false)
        XCTAssertNotNil(firestoreData["lastMessageTimestamp"])
    }
    
    func testToFirestoreData_WithNilOptionalFields_OmitsThoseFields() {
        // Arrange
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            lastMessageText: nil,
            lastMessageTimestamp: nil,
            isGroupChat: false
        )
        
        // Act
        let firestoreData = conversation.toFirestoreData()
        
        // Assert
        XCTAssertNil(firestoreData["lastMessageText"])
        XCTAssertNil(firestoreData["lastMessageTimestamp"])
        XCTAssertNotNil(firestoreData["participants"])
        XCTAssertNotNil(firestoreData["isGroupChat"])
    }
    
    // MARK: - Hashable Tests
    
    func testConversationEquatable_SameId_ReturnsTrue() {
        // Arrange
        let conversation1 = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        let conversation2 = Conversation(
            conversationId: "conv123",
            participants: ["user3", "user4"],
            isGroupChat: true
        )
        
        // Act & Assert
        XCTAssertEqual(conversation1, conversation2, "Conversations with same ID should be equal")
    }
    
    func testConversationEquatable_DifferentId_ReturnsFalse() {
        // Arrange
        let conversation1 = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        let conversation2 = Conversation(
            conversationId: "conv456",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        
        // Act & Assert
        XCTAssertNotEqual(conversation1, conversation2, "Conversations with different IDs should not be equal")
    }
    
    func testConversationHashable_CanBeUsedInSet() {
        // Arrange
        let conversation1 = Conversation(conversationId: "conv1", participants: ["u1"], isGroupChat: false)
        let conversation2 = Conversation(conversationId: "conv2", participants: ["u2"], isGroupChat: false)
        let conversation3 = Conversation(conversationId: "conv1", participants: ["u3"], isGroupChat: false)
        
        // Act
        let conversationSet: Set<Conversation> = [conversation1, conversation2, conversation3]
        
        // Assert
        XCTAssertEqual(conversationSet.count, 2, "Set should contain only 2 unique conversations (conv1 and conv2)")
    }
    
    // MARK: - Group Chat Tests
    
    func testConversationInit_WithThreeParticipants_CreatesGroupChat() {
        // Act
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            lastMessageText: "Hello group!",
            lastMessageTimestamp: Date(),
            isGroupChat: true
        )
        
        // Assert
        XCTAssertEqual(conversation.conversationId, "groupConv123")
        XCTAssertEqual(conversation.participants.count, 3)
        XCTAssertEqual(conversation.lastMessageText, "Hello group!")
        XCTAssertTrue(conversation.isGroupChat)
    }
    
    func testConversationInit_WithGroupName_StoresGroupName() {
        // Act
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true,
            groupName: "Team Alpha"
        )
        
        // Assert
        XCTAssertEqual(conversation.groupName, "Team Alpha")
        XCTAssertTrue(conversation.isGroupChat)
    }
    
    func testConversationInit_WithoutGroupName_HasNilGroupName() {
        // Act
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true
        )
        
        // Assert
        XCTAssertNil(conversation.groupName)
    }
    
    func testIsGroupChat_WithTwoParticipants_IsFalse() {
        // Act
        let conversation = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2"],
            isGroupChat: false
        )
        
        // Assert
        XCTAssertFalse(conversation.isGroupChat)
        XCTAssertEqual(conversation.participants.count, 2)
    }
    
    func testIsGroupChat_WithThreeParticipants_IsTrue() {
        // Act
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true
        )
        
        // Assert
        XCTAssertTrue(conversation.isGroupChat)
        XCTAssertEqual(conversation.participants.count, 3)
    }
    
    func testIsGroupChat_WithFourParticipants_IsTrue() {
        // Act
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3", "user4"],
            isGroupChat: true
        )
        
        // Assert
        XCTAssertTrue(conversation.isGroupChat)
        XCTAssertEqual(conversation.participants.count, 4)
    }
    
    func testToFirestoreData_WithGroupName_IncludesGroupName() {
        // Arrange
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true,
            groupName: "Project Team"
        )
        
        // Act
        let firestoreData = conversation.toFirestoreData()
        
        // Assert
        XCTAssertEqual(firestoreData["groupName"] as? String, "Project Team")
        XCTAssertEqual(firestoreData["isGroupChat"] as? Bool, true)
        XCTAssertEqual(firestoreData["participants"] as? [String], ["user1", "user2", "user3"])
    }
    
    func testToFirestoreData_WithoutGroupName_OmitsGroupName() {
        // Arrange
        let conversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true
        )
        
        // Act
        let firestoreData = conversation.toFirestoreData()
        
        // Assert
        XCTAssertNil(firestoreData["groupName"])
        XCTAssertEqual(firestoreData["isGroupChat"] as? Bool, true)
    }
    
    func testConversationCodable_WithGroupName_EncodesAndDecodes() throws {
        // Arrange
        let originalConversation = Conversation(
            conversationId: "groupConv123",
            participants: ["user1", "user2", "user3"],
            lastMessageText: "Group test message",
            lastMessageTimestamp: Date(),
            isGroupChat: true,
            groupName: "Study Group"
        )
        
        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConversation)
        
        // Act - Decode
        let decoder = JSONDecoder()
        let decodedConversation = try decoder.decode(Conversation.self, from: data)
        
        // Assert
        XCTAssertEqual(decodedConversation.conversationId, originalConversation.conversationId)
        XCTAssertEqual(decodedConversation.participants, originalConversation.participants)
        XCTAssertEqual(decodedConversation.groupName, originalConversation.groupName)
        XCTAssertEqual(decodedConversation.isGroupChat, originalConversation.isGroupChat)
    }
    
    func testConversationEquatable_WithDifferentGroupNames_ReturnsNotEqual() {
        // Arrange
        let conversation1 = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true,
            groupName: "Team A"
        )
        let conversation2 = Conversation(
            conversationId: "conv123",
            participants: ["user1", "user2", "user3"],
            isGroupChat: true,
            groupName: "Team B"
        )
        
        // Act & Assert
        XCTAssertNotEqual(conversation1, conversation2, "Conversations with different group names should not be equal")
    }
}

