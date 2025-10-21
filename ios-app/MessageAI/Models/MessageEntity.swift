//
//  MessageEntity.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import Foundation
import SwiftData

/// SwiftData entity for local message caching
@Model
final class MessageEntity {
    @Attribute(.unique) var messageId: String
    var senderId: String
    var text: String
    var timestamp: Date
    var status: String  // "sending", "sent", "delivered", "read"
    
    // Relationship to parent conversation
    var conversation: ConversationEntity?
    
    init(messageId: String, senderId: String, text: String, timestamp: Date, status: String = "sending", conversation: ConversationEntity? = nil) {
        self.messageId = messageId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.conversation = conversation
    }
    
    /// Convert from Message model to MessageEntity
    static func from(message: Message, conversation: ConversationEntity? = nil) -> MessageEntity {
        return MessageEntity(
            messageId: message.messageId,
            senderId: message.senderId,
            text: message.text,
            timestamp: message.timestamp,
            status: message.status,
            conversation: conversation
        )
    }
    
    /// Convert to Message model
    func toMessage() -> Message {
        return Message(
            id: messageId,
            messageId: messageId,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            status: status
        )
    }
}

