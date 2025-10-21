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
    
    /// Optional name for group chats
    var groupName: String?
    
    /// Relationship to messages in this conversation
    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    var messages: [MessageEntity]?
    
    // MARK: - Initialization
    
    init(conversationId: String, participants: [String], lastMessageText: String? = nil, lastMessageTimestamp: Date? = nil, isGroupChat: Bool = false, groupName: String? = nil) {
        self.conversationId = conversationId
        self.participants = participants
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.isGroupChat = isGroupChat
        self.groupName = groupName
    }
    
    // MARK: - Conversion Methods
    
    /// Convert to Conversation model
    func toConversation() -> Conversation {
        return Conversation(
            conversationId: conversationId,
            participants: participants,
            lastMessageText: lastMessageText,
            lastMessageTimestamp: lastMessageTimestamp,
            isGroupChat: isGroupChat,
            groupName: groupName
        )
    }
    
    /// Create ConversationEntity from Conversation model
    static func from(conversation: Conversation) -> ConversationEntity {
        return ConversationEntity(
            conversationId: conversation.conversationId,
            participants: conversation.participants,
            lastMessageText: conversation.lastMessageText,
            lastMessageTimestamp: conversation.lastMessageTimestamp,
            isGroupChat: conversation.isGroupChat,
            groupName: conversation.groupName
        )
    }
    
    /// Update entity from Conversation model
    func update(from conversation: Conversation) {
        self.participants = conversation.participants
        self.lastMessageText = conversation.lastMessageText
        self.lastMessageTimestamp = conversation.lastMessageTimestamp
        self.isGroupChat = conversation.isGroupChat
        self.groupName = conversation.groupName
    }
}

