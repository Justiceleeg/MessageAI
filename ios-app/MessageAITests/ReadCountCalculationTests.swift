//
//  ReadCountCalculationTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-22.
//  Story 4.1: Unit tests for read count calculation logic
//

import XCTest
import SwiftData
@testable import MessageAI

/// Tests for read count calculation in ChatViewModel (Story 4.1)
@MainActor
final class ReadCountCalculationTests: XCTestCase {
    
    var viewModel: ChatViewModel!
    var mockFirestoreService: ChatViewModelMockFirestoreService!
    var mockAuthService: ChatViewModelMockAuthService!
    var mockNetworkMonitor: ChatViewModelMockNetworkMonitor!
    var mockOfflineQueue: ChatViewModelMockOfflineMessageQueue!
    var modelContext: ModelContext!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup in-memory model context
        let schema = Schema([ConversationEntity.self, MessageEntity.self, UserEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(container)
        
        // Setup mock services
        mockFirestoreService = ChatViewModelMockFirestoreService()
        mockAuthService = ChatViewModelMockAuthService()
        mockNetworkMonitor = ChatViewModelMockNetworkMonitor()
        mockOfflineQueue = ChatViewModelMockOfflineMessageQueue()
        
        // Set current user
        mockAuthService.currentUser = User(
            id: "user1",
            userId: "user1",
            email: "user1@example.com",
            displayName: "User 1"
        )
        
        // Create view model
        viewModel = ChatViewModel(
            conversationId: "conv_123",
            otherUserId: "user2",
            firestoreService: mockFirestoreService,
            authService: mockAuthService,
            networkMonitor: mockNetworkMonitor,
            offlineQueue: mockOfflineQueue,
            modelContext: modelContext
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockFirestoreService = nil
        mockAuthService = nil
        mockNetworkMonitor = nil
        mockOfflineQueue = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Read Count Calculation Tests
    
    func testCalculateReadCount_OneToOneChat_NotRead() {
        // Given: A message in 1:1 chat that hasn't been read
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",  // Current user
            text: "Hello",
            timestamp: Date(),
            status: "delivered",
            readBy: []  // Not read yet
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 0
        XCTAssertEqual(readCount, 0, "Unread message should have count of 0")
    }
    
    func testCalculateReadCount_OneToOneChat_Read() {
        // Given: A message in 1:1 chat that has been read by other user
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",  // Current user
            text: "Hello",
            timestamp: Date(),
            status: "read",
            readBy: ["user2"]  // Other user read it
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 1
        XCTAssertEqual(readCount, 1, "Message read by other user should have count of 1")
    }
    
    func testCalculateReadCount_GroupChat_PartiallyRead() {
        // Given: A message in group chat read by some participants
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",  // Current user
            text: "Hello group",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3"]  // 2 out of 4 participants read it
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 2
        XCTAssertEqual(readCount, 2, "Message read by 2 users should have count of 2")
    }
    
    func testCalculateReadCount_GroupChat_AllRead() {
        // Given: A message in group chat read by all participants
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",  // Current user
            text: "Hello group",
            timestamp: Date(),
            status: "read",
            readBy: ["user2", "user3", "user4"]  // All 3 other participants read it
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 3
        XCTAssertEqual(readCount, 3, "Message read by all 3 participants should have count of 3")
    }
    
    func testCalculateReadCount_ExcludesCurrentUser() {
        // Given: A message where readBy includes current user (shouldn't happen but test edge case)
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",  // Current user
            text: "Hello",
            timestamp: Date(),
            status: "read",
            readBy: ["user1", "user2"]  // Includes sender (current user)
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 1 (excludes current user)
        XCTAssertEqual(readCount, 1, "Read count should exclude current user")
    }
    
    func testCalculateReadCount_ReceivedMessage_ReturnsZero() {
        // Given: A message received from another user (not sent by current user)
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user2",  // Other user
            text: "Hello back",
            timestamp: Date(),
            status: "delivered",
            readBy: ["user1"]
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 0 (only show counts for sent messages)
        XCTAssertEqual(readCount, 0, "Received messages should not show read count")
    }
    
    func testCalculateReadCount_NoAuthUser_ReturnsZero() {
        // Given: No authenticated user
        mockAuthService.currentUser = nil
        
        let message = Message(
            id: "msg1",
            messageId: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            status: "read",
            readBy: ["user2"]
        )
        
        // When: Calculate read count
        let readCount = viewModel.calculateReadCount(for: message)
        
        // Then: Count should be 0
        XCTAssertEqual(readCount, 0, "Should return 0 when no current user")
    }
}

// MARK: - Test-specific Mock Services (Story 4.1)

@MainActor
class ChatViewModelMockFirestoreService: FirestoreService {
    override func sendMessage(conversationId: String, senderId: String, text: String) async throws -> Message {
        return Message(id: "test", messageId: "test", senderId: senderId, text: text, timestamp: Date(), status: "sent")
    }
}

class ChatViewModelMockAuthService: ObservableObject {
    @Published var currentUser: User?
}

class ChatViewModelMockNetworkMonitor: NetworkMonitor {
    override init() {
        super.init()
    }
}

class ChatViewModelMockOfflineMessageQueue: OfflineMessageQueue {
    override init() {
        super.init()
    }
}


