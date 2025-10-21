//
//  Conversation.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation
import FirebaseFirestore

/// Conversation model matching Firestore schema
struct Conversation: Identifiable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the conversation
    var id: String { conversationId }
    
    /// Conversation's unique identifier (Firestore document ID)
    let conversationId: String
    
    /// Array of participant user IDs
    let participants: [String]
    
    /// Preview text of the most recent message
    var lastMessageText: String?
    
    /// Timestamp of the most recent message
    var lastMessageTimestamp: Date?
    
    /// Indicates if this is a group chat (more than 2 participants)
    let isGroupChat: Bool
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case conversationId
        case participants
        case lastMessageText
        case lastMessageTimestamp
        case isGroupChat
    }
    
    // MARK: - Initialization
    
    init(conversationId: String, participants: [String], lastMessageText: String? = nil, lastMessageTimestamp: Date? = nil, isGroupChat: Bool = false) {
        self.conversationId = conversationId
        self.participants = participants
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.isGroupChat = isGroupChat
    }
    
    // MARK: - Helper Methods
    
    /// Returns the other participant's ID in a 1:1 chat
    /// - Parameter currentUserId: The current user's ID
    /// - Returns: The other user's ID, or nil if not found or if group chat
    func otherParticipantId(currentUserId: String) -> String? {
        guard !isGroupChat else { return nil }
        return participants.first { $0 != currentUserId }
    }
    
    // MARK: - Firestore Conversion
    
    /// Initialize from Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let participants = data["participants"] as? [String],
              let isGroupChat = data["isGroupChat"] as? Bool else {
            return nil
        }
        
        self.conversationId = document.documentID
        self.participants = participants
        self.lastMessageText = data["lastMessageText"] as? String
        self.isGroupChat = isGroupChat
        
        // Handle timestamp conversion
        if let timestamp = data["lastMessageTimestamp"] as? Timestamp {
            self.lastMessageTimestamp = timestamp.dateValue()
        }
    }
    
    /// Convert to Firestore dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "participants": participants,
            "isGroupChat": isGroupChat
        ]
        
        if let lastMessageText = lastMessageText {
            data["lastMessageText"] = lastMessageText
        }
        
        if let lastMessageTimestamp = lastMessageTimestamp {
            data["lastMessageTimestamp"] = Timestamp(date: lastMessageTimestamp)
        }
        
        return data
    }
}

// MARK: - Hashable

extension Conversation: Hashable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.conversationId == rhs.conversationId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
}

