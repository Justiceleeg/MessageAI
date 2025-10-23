//
//  DecisionEntity.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import SwiftData

/// SwiftData entity for Decision local persistence
@Model
class DecisionEntity {
    
    // MARK: - Properties
    
    @Attribute(.unique) var decisionId: String
    var userId: String
    var text: String
    var conversationId: String
    var sourceMessageId: String
    var timestamp: Date
    
    // MARK: - Initialization
    
    init(
        decisionId: String,
        userId: String,
        text: String,
        conversationId: String,
        sourceMessageId: String,
        timestamp: Date
    ) {
        self.decisionId = decisionId
        self.userId = userId
        self.text = text
        self.conversationId = conversationId
        self.sourceMessageId = sourceMessageId
        self.timestamp = timestamp
    }
}

// MARK: - Decision Conversion

extension DecisionEntity {
    /// Convert from Decision model to DecisionEntity
    static func from(_ decision: Decision) -> DecisionEntity {
        return DecisionEntity(
            decisionId: decision.decisionId,
            userId: decision.userId,
            text: decision.text,
            conversationId: decision.conversationId,
            sourceMessageId: decision.sourceMessageId,
            timestamp: decision.timestamp
        )
    }
    
    /// Convert to Decision model
    func toDecision() -> Decision {
        return Decision(
            decisionId: decisionId,
            userId: userId,
            text: text,
            conversationId: conversationId,
            sourceMessageId: sourceMessageId,
            timestamp: timestamp
        )
    }
}

