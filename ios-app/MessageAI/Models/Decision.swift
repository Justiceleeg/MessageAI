//
//  Decision.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation

/// Decision model matching Firestore schema
struct Decision: Identifiable, Codable, Hashable {
    
    // MARK: - Properties
    
    /// Unique identifier
    var id: String { decisionId }
    
    let decisionId: String
    let userId: String
    let text: String
    let conversationId: String
    let sourceMessageId: String
    let timestamp: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case decisionId
        case userId
        case text
        case conversationId
        case sourceMessageId
        case timestamp
    }
    
    // MARK: - Initialization
    
    init(
        decisionId: String = UUID().uuidString,
        userId: String,
        text: String,
        conversationId: String,
        sourceMessageId: String,
        timestamp: Date = Date()
    ) {
        self.decisionId = decisionId
        self.userId = userId
        self.text = text
        self.conversationId = conversationId
        self.sourceMessageId = sourceMessageId
        self.timestamp = timestamp
    }
}

