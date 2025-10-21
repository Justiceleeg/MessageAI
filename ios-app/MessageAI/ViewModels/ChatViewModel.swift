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
    
    // MARK: - Private Properties
    
    private let otherUserId: String
    private let firestoreService: FirestoreService
    private let authService: AuthService
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ChatViewModel")
    private var messageListenerTask: Task<Void, Never>?
    
    // Computed property for participants array
    private var participants: [String] {
        guard let currentUserId = authService.currentUser?.userId else {
            return [otherUserId]
        }
        return [currentUserId, otherUserId].sorted()
    }
    
    // MARK: - Initialization
    
    init(conversationId: String?, otherUserId: String, firestoreService: FirestoreService, authService: AuthService, modelContext: ModelContext? = nil) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.firestoreService = firestoreService
        self.authService = authService
        
        // Use provided context or get from shared PersistenceController
        self.modelContext = modelContext ?? PersistenceController.shared.modelContainer.mainContext
    }
    
    // Convenience initializer with default services
    convenience init(conversationId: String?, otherUserId: String) {
        self.init(
            conversationId: conversationId,
            otherUserId: otherUserId,
            firestoreService: FirestoreService(),
            authService: AuthService.shared
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
        }
    }
    
    /// Called when view disappears - stops listening to messages
    func onDisappear() {
        logger.info("ChatView disappeared")
        stopListeningToMessages()
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
                
                for try await messages in messageStream {
                    await MainActor.run {
                        self.messages = messages
                        self.isLoading = false
                        self.logger.info("Received \(messages.count) messages from Firestore")
                        
                        // Save to SwiftData cache
                        self.saveMessagesToCache(messages)
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
    
    /// Send a message (handles both new and existing conversations)
    func sendMessage() async {
        // Validate message text
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            logger.warning("Attempted to send empty message")
            return
        }
        
        // Get current user
        guard let currentUser = authService.currentUser else {
            logger.error("No current user - cannot send message")
            errorMessage = "You must be logged in to send messages."
            return
        }
        
        isSending = true
        errorMessage = nil
        
        do {
            if let existingConversationId = conversationId {
                // Existing conversation - send message normally
                logger.info("Sending message to existing conversation: \(existingConversationId)")
                _ = try await firestoreService.sendMessage(
                    conversationId: existingConversationId,
                    senderId: currentUser.userId,
                    text: trimmedText
                )
                
            } else {
                // New conversation - create conversation with first message
                logger.info("Creating new conversation with first message")
                let result = try await firestoreService.createConversationWithMessage(
                    participants: participants,
                    senderId: currentUser.userId,
                    text: trimmedText
                )
                
                // Update conversationId and start listening
                conversationId = result.conversationId
                logger.info("New conversation created: \(result.conversationId)")
                
                // Start listening to messages now that conversation exists
                loadMessages()
            }
            
            // Clear message text after successful send
            messageText = ""
            isSending = false
            
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
            errorMessage = "Failed to send message. Please try again."
            isSending = false
        }
    }
    
    // MARK: - User Information
    
    /// Load other user's display name for navigation title
    private func loadOtherUserDisplayName() {
        Task {
            do {
                let user = try await firestoreService.fetchUser(userId: otherUserId)
                await MainActor.run {
                    self.otherUserDisplayName = user.displayName
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
    
    // MARK: - Helper Methods
    
    /// Check if message was sent by current user (for UI layout)
    func isSentByCurrentUser(message: Message) -> Bool {
        guard let currentUserId = authService.currentUser?.userId else {
            return false
        }
        return message.isSentByCurrentUser(currentUserId: currentUserId)
    }
}

