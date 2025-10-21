//
//  ChatViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-21.
//

import XCTest
import SwiftData
@testable import MessageAI

@MainActor
final class ChatViewModelTests: XCTestCase {
    
    var viewModel: ChatViewModel!
    var mockFirestoreService: MockFirestoreService!
    var mockAuthService: MockAuthService!
    var modelContext: ModelContext!
    
    let testConversationId = "conv_test_123"
    let testOtherUserId = "user_other_456"
    let testCurrentUserId = "user_current_123"
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up in-memory model context for testing
        let schema = Schema([
            UserEntity.self,
            ConversationEntity.self,
            MessageEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
        
        // Create mock services
        mockFirestoreService = MockFirestoreService()
        mockAuthService = MockAuthService()
        mockAuthService.currentUser = User(
            userId: testCurrentUserId,
            displayName: "Test User",
            email: "test@example.com",
            presence: .online,
            lastSeen: Date()
        )
        
        // Create view model
        viewModel = ChatViewModel(
            conversationId: testConversationId,
            otherUserId: testOtherUserId,
            firestoreService: mockFirestoreService,
            authService: mockAuthService,
            modelContext: modelContext
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockFirestoreService = nil
        mockAuthService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Sending Messages Tests
    
    func testSendMessage_WithExistingConversation_CallsSendMessage() async throws {
        // Arrange
        viewModel.conversationId = testConversationId
        viewModel.messageText = "Hello, world!"
        mockFirestoreService.sendMessageResult = .success(Message(
            id: "msg_123",
            messageId: "msg_123",
            senderId: testCurrentUserId,
            text: "Hello, world!",
            timestamp: Date(),
            status: "sent"
        ))
        
        // Act
        await viewModel.sendMessage()
        
        // Assert
        XCTAssertTrue(mockFirestoreService.sendMessageCalled, "sendMessage should be called for existing conversation")
        XCTAssertEqual(mockFirestoreService.lastConversationId, testConversationId)
        XCTAssertEqual(mockFirestoreService.lastMessageText, "Hello, world!")
        XCTAssertTrue(viewModel.messageText.isEmpty, "Message text should be cleared after sending")
        XCTAssertFalse(viewModel.isSending, "isSending should be false after completion")
    }
    
    func testSendMessage_WithNewConversation_CreatesConversationAndMessage() async throws {
        // Arrange
        viewModel.conversationId = nil  // New conversation
        viewModel.messageText = "First message!"
        let newConversationId = "conv_new_789"
        
        mockFirestoreService.createConversationResult = .success((
            conversationId: newConversationId,
            message: Message(
                id: "msg_first",
                messageId: "msg_first",
                senderId: testCurrentUserId,
                text: "First message!",
                timestamp: Date(),
                status: "sent"
            )
        ))
        
        // Act
        await viewModel.sendMessage()
        
        // Assert
        XCTAssertTrue(mockFirestoreService.createConversationCalled, "createConversation should be called for new conversation")
        XCTAssertEqual(mockFirestoreService.lastMessageText, "First message!")
        XCTAssertEqual(viewModel.conversationId, newConversationId, "conversationId should be updated after creation")
        XCTAssertTrue(viewModel.messageText.isEmpty, "Message text should be cleared after sending")
    }
    
    func testSendMessage_WithEmptyText_DoesNotSend() async {
        // Arrange
        viewModel.messageText = "   "  // Whitespace only
        
        // Act
        await viewModel.sendMessage()
        
        // Assert
        XCTAssertFalse(mockFirestoreService.sendMessageCalled, "Should not send empty message")
        XCTAssertFalse(mockFirestoreService.createConversationCalled, "Should not create conversation for empty message")
    }
    
    func testSendMessage_WithoutCurrentUser_SetsError() async {
        // Arrange
        mockAuthService.currentUser = nil
        viewModel.messageText = "Hello"
        
        // Act
        await viewModel.sendMessage()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage, "Should set error message when no current user")
        XCTAssertFalse(mockFirestoreService.sendMessageCalled)
    }
    
    func testSendMessage_WhenFirestoreFails_SetsError() async {
        // Arrange
        viewModel.conversationId = testConversationId
        viewModel.messageText = "Hello"
        mockFirestoreService.sendMessageResult = .failure(FirestoreError.writeFailed("Network error"))
        
        // Act
        await viewModel.sendMessage()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage, "Should set error message on Firestore failure")
        XCTAssertFalse(viewModel.isSending, "isSending should be false after error")
    }
    
    // MARK: - Helper Method Tests
    
    func testIsSentByCurrentUser_WithCurrentUserMessage_ReturnsTrue() {
        // Arrange
        let message = Message(
            id: "msg_1",
            messageId: "msg_1",
            senderId: testCurrentUserId,
            text: "Test",
            timestamp: Date(),
            status: "sent"
        )
        
        // Act
        let result = viewModel.isSentByCurrentUser(message: message)
        
        // Assert
        XCTAssertTrue(result, "Message from current user should return true")
    }
    
    func testIsSentByCurrentUser_WithOtherUserMessage_ReturnsFalse() {
        // Arrange
        let message = Message(
            id: "msg_2",
            messageId: "msg_2",
            senderId: testOtherUserId,
            text: "Test",
            timestamp: Date(),
            status: "sent"
        )
        
        // Act
        let result = viewModel.isSentByCurrentUser(message: message)
        
        // Assert
        XCTAssertFalse(result, "Message from other user should return false")
    }
}

// MARK: - Mock Services

@MainActor
class MockFirestoreService: FirestoreService {
    var sendMessageCalled = false
    var createConversationCalled = false
    var lastConversationId: String?
    var lastMessageText: String?
    var lastParticipants: [String]?
    
    var sendMessageResult: Result<Message, Error> = .success(Message(
        id: "mock_msg",
        messageId: "mock_msg",
        senderId: "mock_user",
        text: "Mock message",
        timestamp: Date(),
        status: "sent"
    ))
    
    var createConversationResult: Result<(conversationId: String, message: Message), Error> = .success((
        conversationId: "mock_conv",
        message: Message(
            id: "mock_msg",
            messageId: "mock_msg",
            senderId: "mock_user",
            text: "Mock message",
            timestamp: Date(),
            status: "sent"
        )
    ))
    
    var messagesToReturn: [Message] = []
    var userToReturn: User?
    
    override func sendMessage(conversationId: String, senderId: String, text: String) async throws -> Message {
        sendMessageCalled = true
        lastConversationId = conversationId
        lastMessageText = text
        
        switch sendMessageResult {
        case .success(let message):
            return message
        case .failure(let error):
            throw error
        }
    }
    
    override func createConversationWithMessage(participants: [String], senderId: String, text: String) async throws -> (conversationId: String, message: Message) {
        createConversationCalled = true
        lastParticipants = participants
        lastMessageText = text
        
        switch createConversationResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
    
    override func listenToMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(messagesToReturn)
            continuation.finish()
        }
    }
    
    override func fetchUser(userId: String) async throws -> User {
        if let user = userToReturn {
            return user
        }
        return User(userId: userId, displayName: "Mock User", email: nil, presence: .online, lastSeen: Date())
    }
}

class MockAuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
}

