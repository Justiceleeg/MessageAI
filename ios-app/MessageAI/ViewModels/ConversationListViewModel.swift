//
//  ConversationListViewModel.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseDatabase
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
    
    /// Map of user presence status (userId → isOnline)
    @Published var userPresenceMap: [String: Bool] = [:]
    
    /// Map of user last seen timestamps (userId → lastSeen Date)
    @Published var userLastSeenMap: [String: Date] = [:]
    
    /// Map of conversation priorities (conversationId → Priority) - Story 5.3
    @Published var conversationPriorityMap: [String: Priority] = [:]
    
    // MARK: - Private Properties
    
    private let firestoreService: FirestoreService
    private let authService: AuthService
    private let presenceService = PresenceService()
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ConversationListViewModel")
    private let aiBackendService = AIBackendService.shared  // Story 5.3: For analyzing messages
    
    /// In-memory cache for user display names to avoid repeated fetches
    private var userCache: [String: User] = [:]
    
    /// Active presence listeners (userId → DatabaseHandle) for visible conversation rows
    nonisolated(unsafe) private var activePresenceListeners: [String: DatabaseHandle] = [:]
    
    /// Active priority listeners (conversationId → Task) for priority calculation - Story 5.3
    nonisolated(unsafe) private var activePriorityListeners: [String: Task<Void, Never>] = [:]
    
    /// Track which messages we've already analyzed (to avoid re-analyzing) - Story 5.3
    nonisolated(unsafe) private var analyzedMessageIds = Set<String>()
    
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
                    
                    // Calculate initial unread counts for all conversations
                    await calculateInitialUnreadCounts(for: conversations)
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
    
    // MARK: - Presence Tracking
    
    /// Start listening to presence for a specific user (called when conversation row appears)
    /// Only tracks presence for 1:1 conversations (not groups)
    func startPresenceListener(for userId: String) {
        // Skip if already listening
        guard activePresenceListeners[userId] == nil else {
            logger.debug("Already listening to presence for user \(userId)")
            return
        }
        
        logger.info("Starting presence listener for user \(userId)")
        
        let handle = presenceService.observePresence(userId: userId) { [weak self] isOnline, lastSeen in
            Task { @MainActor [weak self] in
                self?.userPresenceMap[userId] = isOnline
                self?.userLastSeenMap[userId] = lastSeen
                self?.logger.debug("Presence updated: \(userId) is \(isOnline ? "online" : "offline")")
            }
        }
        
        activePresenceListeners[userId] = handle
    }
    
    /// Stop listening to presence for a specific user (called when conversation row disappears)
    func stopPresenceListener(for userId: String) {
        guard let handle = activePresenceListeners[userId] else {
            return
        }
        
        logger.info("Stopping presence listener for user \(userId)")
        
        presenceService.stopObservingPresence(userId: userId, handle: handle)
        activePresenceListeners.removeValue(forKey: userId)
        userPresenceMap.removeValue(forKey: userId)
        userLastSeenMap.removeValue(forKey: userId)
    }
    
    /// Stop all presence listeners (cleanup)
    private func stopAllPresenceListeners() {
        logger.info("Stopping all presence listeners (\(self.activePresenceListeners.count) active)")
        
        for (userId, handle) in activePresenceListeners {
            presenceService.stopObservingPresence(userId: userId, handle: handle)
        }
        
        activePresenceListeners.removeAll()
        userPresenceMap.removeAll()
        userLastSeenMap.removeAll()
    }
    
    /// Calculate initial unread counts for all conversations (Story 5.3)
    private func calculateInitialUnreadCounts(for conversations: [Conversation]) async {
        guard let currentUserId = authService.currentUser?.userId else {
            return
        }
        
        // Calculate unread counts for each conversation
        for conversation in conversations {
            Task {
                do {
                    // Fetch messages for this conversation
                    let messages = try await firestoreService.fetchMessages(conversationId: conversation.conversationId)
                    
                    // Count unread messages from others
                    let unreadCount = messages.filter { message in
                        message.senderId != currentUserId && !message.readBy.contains(currentUserId)
                    }.count
                    
                    // Update the conversation's unread count
                    await MainActor.run {
                        if let index = self.conversations.firstIndex(where: { $0.conversationId == conversation.conversationId }) {
                            var updatedConversation = self.conversations[index]
                            updatedConversation.unreadCount = unreadCount
                            self.conversations[index] = updatedConversation
                        }
                    }
                } catch {
                    logger.error("Failed to calculate unread count for \(conversation.conversationId): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Priority Tracking (Story 5.3)
    
    /// Start listening to messages for priority calculation
    /// - Parameter conversationId: Conversation to track priority for
    func startPriorityListener(for conversationId: String) {
        // Skip if already listening
        guard activePriorityListeners[conversationId] == nil else {
            return
        }
        
        guard let currentUserId = authService.currentUser?.userId else {
            return
        }
        
        let task = Task {
            do {
                let messageStream = firestoreService.listenToMessages(conversationId: conversationId)
                
                for try await messages in messageStream {
                    // Filter for unread messages FROM OTHER USERS (not our own messages)
                    let unreadMessages = messages.filter { message in
                        // Only count messages from others that we haven't read
                        message.senderId != currentUserId && !message.readBy.contains(currentUserId)
                    }
                    
                    // Update conversation unreadCount
                    await MainActor.run {
                        if let index = self.conversations.firstIndex(where: { $0.conversationId == conversationId }) {
                            // Create a new conversation with updated unread count
                            // This ensures SwiftUI detects the change
                            var updatedConversation = self.conversations[index]
                            updatedConversation.unreadCount = unreadMessages.count
                            self.conversations[index] = updatedConversation
                        }
                    }
                    
                    // Analyze any unread incoming messages that don't have priority yet
                    for message in unreadMessages {
                        // Skip if already analyzed or if it's our own message
                        if analyzedMessageIds.contains(message.messageId) || message.senderId == currentUserId {
                            continue
                        }
                        
                        // Only analyze messages without priority
                        if message.priority == nil {
                            analyzedMessageIds.insert(message.messageId)
                            
                            // Analyze in background
                            Task {
                                await analyzeAndUpdateMessage(message, conversationId: conversationId)
                            }
                        }
                    }
                    
                    // Calculate highest priority of unread messages
                    let highestPriority = calculateHighestPriority(from: unreadMessages)
                    
                    await MainActor.run {
                        if let priority = highestPriority {
                            self.conversationPriorityMap[conversationId] = priority
                        } else {
                            // No priority - remove from map
                            self.conversationPriorityMap.removeValue(forKey: conversationId)
                        }
                    }
                }
            } catch {
                logger.error("Priority listener error for conversation \(conversationId): \(error.localizedDescription)")
            }
            
            // Task ended - remove from active listeners
            await MainActor.run {
                self.activePriorityListeners.removeValue(forKey: conversationId)
            }
        }
        
        activePriorityListeners[conversationId] = task
    }
    
    /// Stop listening to priority for a conversation
    /// - Parameter conversationId: Conversation to stop tracking
    func stopPriorityListener(for conversationId: String) {
        guard let task = activePriorityListeners[conversationId] else {
            return
        }
        
        logger.info("Stopping priority listener for conversation \(conversationId)")
        
        task.cancel()
        activePriorityListeners.removeValue(forKey: conversationId)
        conversationPriorityMap.removeValue(forKey: conversationId)
    }
    
    /// Calculate highest priority from messages
    /// - Parameter messages: Array of messages to check
    /// - Returns: Highest priority found (high > medium), or nil if no priority
    private func calculateHighestPriority(from messages: [Message]) -> Priority? {
        var hasHigh = false
        var hasMedium = false
        
        for message in messages {
            if let priority = message.priority {
                if priority == .high {
                    hasHigh = true
                    break // High is the highest, can return immediately
                } else if priority == .medium {
                    hasMedium = true
                }
            }
        }
        
        if hasHigh {
            return .high
        } else if hasMedium {
            return .medium
        } else {
            return nil
        }
    }
    
    /// Analyze a message with AI backend and update Firestore with detected priority
    /// - Parameters:
    ///   - message: The message to analyze
    ///   - conversationId: The conversation ID containing the message
    private func analyzeAndUpdateMessage(_ message: Message, conversationId: String) async {
        do {
            let analysis = try await aiBackendService.analyzeMessage(
                messageId: message.messageId,
                text: message.text,
                userId: message.senderId,
                conversationId: conversationId
            )
            
            // If priority detected, update Firestore
            if analysis.priority.detected {
                let priority: Priority = analysis.priority.level == "high" ? .high : .medium
                
                try await firestoreService.updateMessagePriority(
                    conversationId: conversationId,
                    messageId: message.messageId,
                    priority: priority
                )
            }
        } catch {
            // Silent failure - priority is a nice-to-have feature
            logger.debug("AI analysis failed for message \(message.messageId): \(error.localizedDescription)")
        }
    }
    
    /// Stop all priority listeners (cleanup)
    private func stopAllPriorityListeners() {
        logger.info("Stopping all priority listeners (\(self.activePriorityListeners.count) active)")
        
        for (_, task) in activePriorityListeners {
            task.cancel()
        }
        
        activePriorityListeners.removeAll()
        conversationPriorityMap.removeAll()
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cancel the listener task on cleanup
        listenerTask?.cancel()
        
        // Stop all presence listeners (direct Firebase RTDB cleanup)
        for (userId, handle) in activePresenceListeners {
            Database.database().reference()
                .child("users")
                .child(userId)
                .child("presence")
                .removeObserver(withHandle: handle)
        }
        
        // Stop all priority listeners (Story 5.3)
        for (_, task) in activePriorityListeners {
            task.cancel()
        }
    }
}

