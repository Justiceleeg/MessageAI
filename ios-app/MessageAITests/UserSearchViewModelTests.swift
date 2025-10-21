//
//  UserSearchViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/21/25.
//

import XCTest
import Combine
@testable import MessageAI

@MainActor
final class UserSearchViewModelTests: XCTestCase {
    
    var viewModel: UserSearchViewModel!
    var mockFirestoreService: MockFirestoreService!
    var mockAuthService: MockAuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockFirestoreService = MockFirestoreService()
        mockAuthService = MockAuthService()
        
        // Set up mock auth with current user
        mockAuthService.currentUser = User(
            userId: "currentUser123",
            displayName: "Current User",
            presence: .online,
            lastSeen: Date()
        )
        
        viewModel = UserSearchViewModel(
            firestoreService: mockFirestoreService,
            authService: mockAuthService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockFirestoreService = nil
        mockAuthService = nil
        try await super.tearDown()
    }
    
    // MARK: - Search Tests
    
    func testSearchUsers_WithValidQuery_UpdatesSearchResults() async throws {
        // Arrange
        let mockUsers = [
            User(userId: "user1", displayName: "Alice Smith", email: "alice@example.com", presence: .online, lastSeen: Date()),
            User(userId: "user2", displayName: "Alice Jones", email: "alice.jones@example.com", presence: .online, lastSeen: Date())
        ]
        mockFirestoreService.mockSearchResults = mockUsers
        viewModel.searchQuery = "Alice"
        
        // Act
        await viewModel.searchUsers()
        
        // Assert
        XCTAssertEqual(viewModel.searchResults.count, 2)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSearchUsers_WithShortQuery_ReturnsEmpty() async throws {
        // Arrange
        viewModel.searchQuery = "A"  // Less than 2 characters
        
        // Act
        await viewModel.searchUsers()
        
        // Assert
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
    
    func testSearchUsers_WithEmptyQuery_ReturnsEmpty() async throws {
        // Arrange
        viewModel.searchQuery = ""
        
        // Act
        await viewModel.searchUsers()
        
        // Assert
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
    
    func testSearchUsers_WithNoAuthUser_SetsErrorMessage() async throws {
        // Arrange
        mockAuthService.currentUser = nil
        viewModel.searchQuery = "Alice"
        
        // Act
        await viewModel.searchUsers()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("log in"))
    }
    
    func testSearchUsers_OnError_SetsErrorMessage() async throws {
        // Arrange
        mockFirestoreService.shouldThrowError = true
        viewModel.searchQuery = "Alice"
        
        // Act
        await viewModel.searchUsers()
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSearching)
    }
    
    // MARK: - Select User Tests
    
    func testSelectUser_WithExistingConversation_ReturnsConversationId() async throws {
        // Arrange
        let otherUser = User(userId: "user456", displayName: "Alice", presence: .online, lastSeen: Date())
        let mockConversation = Conversation(
            conversationId: "conv123",
            participants: ["currentUser123", "user456"],
            isGroupChat: false
        )
        mockFirestoreService.mockFindConversationResult = mockConversation
        
        // Act
        let result = try await viewModel.selectUser(otherUser)
        
        // Assert
        XCTAssertEqual(result.conversationId, "conv123")
        XCTAssertEqual(result.otherUserId, "user456")
    }
    
    func testSelectUser_WithoutExistingConversation_ReturnsNilConversationId() async throws {
        // Arrange
        let otherUser = User(userId: "user456", displayName: "Alice", presence: .online, lastSeen: Date())
        mockFirestoreService.mockFindConversationResult = nil
        
        // Act
        let result = try await viewModel.selectUser(otherUser)
        
        // Assert
        XCTAssertNil(result.conversationId)
        XCTAssertEqual(result.otherUserId, "user456")
    }
    
    func testSelectUser_WhenUserTriesToMessageSelf_ThrowsError() async throws {
        // Arrange
        let selfUser = User(
            userId: "currentUser123",
            displayName: "Current User",
            presence: .online,
            lastSeen: Date()
        )
        
        // Act & Assert
        do {
            _ = try await viewModel.selectUser(selfUser)
            XCTFail("Expected error to be thrown when messaging self")
        } catch let error as UserSearchError {
            XCTAssertEqual(error, UserSearchError.cannotMessageSelf)
        }
    }
    
    func testSelectUser_WithNoAuthUser_ThrowsError() async throws {
        // Arrange
        mockAuthService.currentUser = nil
        let otherUser = User(userId: "user456", displayName: "Alice", presence: .online, lastSeen: Date())
        
        // Act & Assert
        do {
            _ = try await viewModel.selectUser(otherUser)
            XCTFail("Expected error to be thrown when no auth user")
        } catch {
            XCTAssertTrue(error is FirestoreError)
        }
    }
}

// MARK: - Mock Services

/// Mock FirestoreService for testing
@MainActor
class MockFirestoreService: FirestoreService {
    var mockSearchResults: [User] = []
    var mockFindConversationResult: Conversation?
    var shouldThrowError: Bool = false
    
    override func searchUsers(query: String, currentUserId: String) async throws -> [User] {
        if shouldThrowError {
            throw FirestoreError.readFailed("Mock error")
        }
        return mockSearchResults
    }
    
    override func findConversation(userId1: String, userId2: String) async throws -> Conversation? {
        if shouldThrowError {
            throw FirestoreError.readFailed("Mock error")
        }
        return mockFindConversationResult
    }
}

/// Mock AuthService for testing
@MainActor
class MockAuthService: AuthService {
    override var currentUser: User? {
        get { _mockCurrentUser }
        set { _mockCurrentUser = newValue }
    }
    
    private var _mockCurrentUser: User?
    
    override init(firestoreService: FirestoreService) {
        super.init(firestoreService: firestoreService)
    }
}

