//
//  MessageEntity.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import Foundation
import SwiftData

/// SwiftData entity for local message caching
/// 
/// Status Values:
/// - "sending": Message is being sent (optimistic UI, not yet confirmed by Firestore)
/// - "sent": Message confirmed written to Firestore, but not yet delivered to recipient
/// - "delivered": Message delivered to recipient (recipient's app received it)
/// - "read": Message read by recipient (recipient viewed it in ChatView)
@Model
final class MessageEntity {
    @Attribute(.unique) var messageId: String
    var senderId: String
    var text: String
    var timestamp: Date
    var status: String  // "sending", "sent", "delivered", "read"
    var readBy: [String]  // Array of userIds who have read this message
    
    // Relationship to parent conversation
    var conversation: ConversationEntity?
    
    init(messageId: String, senderId: String, text: String, timestamp: Date, status: String = "sending", readBy: [String] = [], conversation: ConversationEntity? = nil) {
        self.messageId = messageId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
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
            readBy: message.readBy,
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
            status: status,
            readBy: readBy
        )
    }
    
    /// Computed property for display status - cached by SwiftData
    /// This avoids repeated computation in SwiftUI views
    /// Note: This is a simplified version - the full logic is in ChatViewModel
    var displayStatus: String {
        return status
    }
}

