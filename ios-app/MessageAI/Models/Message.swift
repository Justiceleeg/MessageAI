//
//  Message.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import Foundation

/// Priority level for message urgency detection (Story 5.3)
enum Priority: String, Codable {
    case medium
    case high
}

/// Represents a message in a 1:1 or group conversation
/// 
/// Status Values:
/// - "sending": Message is being sent (optimistic UI, not yet confirmed by Firestore)
/// - "sent": Message confirmed written to Firestore, but not yet delivered to recipient
/// - "delivered": Message delivered to recipient (recipient's app received it)
/// - "read": Message read by recipient (recipient viewed it in ChatView)
struct Message: Identifiable, Codable, Equatable {
    let id: String  // messageId for Identifiable conformance
    let messageId: String
    let senderId: String
    let text: String
    let timestamp: Date
    var status: String  // "sending", "sent", "delivered", "read"
    var readBy: [String]  // Array of userIds who have read this message
    var priority: Priority?  // NEW: Priority level for urgent messages (Story 5.3)
    
    /// Helper to determine if message was sent by current user for UI layout
    func isSentByCurrentUser(currentUserId: String) -> Bool {
        return senderId == currentUserId
    }
    
    /// Firestore coding keys
    enum CodingKeys: String, CodingKey {
        case messageId
        case senderId
        case text
        case timestamp
        case status
        case readBy
        case priority
    }
    
    init(id: String, messageId: String, senderId: String, text: String, timestamp: Date, status: String = "sending", readBy: [String] = [], priority: Priority? = nil) {
        self.id = id
        self.messageId = messageId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.priority = priority
    }
    
    /// Initialize from Firestore decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messageId = try container.decode(String.self, forKey: .messageId)
        self.id = messageId
        self.messageId = messageId
        self.senderId = try container.decode(String.self, forKey: .senderId)
        self.text = try container.decode(String.self, forKey: .text)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.status = try container.decode(String.self, forKey: .status)
        self.readBy = try container.decodeIfPresent([String].self, forKey: .readBy) ?? []
        self.priority = try container.decodeIfPresent(Priority.self, forKey: .priority)
    }
}

