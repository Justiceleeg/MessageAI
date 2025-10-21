//
//  Message.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import Foundation

/// Represents a message in a 1:1 conversation
struct Message: Identifiable, Codable, Equatable {
    let id: String  // messageId for Identifiable conformance
    let messageId: String
    let senderId: String
    let text: String
    let timestamp: Date
    var status: String  // "sending", "sent", "delivered", "read"
    
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
    }
    
    init(id: String, messageId: String, senderId: String, text: String, timestamp: Date, status: String = "sending") {
        self.id = id
        self.messageId = messageId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.status = status
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
    }
}

