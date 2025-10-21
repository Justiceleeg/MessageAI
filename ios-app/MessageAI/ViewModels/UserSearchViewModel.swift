//
//  UserSearchViewModel.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation
import Combine
import OSLog

/// ViewModel for managing user search state and operations (Story 2.0)
@MainActor
final class UserSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Search query text from search bar
    @Published var searchQuery: String = ""
    
    /// Array of search results
    @Published var searchResults: [User] = []
    
    /// Loading state indicator
    @Published var isSearching: Bool = false
    
    /// Error message for display to user
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let firestoreService: FirestoreService
    private let authService: AuthService
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "UserSearchViewModel")
    
    /// Cancellable for search debouncing
    private var searchCancellable: AnyCancellable?
    
    /// Task for managing search operation
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService) {
        self.firestoreService = firestoreService
        self.authService = authService
        
        // Set up search debouncing (300ms delay after user stops typing)
        setupSearchDebouncing()
    }
    
    // MARK: - Public Methods
    
    /// Search for users matching the query
    func searchUsers() async {
        // Validate minimum query length
        guard searchQuery.count >= 2 else {
            searchResults = []
            return
        }
        
        guard let currentUserId = authService.currentUser?.userId else {
            logger.error("Cannot search users: No authenticated user")
            errorMessage = "Please log in to search for users."
            return
        }
        
        // Cancel any existing search
        searchTask?.cancel()
        
        isSearching = true
        errorMessage = nil
        
        searchTask = Task {
            do {
                let results = try await firestoreService.searchUsers(
                    query: searchQuery,
                    currentUserId: currentUserId
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                searchResults = results
                isSearching = false
                logger.info("Search completed with \(results.count) results")
                
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                logger.error("Search failed: \(error.localizedDescription)")
                errorMessage = "Unable to search users. Please try again."
                searchResults = []
                isSearching = false
            }
        }
    }
    
    /// Select a user and check if conversation exists
    /// - Parameter user: The selected user
    /// - Returns: Tuple with optional conversationId (nil if new chat) and otherUserId
    func selectUser(_ user: User) async throws -> (conversationId: String?, otherUserId: String) {
        logger.info("User selected: \(user.userId)")
        
        guard let currentUserId = authService.currentUser?.userId else {
            logger.error("Cannot select user: No authenticated user")
            throw FirestoreError.userNotFound
        }
        
        // Check if user is trying to message themselves
        guard user.userId != currentUserId else {
            logger.warning("User attempted to message themselves")
            throw UserSearchError.cannotMessageSelf
        }
        
        do {
            // Check if conversation already exists
            let existingConversation = try await firestoreService.findConversation(
                userId1: currentUserId,
                userId2: user.userId
            )
            
            if let conversation = existingConversation {
                logger.info("Found existing conversation: \(conversation.conversationId)")
                return (conversationId: conversation.conversationId, otherUserId: user.userId)
            } else {
                logger.info("No existing conversation, will create on first message")
                return (conversationId: nil, otherUserId: user.userId)
            }
            
        } catch {
            logger.error("Failed to check for existing conversation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Set up search debouncing to avoid excessive queries
    private func setupSearchDebouncing() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.searchUsers()
                }
            }
    }
    
    // MARK: - Cleanup
    
    deinit {
        searchTask?.cancel()
        searchCancellable?.cancel()
    }
}

// MARK: - UserSearchError

/// Custom errors for user search operations
enum UserSearchError: LocalizedError {
    case cannotMessageSelf
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .cannotMessageSelf:
            return "You cannot start a conversation with yourself."
        case .userNotFound:
            return "User not found."
        }
    }
}

