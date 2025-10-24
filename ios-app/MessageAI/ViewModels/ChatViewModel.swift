//
//  ChatViewModel.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseDatabase
import OSLog

/// ViewModel for managing chat screen state and message operations
@MainActor
final class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var conversationId: String?
    @Published var otherUserDisplayName: String = ""
    @Published var senderNames: [String: String] = [:] // Cache for sender display names (userId -> displayName)
    
    // AI Analysis (Story 5.1)
    @Published var aiSuggestions: [String: MessageAnalysisResponse] = [:] // messageId -> analysis
    @Published var dismissedAISuggestions: Set<String> = [] // messageIds where user acted on suggestion
    
    // Presence tracking (Story 3.3)
    @Published var participantPresence: [String: Bool] = [:]  // userId -> isOnline
    @Published var participantLastSeen: [String: Date] = [:]  // userId -> lastSeen Date
    
    // Typing indicators (Story 3.5)
    @Published var typingUsers: [User] = []  // Users currently typing
    
    // MARK: - Private Properties
    
    private let otherUserId: String
    private let firestoreService: FirestoreService
    private let authService: AuthService
    private let modelContext: ModelContext
    private let networkMonitor: NetworkMonitor
    private let offlineQueue: OfflineMessageQueue
    private let presenceService = PresenceService()  // Story 3.3
    private let aiBackendService = AIBackendService.shared  // Story 5.1
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ChatViewModel")
    private var messageListenerTask: Task<Void, Never>?
    private var networkObserverTask: Task<Void, Never>?
    
    // Presence tracking (Story 3.3)
    private var activePresenceListeners: [String: DatabaseHandle] = [:]  // userId -> DatabaseHandle
    
    // Group chat properties (Story 3.1)
    @Published var conversation: Conversation? // Made public for View access and read receipt tracking
    private var pendingGroupParticipants: [User]?
    private var pendingGroupName: String?
    var isGroupChat: Bool {
        conversation?.isGroupChat ?? (pendingGroupParticipants != nil)
    }
    
    // Read receipt tracking (Story 3.2)
    private var readReceiptTask: Task<Void, Never>?
    private var pendingReadMessageIds: Set<String> = []
    
    // Typing indicators (Story 3.5)
    private var typingCancellable: AnyCancellable?
    private var textDebounceTimer: Timer?
    
    // Computed property for participants array
    private var participants: [String] {
        guard let currentUserId = authService.currentUser?.userId else {
            return [otherUserId]
        }
        return [currentUserId, otherUserId].sorted()
    }
    
    // MARK: - Initialization
    
    init(conversationId: String?, otherUserId: String, firestoreService: FirestoreService, authService: AuthService, networkMonitor: NetworkMonitor, offlineQueue: OfflineMessageQueue, modelContext: ModelContext? = nil, groupParticipants: [User]? = nil, groupName: String? = nil) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.firestoreService = firestoreService
        self.authService = authService
        self.networkMonitor = networkMonitor
        self.offlineQueue = offlineQueue
        self.pendingGroupParticipants = groupParticipants
        self.pendingGroupName = groupName
        
        // Use provided context or get from shared PersistenceController
        self.modelContext = modelContext ?? PersistenceController.shared.modelContainer.mainContext
        
        // Observe network changes for offline queue processing
        startNetworkObserver()
    }
    
    // Convenience initializer with default services
    convenience init(conversationId: String?, otherUserId: String, groupParticipants: [User]? = nil, groupName: String? = nil) {
        self.init(
            conversationId: conversationId,
            otherUserId: otherUserId,
            firestoreService: FirestoreService(),
            authService: AuthService.shared,
            networkMonitor: NetworkMonitor.shared,
            offlineQueue: OfflineMessageQueue.shared,
            groupParticipants: groupParticipants,
            groupName: groupName
        )
    }
    
    // MARK: - Lifecycle Methods
    
    /// Called when view appears - starts listening to messages if conversation exists
    func onAppear() {
        logger.info("ChatView appeared for otherUserId: \(self.otherUserId)")
        loadOtherUserDisplayName()
        
        // Only start listening if we have an existing conversation
        if conversationId != nil {
            // First load cached messages for fast UI
            loadCachedMessages()
            // Then start real-time listener
            loadMessages()
            // Load conversation data for read receipts (Story 3.2)
            Task {
                await loadConversationData()
                // Mark messages as delivered AFTER conversation loads (Story 3.2)
                await markMessagesAsDeliveredAsync()
                // Start presence listening after conversation is loaded (Story 3.3)
                startPresenceListening()
                // Start typing indicator listening (Story 3.5)
                startTypingListening()
                // Mark all visible messages as read (Story 4.1 - catch messages already on screen)
                markAllVisibleMessagesAsRead()
            }
        } else {
            // For new conversations, start presence listening immediately (Story 3.3)
            startPresenceListening()
        }
    }
    
    /// Called when view disappears - stops listening to messages
    func onDisappear() {
        logger.info("ChatView disappeared")
        stopListeningToMessages()
        stopNetworkObserver()
        stopPresenceListening()  // Story 3.3
        stopTypingListening()  // Story 3.5
        
        // Stop typing indicator when leaving chat
        if let conversationId = conversationId {
            presenceService.stopTyping(in: conversationId)
        }
    }
    
    // MARK: - Network Monitoring
    
    /// Start observing network changes to process offline queue
    private func startNetworkObserver() {
        logger.info("Starting network observer")
        
        networkObserverTask = Task { @MainActor in
            var previousConnectionState = networkMonitor.isConnected
            
            // Monitor isConnected changes
            for await isConnected in networkMonitor.$isConnected.values {
                // Only process queue when transitioning from offline to online
                if !previousConnectionState && isConnected {
                    logger.info("Network reconnected - processing offline queue")
                    await processOfflineQueue()
                }
                previousConnectionState = isConnected
            }
        }
    }
    
    /// Stop observing network changes
    private func stopNetworkObserver() {
        logger.info("Stopping network observer")
        networkObserverTask?.cancel()
        networkObserverTask = nil
    }
    
    // MARK: - Message Loading
    
    /// Load cached messages from SwiftData for instant UI (offline support)
    private func loadCachedMessages() {
        guard let conversationId = conversationId else { return }
        
        logger.info("Loading cached messages from SwiftData")
        
        Task {
            do {
                // Fetch conversation entity to get messages
                let conversationPredicate = #Predicate<ConversationEntity> { conv in
                    conv.conversationId == conversationId
                }
                let conversationDescriptor = FetchDescriptor<ConversationEntity>(predicate: conversationPredicate)
                let conversations = try modelContext.fetch(conversationDescriptor)
                
                guard conversations.first != nil else {
                    logger.info("No cached conversation found")
                    return
                }
                
                // Fetch messages for this conversation
                let messagePredicate = #Predicate<MessageEntity> { msg in
                    msg.conversation?.conversationId == conversationId
                }
                var messageDescriptor = FetchDescriptor<MessageEntity>(predicate: messagePredicate)
                messageDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
                
                let cachedMessageEntities = try modelContext.fetch(messageDescriptor)
                let cachedMessages = cachedMessageEntities.map { $0.toMessage() }
                
                await MainActor.run {
                    if !cachedMessages.isEmpty {
                        self.messages = cachedMessages
                        self.logger.info("Loaded \(cachedMessages.count) cached messages")
                    }
                }
            } catch {
                logger.error("Failed to load cached messages: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start listening to messages in the conversation (real-time)
    func loadMessages() {
        guard let conversationId = conversationId else {
            logger.info("No conversationId - skipping message listener (new conversation)")
            return
        }
        
        // Cancel existing listener if any
        stopListeningToMessages()
        
        logger.info("Starting message listener for conversationId: \(conversationId)")
        isLoading = true
        
        messageListenerTask = Task {
            do {
                let messageStream = firestoreService.listenToMessages(conversationId: conversationId)
                
                for try await firestoreMessages in messageStream {
                    await MainActor.run {
                        // Merge Firestore messages with local optimistic messages
                        self.mergeMessages(firestoreMessages: firestoreMessages)
                        self.isLoading = false
                        self.logger.info("Received \(firestoreMessages.count) messages from Firestore")
                        
                        // Save to SwiftData cache
                        self.saveMessagesToCache(firestoreMessages)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    self.logger.error("Message listener error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Merge Firestore messages with local optimistic messages
    /// This prevents the listener from overwriting optimistic messages before Firestore confirms them
    private func mergeMessages(firestoreMessages: [Message]) {
        logger.info("🔄 MERGE MESSAGES CALLED with \(firestoreMessages.count) messages from Firestore")
        // Start with Firestore messages (source of truth)
        var mergedMessages = firestoreMessages
        
        // Get message IDs from Firestore for quick lookup
        let firestoreMessageIds = Set(firestoreMessages.map { $0.messageId })
        
        // Find local optimistic messages that aren't in Firestore yet
        let localOptimisticMessages = self.messages.filter { localMessage in
            // Only keep if:
            // 1. Not in Firestore yet (messageId not found)
            // 2. Status is still "sending" or "failed" (local only)
            !firestoreMessageIds.contains(localMessage.messageId) && 
            (localMessage.status == "sending" || localMessage.status == "failed")
        }
        
        // Add unconfirmed local messages
        mergedMessages.append(contentsOf: localOptimisticMessages)
        
        // Sort by timestamp (chronological order)
        mergedMessages.sort { $0.timestamp < $1.timestamp }
        
        // Deduplicate by messageId (just in case) - keep Firestore version
        var seenIds = Set<String>()
        mergedMessages = mergedMessages.filter { message in
            if seenIds.contains(message.messageId) {
                logger.debug("Duplicate messageId found during merge, keeping Firestore version: \(message.messageId)")
                return false // Already have this message
            }
            seenIds.insert(message.messageId)
            return true
        }
        
        // Update the array
        self.messages = mergedMessages
        
        logger.debug("Merged messages: \(firestoreMessages.count) from Firestore + \(localOptimisticMessages.count) local optimistic = \(mergedMessages.count) total")
        
        // Mark any new undelivered messages as delivered (Story 3.2)
        Task {
            await markMessagesAsDeliveredAsync()
            // Also mark visible messages as read (Story 4.1 - catch new messages)
            markAllVisibleMessagesAsRead()
        }
    }
    
    /// Save messages to SwiftData cache (on main actor)
    private func saveMessagesToCache(_ messages: [Message]) {
        guard let conversationId = conversationId else { return }
        
        Task { @MainActor in
            do {
                // Fetch conversation entity
                let conversationPredicate = #Predicate<ConversationEntity> { conv in
                    conv.conversationId == conversationId
                }
                let conversationDescriptor = FetchDescriptor<ConversationEntity>(predicate: conversationPredicate)
                let conversations = try modelContext.fetch(conversationDescriptor)
                
                guard let conversation = conversations.first else {
                    logger.warning("Conversation not found in cache, cannot save messages")
                    return
                }
                
                // Get existing message IDs to avoid duplicates
                let messagePredicate = #Predicate<MessageEntity> { msg in
                    msg.conversation?.conversationId == conversationId
                }
                let messageDescriptor = FetchDescriptor<MessageEntity>(predicate: messagePredicate)
                let existingMessages = try modelContext.fetch(messageDescriptor)
                let existingMessageIds = Set(existingMessages.map { $0.messageId })
                
                // Insert new messages
                for message in messages {
                    if !existingMessageIds.contains(message.messageId) {
                        let messageEntity = MessageEntity.from(message: message, conversation: conversation)
                        modelContext.insert(messageEntity)
                    }
                }
                
                // Save context
                try modelContext.save()
                logger.info("Saved \(messages.count) messages to cache")
                
            } catch {
                logger.error("Failed to save messages to cache: \(error.localizedDescription)")
            }
        }
    }
    
    /// Stop listening to messages
    private func stopListeningToMessages() {
        messageListenerTask?.cancel()
        messageListenerTask = nil
        logger.info("Stopped message listener")
    }
    
    // MARK: - Sending Messages
    
    /// Send a message with optimistic UI (handles both new and existing conversations)
    func sendMessage() async {
        // Capture and clear message text on main actor
        let text = await MainActor.run { () -> String in
            let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return ""
            }
            // Clear immediately after capturing
            messageText = ""
            errorMessage = nil
            return trimmedText
        }
        
        // Return early if empty
        guard !text.isEmpty else {
            logger.warning("Attempted to send empty message")
            return
        }
        
        // Get current user
        guard let currentUser = authService.currentUser else {
            logger.error("No current user - cannot send message")
            await MainActor.run {
                errorMessage = "You must be logged in to send messages."
            }
            return
        }
        
        // Stop typing indicator when sending message (Story 3.5)
        stopTypingOnSend()
        
        // 1. Create optimistic message and add to UI immediately
        let messageId = UUID().uuidString
        let optimisticMessage = Message(
            id: messageId,
            messageId: messageId,
            senderId: currentUser.userId,
            text: text,
            timestamp: Date(),
            status: "sending"  // Optimistic status
        )
        
        // Add message to UI immediately (optimistic update)
        messages.append(optimisticMessage)
        logger.info("Added optimistic message to UI: \(messageId)")
        
        // Save optimistic message to cache immediately
        await saveOptimisticMessageToCache(optimisticMessage)
        
        // 2. Attempt to send to Firestore
        do {
            if let existingConversationId = conversationId {
                // Existing conversation - send message normally
                logger.info("Sending message to existing conversation: \(existingConversationId)")
                _ = try await firestoreService.sendMessage(
                    conversationId: existingConversationId,
                    senderId: currentUser.userId,
                    text: text,
                    messageId: messageId  // Pass our optimistic messageId
                )
                
                // Don't update status manually - let Firestore listener handle it
                // The mergeMessages() will replace optimistic message when Firestore confirms
                logger.info("Message sent to Firestore successfully: \(messageId)")
                
                // Analyze message for AI features in background (Story 5.1)
                analyzeMessageForAI(optimisticMessage)
                
            } else if let groupParticipants = pendingGroupParticipants {
                // New group conversation - create group first, then send message
                logger.info("Creating new group conversation with \(groupParticipants.count) participants")
                
                // Build participant ID list (include current user)
                var participantIds = groupParticipants.map { $0.userId }
                participantIds.append(currentUser.userId)
                
                // Create group conversation
                let newConversationId = try await firestoreService.createGroupConversation(
                    participants: participantIds,
                    groupName: pendingGroupName
                )
                
                // Update conversationId
                conversationId = newConversationId
                logger.info("New group conversation created: \(newConversationId)")
                
                // Clear pending group data (no longer needed)
                pendingGroupParticipants = nil
                pendingGroupName = nil
                
                // Send the first message
                _ = try await firestoreService.sendMessage(
                    conversationId: newConversationId,
                    senderId: currentUser.userId,
                    text: text,
                    messageId: messageId
                )
                
                // Start listening to messages
                loadMessages()
                
                // Start typing listener now that we have a conversationId (Story 3.5)
                startTypingListening()
                
                // Analyze message for AI features in background (Story 5.1)
                analyzeMessageForAI(optimisticMessage)
                
            } else {
                // New 1:1 conversation - create conversation with first message
                logger.info("Creating new 1:1 conversation with first message")
                let result = try await firestoreService.createConversationWithMessage(
                    participants: participants,
                    senderId: currentUser.userId,
                    text: text,
                    messageId: messageId  // Pass our optimistic messageId
                )
                
                // Update conversationId
                conversationId = result.conversationId
                logger.info("New conversation created: \(result.conversationId)")
                
                // Start listening to messages now that conversation exists
                // The listener will replace the optimistic message with the confirmed one
                loadMessages()
                
                // Start typing listener now that we have a conversationId (Story 3.5)
                startTypingListening()
                
                // Analyze message for AI features in background (Story 5.1)
                analyzeMessageForAI(optimisticMessage)
            }
            
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
            
            // Check if it's a network error
            if isNetworkError(error) {
                logger.warning("Network error detected - enqueueing message to offline queue")
                
                // Add to offline queue (requires conversationId)
                if let conversationId = conversationId {
                    let queuedMessage = OfflineMessageQueue.QueuedMessage(
                        messageId: messageId,
                        conversationId: conversationId,
                        senderId: currentUser.userId,
                        text: text,
                        timestamp: optimisticMessage.timestamp,
                        retryCount: 0
                    )
                    offlineQueue.enqueue(queuedMessage)
                    
                    // Keep status as "sending" - will retry automatically
                    logger.info("Message queued for retry when network reconnects")
                } else {
                    // New conversation case - can't queue without conversationId
                    updateMessageStatus(messageId: messageId, status: "failed")
                    errorMessage = "Cannot send message while offline in a new conversation. Please try again when connected."
                }
            } else {
                // Other error (permissions, validation, etc.)
                updateMessageStatus(messageId: messageId, status: "failed")
                errorMessage = "Failed to send message. Tap to retry."
            }
        }
    }
    
    /// Retry sending a failed message
    func retryMessage(_ message: Message) async {
        logger.info("Retrying failed message: \(message.messageId)")
        
        guard let currentUser = authService.currentUser else {
            logger.error("No current user - cannot retry message")
            return
        }
        
        guard let conversationId = conversationId else {
            logger.error("No conversationId - cannot retry message")
            return
        }
        
        // Update status to "sending" to show retry in progress
        updateMessageStatus(messageId: message.messageId, status: "sending")
        
        do {
            _ = try await firestoreService.sendMessage(
                conversationId: conversationId,
                senderId: currentUser.userId,
                text: message.text,
                messageId: message.messageId  // Preserve the original messageId
            )
            
            // Success - Firestore listener will update status to "sent"
            // The merge will replace the local "sending" message with confirmed one
            logger.info("Message retry successful: \(message.messageId)")
            
        } catch {
            logger.error("Message retry failed: \(error.localizedDescription)")
            
            // Check if network error
            if isNetworkError(error) {
                // Add to offline queue
                let queuedMessage = OfflineMessageQueue.QueuedMessage(
                    messageId: message.messageId,
                    conversationId: conversationId,
                    senderId: currentUser.userId,
                    text: message.text,
                    timestamp: message.timestamp,
                    retryCount: 0
                )
                offlineQueue.enqueue(queuedMessage)
                logger.info("Message re-queued for retry")
            } else {
                // Update status back to "failed"
                updateMessageStatus(messageId: message.messageId, status: "failed")
                errorMessage = "Failed to retry message. Please try again."
            }
        }
    }
    
    /// Delete a failed message
    func deleteMessage(_ message: Message) {
        logger.info("Deleting failed message: \(message.messageId)")
        messages.removeAll { $0.messageId == message.messageId }
        
        // Remove from offline queue if present
        offlineQueue.remove(messageId: message.messageId)
        
        // Remove from cache
        Task {
            await deleteMessageFromCache(messageId: message.messageId)
        }
    }
    
    // MARK: - User Information
    
    /// Load conversation data and display name/title for navigation
    private func loadOtherUserDisplayName() {
        Task {
            // Load conversation data if we have a conversationId
            if let conversationId = conversationId {
                await loadConversationData(conversationId: conversationId)
            }
            
            // For pending groups (lazy creation), prefetch participant names
            if let groupParticipants = pendingGroupParticipants {
                await prefetchPendingGroupNames(participants: groupParticipants)
            }
            
            // For group chats, use group display logic
            if isGroupChat {
                await MainActor.run {
                    self.otherUserDisplayName = getGroupTitle()
                }
            } else {
                // For 1:1 chats, load the other user's name
                do {
                    let user = try await firestoreService.fetchUser(userId: otherUserId)
                    await MainActor.run {
                        self.otherUserDisplayName = user.displayName
                        self.senderNames[otherUserId] = user.displayName
                        self.logger.info("Loaded display name: \(user.displayName)")
                    }
                } catch {
                    await MainActor.run {
                        self.otherUserDisplayName = "Unknown User"
                        self.logger.error("Failed to load other user display name: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Prefetch names for pending group participants
    private func prefetchPendingGroupNames(participants: [User]) async {
        // Cache the display names from User objects
        await MainActor.run {
            for participant in participants {
                self.senderNames[participant.userId] = participant.displayName
            }
            
            // Update title now that we have names
            if isGroupChat {
                self.otherUserDisplayName = getGroupTitle()
            }
        }
    }
    
    /// Load conversation data from Firestore
    private func loadConversationData(conversationId: String) async {
        do {
            // Fetch conversation document
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            
            await MainActor.run {
                self.conversation = conversation
                self.logger.info("Loaded conversation data: isGroupChat=\(conversation.isGroupChat)")
            }
            
            // Prefetch sender names for group chats
            if conversation.isGroupChat {
                await prefetchSenderNames(participants: conversation.participants)
            }
        } catch {
            self.logger.error("Failed to load conversation data: \(error.localizedDescription)")
        }
    }
    
    /// Get formatted group title
    private func getGroupTitle() -> String {
        // Check for pending group name first (lazy creation)
        if let pendingName = pendingGroupName, !pendingName.isEmpty {
            return pendingName
        }
        
        // Check for existing conversation
        if let conversation = conversation {
            // If group has a name, use it
            if let groupName = conversation.groupName, !groupName.isEmpty {
                return groupName
            }
            
            // Otherwise, format participant names
            guard let currentUserId = authService.currentUser?.userId else {
                return "Group Chat"
            }
            
            let otherParticipants = conversation.participants.filter { $0 != currentUserId }
            let names = otherParticipants.compactMap { senderNames[$0] }
            
            if names.isEmpty {
                return "Group Chat"
            } else if names.count <= 3 {
                return names.joined(separator: ", ")
            } else {
                let shown = names.prefix(2).joined(separator: ", ")
                return "\(shown), +\(names.count - 2) more"
            }
        }
        
        // Pending group - format participant names
        if let pendingParticipants = pendingGroupParticipants {
            let names = pendingParticipants.compactMap { senderNames[$0.userId] }
            
            if names.isEmpty {
                return "New Group"
            } else if names.count <= 3 {
                return names.joined(separator: ", ")
            } else {
                let shown = names.prefix(2).joined(separator: ", ")
                return "\(shown), +\(names.count - 2) more"
            }
        }
        
        return "Group Chat"
    }
    
    /// Prefetch sender names for all participants
    private func prefetchSenderNames(participants: [String]) async {
        guard let currentUserId = authService.currentUser?.userId else { return }
        
        // Filter out current user
        let otherParticipants = participants.filter { $0 != currentUserId }
        
        for userId in otherParticipants {
            // Skip if already cached
            if senderNames[userId] != nil { continue }
            
            do {
                let user = try await firestoreService.fetchUserProfile(userId: userId)
                await MainActor.run {
                    self.senderNames[userId] = user.displayName
                    self.logger.info("Cached sender name: \(user.displayName) for userId: \(userId)")
                }
            } catch {
                self.logger.error("Failed to fetch sender name for userId \(userId): \(error.localizedDescription)")
                // Cache placeholder to avoid repeated failures
                await MainActor.run {
                    self.senderNames[userId] = "Unknown"
                }
            }
        }
        
        // Update title after names are loaded
        if isGroupChat {
            await MainActor.run {
                self.otherUserDisplayName = getGroupTitle()
            }
        }
    }
    
    /// Get sender display name for a userId (used by MessageBubbleView)
    func getSenderDisplayName(userId: String) -> String {
        if let cached = senderNames[userId] {
            return cached
        }
        
        // Fetch in background
        Task {
            do {
                let user = try await firestoreService.fetchUserProfile(userId: userId)
                await MainActor.run {
                    self.senderNames[userId] = user.displayName
                    // Trigger UI update
                    self.objectWillChange.send()
                }
            } catch {
                self.logger.error("Failed to fetch sender name: \(error.localizedDescription)")
            }
        }
        
        return "Loading..."
    }
    
    // MARK: - Helper Methods
    
    /// Check if message was sent by current user (for UI layout)
    func isSentByCurrentUser(message: Message) -> Bool {
        guard let currentUserId = authService.currentUser?.userId else {
            return false
        }
        return message.isSentByCurrentUser(currentUserId: currentUserId)
    }
    
    /// Update message status in the messages array
    private func updateMessageStatus(messageId: String, status: String) {
        if let index = messages.firstIndex(where: { $0.messageId == messageId }) {
            messages[index].status = status
            logger.debug("Updated message \(messageId) status to \(status)")
            
            // Update in cache as well
            Task {
                await updateMessageStatusInCache(messageId: messageId, status: status)
            }
        }
    }
    
    /// Save optimistic message to SwiftData cache immediately
    private func saveOptimisticMessageToCache(_ message: Message) async {
        guard let conversationId = conversationId else {
            logger.warning("No conversationId - cannot save optimistic message to cache")
            return
        }
        
        do {
            // Fetch conversation entity
            let conversationPredicate = #Predicate<ConversationEntity> { conv in
                conv.conversationId == conversationId
            }
            let conversationDescriptor = FetchDescriptor<ConversationEntity>(predicate: conversationPredicate)
            let conversations = try modelContext.fetch(conversationDescriptor)
            
            guard let conversation = conversations.first else {
                logger.warning("Conversation not found in cache, cannot save optimistic message")
                return
            }
            
            // Create message entity
            let messageEntity = MessageEntity.from(message: message, conversation: conversation)
            modelContext.insert(messageEntity)
            
            // Save context
            try modelContext.save()
            logger.debug("Saved optimistic message to cache: \(message.messageId)")
            
        } catch {
            logger.error("Failed to save optimistic message to cache: \(error.localizedDescription)")
        }
    }
    
    /// Update message status in SwiftData cache
    private func updateMessageStatusInCache(messageId: String, status: String) async {
        do {
            // Fetch message entity
            let messagePredicate = #Predicate<MessageEntity> { msg in
                msg.messageId == messageId
            }
            let messageDescriptor = FetchDescriptor<MessageEntity>(predicate: messagePredicate)
            let messages = try modelContext.fetch(messageDescriptor)
            
            if let messageEntity = messages.first {
                messageEntity.status = status
                try modelContext.save()
                logger.debug("Updated message status in cache: \(messageId) -> \(status)")
            }
            
        } catch {
            logger.error("Failed to update message status in cache: \(error.localizedDescription)")
        }
    }
    
    /// Delete message from SwiftData cache
    private func deleteMessageFromCache(messageId: String) async {
        do {
            // Fetch message entity
            let messagePredicate = #Predicate<MessageEntity> { msg in
                msg.messageId == messageId
            }
            let messageDescriptor = FetchDescriptor<MessageEntity>(predicate: messagePredicate)
            let messages = try modelContext.fetch(messageDescriptor)
            
            if let messageEntity = messages.first {
                modelContext.delete(messageEntity)
                try modelContext.save()
                logger.debug("Deleted message from cache: \(messageId)")
            }
            
        } catch {
            logger.error("Failed to delete message from cache: \(error.localizedDescription)")
        }
    }
    
    /// Process offline message queue (called when network reconnects)
    private func processOfflineQueue() async {
        guard !self.offlineQueue.isEmpty else {
            logger.info("Offline queue is empty, nothing to process")
            return
        }
        
        logger.info("Processing offline queue with \(self.offlineQueue.count) messages")
        
        let sentCount = await self.offlineQueue.processQueue { [weak self] queuedMessage in
            guard let self = self else { return }
            
            // Attempt to send the queued message with its original messageId
            _ = try await self.firestoreService.sendMessage(
                conversationId: queuedMessage.conversationId,
                senderId: queuedMessage.senderId,
                text: queuedMessage.text,
                messageId: queuedMessage.messageId  // Preserve original messageId
            )
            
            // Don't manually update status - Firestore listener will handle it
            // The merge will replace the optimistic message when confirmed
        }
        
        logger.info("Offline queue processing complete. Sent: \(sentCount) messages")
        
        // Update any messages that reached retry limit to "failed"
        for message in messages where message.status == "sending" {
            if self.offlineQueue.hasReachedRetryLimit(messageId: message.messageId) {
                updateMessageStatus(messageId: message.messageId, status: "failed")
                logger.warning("Message \(message.messageId) reached retry limit, marked as failed")
            }
        }
    }
    
    /// Check if error is a network-related error
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for NSURLError domain (network errors)
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed
            ].contains(nsError.code)
        }
        
        // Check for Firestore-specific network errors
        if nsError.domain == "FIRFirestoreErrorDomain" {
            // Firestore error codes: 14 = unavailable, 4 = deadline exceeded
            return [14, 4].contains(nsError.code)
        }
        
        return false
    }
    
    // MARK: - Read Receipt Methods (Story 3.2)
    
    /// Compute message display status based on readBy and conversation participants
    func computeMessageStatus(for message: Message) -> String {
        // Only show status for messages sent by current user
        guard let currentUserId = authService.currentUser?.userId,
              message.senderId == currentUserId else {
            return ""  // Received messages don't show status
        }
        
        logger.debug("Computing status for message \(message.messageId): rawStatus=\(message.status), readBy=\(message.readBy)")
        
        // Return status directly for sending/sent/delivered
        if message.status == "sending" {
            return "sending"
        }
        
        if message.status == "sent" {
            return "sent"
        }
        
        if message.status == "delivered" {
            return "delivered"
        }
        
        // For read status, check readBy against participants
        if message.status == "read" {
            guard let conversation = conversation else {
                logger.debug("No conversation loaded yet for message \(message.messageId)")
                return "delivered"  // Default to delivered if conversation not loaded
            }
            
            // Get other participants (exclude current user)
            let otherParticipants = conversation.participants.filter { $0 != currentUserId }
            
            logger.debug("Message \(message.messageId): otherParticipants=\(otherParticipants), readBy=\(message.readBy)")
            
            // No other participants? Just return status
            guard !otherParticipants.isEmpty else {
                return message.status
            }
            
            // Check if ANY other participant has read the message (Story 4.1 - for group chats)
            // We'll show the count badge, so just check if at least one person read it
            let anyRead = otherParticipants.contains(where: { message.readBy.contains($0) })
            
            logger.debug("Message \(message.messageId): anyRead=\(anyRead), readCount=\(message.readBy.filter { $0 != currentUserId }.count)")
            
            // Return "read" if any participant has read, otherwise return delivered
            return anyRead ? "read" : "delivered"
        }
        
        return message.status
    }
    
    /// Calculate read count for a message (Story 4.1)
    /// Returns the number of participants who have read the message (excluding sender)
    func calculateReadCount(for message: Message) -> Int {
        guard let currentUserId = authService.currentUser?.userId else {
            return 0
        }
        
        // Only count reads for messages sent by current user
        guard message.senderId == currentUserId else {
            return 0
        }
        
        // Count how many users have read (excluding current user from readBy)
        let readByOthers = message.readBy.filter { $0 != currentUserId }
        let count = readByOthers.count
        
        logger.debug("Read count for message \(message.messageId): \(count) (readBy: \(message.readBy))")
        
        return count
    }
    
    /// Check if a message should show read receipt badge (Story 4.1 UX optimization)
    /// Only show read badge on the LATEST read message, assume earlier ones are read
    func shouldShowReadReceipt(for message: Message) -> Bool {
        guard let currentUserId = authService.currentUser?.userId else {
            return false
        }
        
        // Only show for messages sent by current user
        guard message.senderId == currentUserId else {
            return false
        }
        
        // Only show for messages with "read" status
        guard computeMessageStatus(for: message) == "read" else {
            return false
        }
        
        // Find the latest read message sent by current user
        let sentMessages = messages.filter { $0.senderId == currentUserId }
        
        // Find the last message with "read" status
        if let lastReadMessage = sentMessages.last(where: { computeMessageStatus(for: $0) == "read" }) {
            // Only show read receipt on the latest read message
            return message.messageId == lastReadMessage.messageId
        }
        
        return false
    }
    
    /// Mark messages as delivered when ChatView appears (Story 3.2) - Async version
    private func markMessagesAsDeliveredAsync() async {
        guard let conversationId = conversationId,
              let currentUserId = authService.currentUser?.userId else {
            logger.warning("Cannot mark delivered - missing conversationId or currentUserId")
            return
        }
        
        // Find undelivered messages from other users
        let undeliveredMessages = messages.filter {
            $0.senderId != currentUserId && $0.status == "sent"
        }
        
        logger.info("Found \(undeliveredMessages.count) undelivered messages (total messages: \(self.messages.count))")
        
        guard !undeliveredMessages.isEmpty else {
            logger.debug("No undelivered messages to mark")
            return
        }
        
        logger.info("Marking \(undeliveredMessages.count) messages as delivered")
        
        // Mark each message as delivered sequentially
        for message in undeliveredMessages {
            do {
                logger.debug("Marking message \(message.messageId) as delivered")
                try await firestoreService.markMessageAsDelivered(
                    conversationId: conversationId,
                    messageId: message.messageId,
                    userId: currentUserId
                )
                logger.debug("Successfully marked message \(message.messageId) as delivered")
            } catch {
                logger.error("Failed to mark message as delivered: \(error.localizedDescription)")
            }
        }
        
        // Small delay to ensure Firestore updates propagate before read receipts
        try? await Task.sleep(for: .milliseconds(200))
        logger.info("Delivered status updates complete, read receipts can now fire")
    }
    
    /// Mark a message as read when it becomes visible (Story 3.2)
    func markMessageAsReadIfVisible(messageId: String) -> Bool {
        guard let conversationId = conversationId,
              let currentUserId = authService.currentUser?.userId else {
            logger.warning("Cannot mark read - missing conversationId or currentUserId")
            return false
        }
        
        // Find the message
        guard let message = messages.first(where: { $0.id == messageId }) else {
            logger.debug("Message \(messageId) not found in messages array")
            return false
        }
        
        // Only mark messages from other users
        guard message.senderId != currentUserId else {
            logger.debug("Skipping own message \(messageId)")
            return false
        }
        
        // Only mark if not already read by current user
        guard !message.readBy.contains(currentUserId) else {
            logger.debug("Message \(messageId) already read by current user")
            return false
        }
        
        // Skip if message is still in "sending" status only
        // For "sent" messages, we can mark as read immediately if user is viewing (Story 4.1 optimization)
        if message.status == "sending" {
            logger.debug("Message \(messageId) still sending, skipping read receipt for now")
            return false
        }
        
        logger.debug("Adding message \(messageId) to pending read queue (current status: \(message.status))")
        
        // Add to pending set for batching
        pendingReadMessageIds.insert(messageId)
        
        // Cancel existing task
        readReceiptTask?.cancel()
        
        // Schedule batch update after throttle delay (300ms for near-instant read receipts when both users are active)
        readReceiptTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(300))
                
                guard !pendingReadMessageIds.isEmpty else { 
                    logger.debug("No pending messages to mark as read")
                    return 
                }
                
                let messageIdsToMark = Array(pendingReadMessageIds)
                pendingReadMessageIds.removeAll()
                
                logger.info("📝 Batch marking \(messageIdsToMark.count) messages as read: \(messageIdsToMark.prefix(3))...")
                
                try await firestoreService.batchMarkMessagesAsRead(
                    conversationId: conversationId,
                    messageIds: messageIdsToMark,
                    userId: currentUserId
                )
                
                logger.info("✅ Successfully batch marked \(messageIdsToMark.count) messages as read")
                
            } catch is CancellationError {
                // Task was cancelled, this is expected
                logger.debug("Read receipt task cancelled")
            } catch {
                logger.error("❌ Failed to batch mark messages as read: \(error.localizedDescription)")
            }
        }
        
        return true  // Message was queued to be marked as read
    }
    
    /// Mark all currently visible messages as read (Story 4.1 - fix for messages already on screen)
    /// Call this when chat view appears to catch messages that are already displayed
    func markAllVisibleMessagesAsRead() {
        guard let currentUserId = authService.currentUser?.userId else {
            logger.warning("Cannot mark messages as read - no current user")
            return
        }
        
        logger.info("📖 Marking all visible messages as read (total: \(self.messages.count))")
        
        var markedCount = 0
        var skippedOwnMessages = 0
        var skippedAlreadyRead = 0
        var skippedSending = 0
        
        // Mark each message that should be read
        for message in self.messages {
            // Check skip reasons
            if message.senderId == currentUserId {
                skippedOwnMessages += 1
                continue
            }
            if message.readBy.contains(currentUserId) {
                skippedAlreadyRead += 1
                continue
            }
            if message.status == "sending" {
                skippedSending += 1
                continue
            }
            
            let wasMarked = markMessageAsReadIfVisible(messageId: message.id)
            if wasMarked {
                markedCount += 1
            }
        }
        
        logger.info("📖 Results: marked=\(markedCount), skipped_own=\(skippedOwnMessages), skipped_already_read=\(skippedAlreadyRead), skipped_sending=\(skippedSending), total=\(self.messages.count)")
    }
    
    /// Load conversation data for read receipt computation
    private func loadConversationData() async {
        guard let conversationId = conversationId else { return }
        
        do {
            let conversation = try await firestoreService.fetchConversation(conversationId: conversationId)
            
            await MainActor.run {
                self.conversation = conversation
                logger.info("Loaded conversation data with \(conversation.participants.count) participants")
            }
            
        } catch {
            logger.error("Failed to load conversation data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Presence Tracking (Story 3.3)
    
    /// Start listening to presence for all participants
    func startPresenceListening() {
        guard let currentUserId = authService.currentUser?.userId else {
            logger.warning("Cannot start presence listening: No authenticated user")
            return
        }
        
        // For 1:1 chats: listen to other user only
        // For group chats: listen to all participants
        let participantsToTrack: [String]
        if isGroupChat, let conversation = conversation {
            // Group chat: track all participants except current user
            participantsToTrack = conversation.participants.filter { $0 != currentUserId }
        } else {
            // 1:1 chat: track the other user only
            participantsToTrack = [otherUserId]
        }
        
        logger.info("Starting presence listeners for \(participantsToTrack.count) participants")
        
        for userId in participantsToTrack {
            // Skip if already listening
            guard activePresenceListeners[userId] == nil else {
                logger.debug("Already listening to presence for user \(userId)")
                continue
            }
            
            let handle = presenceService.observePresence(userId: userId) { [weak self] isOnline, lastSeen in
                Task { @MainActor [weak self] in
                    self?.participantPresence[userId] = isOnline
                    self?.participantLastSeen[userId] = lastSeen
                    self?.logger.debug("Presence updated: \(userId) is \(isOnline ? "online" : "offline")")
                }
            }
            
            activePresenceListeners[userId] = handle
        }
    }
    
    /// Stop all presence listeners (cleanup)
    func stopPresenceListening() {
        logger.info("Stopping all presence listeners (\(self.activePresenceListeners.count) active)")
        
        for (userId, handle) in activePresenceListeners {
            presenceService.stopObservingPresence(userId: userId, handle: handle)
        }
        
        activePresenceListeners.removeAll()
        participantPresence.removeAll()
        participantLastSeen.removeAll()
    }
    
    /// Format last seen date into human-readable string
    /// Returns "Online", "Last seen 5m ago", "Last seen 2h ago", "Last seen yesterday"
    func formatLastSeen(userId: String) -> String {
        // Check if user is online
        if participantPresence[userId] == true {
            return "Online"
        }
        
        // Get last seen date
        guard let lastSeen = participantLastSeen[userId] else {
            return "Offline"
        }
        
        let interval = Date().timeIntervalSince(lastSeen)
        
        if interval < 60 {
            return "Last seen just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Last seen \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Last seen \(hours)h ago"
        } else if interval < 172800 {  // Less than 2 days
            return "Last seen yesterday"
        } else {
            let days = Int(interval / 86400)
            return "Last seen \(days)d ago"
        }
    }
    
    // MARK: - Typing Indicators (Story 3.5)
    
    /// Start listening to typing users in the conversation
    func startTypingListening() {
        guard let conversationId = conversationId else {
            logger.info("No conversationId - skipping typing listener")
            return
        }
        
        logger.info("Starting typing indicator listener for conversation: \(conversationId)")
        
        typingCancellable = presenceService.observeTypingUsers(in: conversationId)
            .sink { [weak self] typingUserIds in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // Fetch User objects for the typing users
                    var users: [User] = []
                    for userId in typingUserIds {
                        do {
                            let user = try await self.firestoreService.fetchUser(userId: userId)
                            users.append(user)
                        } catch {
                            self.logger.error("Failed to fetch typing user \(userId): \(error.localizedDescription)")
                        }
                    }
                    
                    self.typingUsers = users
                    self.logger.debug("Updated typing users: \(users.map { $0.displayName })")
                }
            }
    }
    
    /// Stop listening to typing users
    func stopTypingListening() {
        logger.info("Stopping typing indicator listener")
        typingCancellable?.cancel()
        typingCancellable = nil
        typingUsers.removeAll()
    }
    
    /// Handle typing state change when messageText changes
    func handleTypingChange(oldValue: String, newValue: String) {
        guard let conversationId = conversationId else { return }
        
        // Cancel existing debounce timer
        textDebounceTimer?.invalidate()
        
        if newValue.isEmpty {
            // Stopped typing
            presenceService.stopTyping(in: conversationId)
        } else if oldValue.isEmpty {
            // Started typing
            presenceService.startTyping(in: conversationId)
        } else {
            // Continue typing - the PresenceService will handle throttling and auto-stop
            presenceService.startTyping(in: conversationId)
        }
    }
    
    /// Stop typing when message is sent
    func stopTypingOnSend() {
        guard let conversationId = conversationId else { return }
        presenceService.stopTyping(in: conversationId)
    }
    
    // MARK: - AI Analysis (Story 5.1)
    
    /// Analyze a message for events, reminders, decisions, etc.
    /// This happens in the background after the message is sent
    /// Analyze message for AI features (Story 5.1)
    /// - Parameter message: The message to analyze
    func analyzeMessageForAI(_ message: Message) {
        guard let currentUser = authService.currentUser else { return }
        guard let conversationId = conversationId else { return }
        
        // Run analysis in background task
        Task {
            do {
                let analysis = try await aiBackendService.analyzeMessage(
                    messageId: message.messageId,
                    text: message.text,
                    userId: currentUser.userId,
                    conversationId: conversationId,
                    timestamp: message.timestamp,  // Pass message timestamp for accurate date parsing
                    userCalendar: nil  // TODO: Pass user's calendar in future story
                )
                
                // Update UI with analysis results (for calendar/reminder/decision suggestions)
                await MainActor.run {
                    self.aiSuggestions[message.messageId] = analysis
                }
                
            } catch {
                // Silent failure - don't disrupt user experience
                logger.debug("AI analysis failed for message \(message.messageId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Dismiss AI suggestion after user acts on it
    /// - Parameter messageId: The message ID whose suggestion should be dismissed
    func dismissAISuggestion(for messageId: String) {
        dismissedAISuggestions.insert(messageId)
        logger.info("Dismissed AI suggestion for message: \(messageId)")
    }
}

