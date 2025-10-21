//
//  ConversationListViewModel.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation
import Combine
import FirebaseAuth
import OSLog
import SwiftData

/// ViewModel for managing conversation list state and operations
@MainActor
final class ConversationListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of conversations for the current user
    @Published var conversations: [Conversation] = []
    
    /// Loading state indicator
    @Published var isLoading: Bool = false
    
    /// Error message for display to user
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let firestoreService: FirestoreService
    private let authService: AuthService
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ConversationListViewModel")
    
    /// In-memory cache for user display names to avoid repeated fetches
    private var userCache: [String: User] = [:]
    
    /// Task for managing the conversation listener
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService, modelContext: ModelContext? = nil) {
        self.firestoreService = firestoreService
        self.authService = authService
        self.modelContext = modelContext
    }
    
    // MARK: - Lifecycle Methods
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Start listening to conversations when view appears
    func onAppear() {
        logger.info("ConversationListView appeared")
        loadConversations()
    }
    
    /// Stop listening to conversations when view disappears
    func onDisappear() {
        logger.info("ConversationListView disappeared")
        stopListening()
    }
    
    // MARK: - Public Methods
    
    /// Load conversations from cache first, then start real-time listener
    func loadConversations() {
        // Load from cache first for instant UI
        loadFromCache()
        
        // Start Firestore listener
        startFirestoreListener()
    }
    
    /// Get display name for a user ID (uses cache or fetches from Firestore)
    func getDisplayName(for userId: String) -> String {
        if let cachedUser = userCache[userId] {
            return cachedUser.displayName
        }
        
        // Return placeholder while loading
        // Trigger fetch in background
        Task {
            await fetchAndCacheUser(userId: userId)
        }
        
        return "Loading..."
    }
    
    /// Get the other participant's ID in a 1:1 conversation
    func getOtherParticipantId(for conversation: Conversation) -> String {
        guard let currentUserId = authService.currentUser?.userId,
              let otherUserId = conversation.otherParticipantId(currentUserId: currentUserId) else {
            return ""
        }
        
        return otherUserId
    }
    
    /// Get display name for conversation (handles both 1:1 and group chats)
    func getOtherParticipantName(for conversation: Conversation) -> String {
        // For group chats, use group name or formatted participant list
        if conversation.isGroupChat {
            return getGroupDisplayName(for: conversation)
        }
        
        // For 1:1 chats, show the other user's name
        guard let currentUserId = authService.currentUser?.userId,
              let otherUserId = conversation.otherParticipantId(currentUserId: currentUserId) else {
            return "Unknown"
        }
        
        return getDisplayName(for: otherUserId)
    }
    
    /// Get display name for a group chat
    private func getGroupDisplayName(for conversation: Conversation) -> String {
        // If group has a name, use it
        if let groupName = conversation.groupName, !groupName.isEmpty {
            return groupName
        }
        
        // Otherwise, format participant names
        guard let currentUserId = authService.currentUser?.userId else {
            return "Group Chat"
        }
        
        // Get names of other participants (excluding current user)
        let otherParticipants = conversation.participants.filter { $0 != currentUserId }
        let names = otherParticipants.map { getDisplayName(for: $0) }
        
        // Format based on count
        if names.isEmpty {
            return "Group Chat"
        } else if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let shown = names.prefix(2).joined(separator: ", ")
            return "\(shown), +\(names.count - 2) more"
        }
    }
    
    // MARK: - Private Methods
    
    /// Load conversations from SwiftData cache
    private func loadFromCache() {
        guard let modelContext = modelContext else {
            logger.warning("No ModelContext available for caching")
            return
        }
        
        do {
            // Fetch all cached entities (no sorting in descriptor due to optional timestamp)
            let descriptor = FetchDescriptor<ConversationEntity>()
            let cachedEntities = try modelContext.fetch(descriptor)
            
            if !cachedEntities.isEmpty {
                // Convert to conversations and sort manually
                let conversations = cachedEntities.map { $0.toConversation() }
                    .sorted { conversation1, conversation2 in
                        // Sort by timestamp, handling optionals (newest first)
                        guard let time1 = conversation1.lastMessageTimestamp else { return false }
                        guard let time2 = conversation2.lastMessageTimestamp else { return true }
                        return time1 > time2
                    }
                
                self.conversations = conversations
                logger.info("Loaded \(cachedEntities.count) conversations from cache")
            }
        } catch {
            logger.error("Failed to load conversations from cache: \(error.localizedDescription)")
            // Don't crash the app - cache loading is not critical
            // Continue to Firestore fetch instead
        }
    }
    
    /// Start listening to Firestore for real-time updates
    private func startFirestoreListener() {
        guard let currentUser = authService.currentUser else {
            logger.error("Cannot load conversations: No authenticated user")
            errorMessage = "Please log in to view conversations."
            return
        }
        
        // Cancel any existing listener
        stopListening()
        
        isLoading = true
        errorMessage = nil
        
        listenerTask = Task {
            do {
                let stream = firestoreService.listenToConversations(userId: currentUser.userId)
                
                for try await conversations in stream {
                    // Update UI with new conversations
                    self.conversations = conversations
                    self.isLoading = false
                    
                    // Save to cache
                    await saveToCache(conversations: conversations)
                    
                    // Prefetch user details for all participants
                    await prefetchUserDetails(from: conversations)
                }
                
            } catch {
                logger.error("Failed to listen to conversations: \(error.localizedDescription)")
                self.errorMessage = "Unable to load conversations. Please try again."
                self.isLoading = false
            }
        }
    }
    
    /// Stop listening to Firestore updates
    private func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }
    
    /// Save conversations to SwiftData cache
    private func saveToCache(conversations: [Conversation]) async {
        guard let modelContext = modelContext else { return }
        
        do {
            // Fetch existing entities
            let descriptor = FetchDescriptor<ConversationEntity>()
            let existingEntities = try modelContext.fetch(descriptor)
            
            // Create lookup dictionary
            let existingDict = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.conversationId, $0) })
            
            // Update or insert conversations
            for conversation in conversations {
                if let existing = existingDict[conversation.conversationId] {
                    existing.update(from: conversation)
                } else {
                    let newEntity = ConversationEntity.from(conversation: conversation)
                    modelContext.insert(newEntity)
                }
            }
            
            try modelContext.save()
            logger.info("Saved \(conversations.count) conversations to cache")
            
        } catch {
            logger.error("Failed to save conversations to cache: \(error.localizedDescription)")
        }
    }
    
    /// Prefetch user details for all conversation participants
    private func prefetchUserDetails(from conversations: [Conversation]) async {
        guard let currentUserId = authService.currentUser?.userId else { return }
        
        // Collect all unique participant IDs (excluding current user)
        var participantIds = Set<String>()
        for conversation in conversations {
            participantIds.formUnion(conversation.participants.filter { $0 != currentUserId })
        }
        
        // Fetch users not already in cache
        for userId in participantIds where userCache[userId] == nil {
            await fetchAndCacheUser(userId: userId)
        }
    }
    
    /// Fetch and cache a user's details
    private func fetchAndCacheUser(userId: String) async {
        // Check if already in cache
        guard userCache[userId] == nil else { return }
        
        do {
            let user = try await firestoreService.fetchUser(userId: userId)
            userCache[userId] = user
            
            // Trigger UI update by modifying published property
            // This ensures display names update after fetching
            self.conversations = self.conversations
            
            logger.info("Cached user details for userId: \(userId)")
            
        } catch {
            logger.error("Failed to fetch user \(userId): \(error.localizedDescription)")
            // Cache a placeholder to avoid repeated failed fetches
            userCache[userId] = User(
                userId: userId,
                displayName: "Unknown User",
                presence: .offline,
                lastSeen: Date()
            )
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cancel the listener task on cleanup
        listenerTask?.cancel()
    }
}

