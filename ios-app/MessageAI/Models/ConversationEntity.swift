//
//  ConversationEntity.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation
import SwiftData

/// SwiftData entity for local conversation caching
@Model
final class ConversationEntity {
    
    // MARK: - Properties
    
    /// Unique conversation identifier (matches Firestore document ID)
    @Attribute(.unique) var conversationId: String
    
    /// Array of participant user IDs
    var participants: [String]
    
    /// Preview text of the most recent message
    var lastMessageText: String?
    
    /// Timestamp of the most recent message
    var lastMessageTimestamp: Date?
    
    /// Indicates if this is a group chat
    var isGroupChat: Bool
    
    // Note: Relationship to messages will be added in Story 2.2
    // @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    // var messages: [MessageEntity]?
    
    // MARK: - Initialization
    
    init(conversationId: String, participants: [String], lastMessageText: String? = nil, lastMessageTimestamp: Date? = nil, isGroupChat: Bool = false) {
        self.conversationId = conversationId
        self.participants = participants
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.isGroupChat = isGroupChat
    }
    
    // MARK: - Conversion Methods
    
    /// Convert to Conversation model
    func toConversation() -> Conversation {
        return Conversation(
            conversationId: conversationId,
            participants: participants,
            lastMessageText: lastMessageText,
            lastMessageTimestamp: lastMessageTimestamp,
            isGroupChat: isGroupChat
        )
    }
    
    /// Create ConversationEntity from Conversation model
    static func from(conversation: Conversation) -> ConversationEntity {
        return ConversationEntity(
            conversationId: conversation.conversationId,
            participants: conversation.participants,
            lastMessageText: conversation.lastMessageText,
            lastMessageTimestamp: conversation.lastMessageTimestamp,
            isGroupChat: conversation.isGroupChat
        )
    }
    
    /// Update entity from Conversation model
    func update(from conversation: Conversation) {
        self.participants = conversation.participants
        self.lastMessageText = conversation.lastMessageText
        self.lastMessageTimestamp = conversation.lastMessageTimestamp
        self.isGroupChat = conversation.isGroupChat
    }
}

/// Placeholder for MessageEntity (will be implemented in Story 2.2)
@Model
final class MessageEntity {
    @Attribute(.unique) var messageId: String
    var text: String
    var timestamp: Date
    var senderId: String
    
    // Note: Relationship to conversation will be added in Story 2.2
    // var conversation: ConversationEntity?
    
    init(messageId: String, text: String, timestamp: Date, senderId: String) {
        self.messageId = messageId
        self.text = text
        self.timestamp = timestamp
        self.senderId = senderId
    }
}

