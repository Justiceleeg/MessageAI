//
//  EventEntity.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import SwiftData

/// SwiftData entity for Event local persistence
@Model
class EventEntity {
    
    // MARK: - Properties
    
    @Attribute(.unique) var eventId: String
    var title: String
    var date: Date
    var time: String?
    var location: String?
    var creatorUserId: String
    var createdAt: Date
    var createdInConversationId: String
    var createdAtMessageId: String
    
    // Store complex types as JSON strings for SwiftData
    var invitationsJSON: String
    var attendeesJSON: String
    
    // MARK: - Initialization
    
    init(
        eventId: String,
        title: String,
        date: Date,
        time: String? = nil,
        location: String? = nil,
        creatorUserId: String,
        createdAt: Date,
        createdInConversationId: String,
        createdAtMessageId: String,
        invitationsJSON: String = "{}",
        attendeesJSON: String = "{}"
    ) {
        self.eventId = eventId
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.creatorUserId = creatorUserId
        self.createdAt = createdAt
        self.createdInConversationId = createdInConversationId
        self.createdAtMessageId = createdAtMessageId
        self.invitationsJSON = invitationsJSON
        self.attendeesJSON = attendeesJSON
    }
}

// MARK: - Event Conversion

extension EventEntity {
    /// Convert from Event model to EventEntity
    static func from(_ event: Event) -> EventEntity {
        let encoder = JSONEncoder()
        
        // Encode invitations dictionary
        let invitationsJSON = (try? encoder.encode(event.invitations))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        // Encode attendees dictionary
        let attendeesJSON = (try? encoder.encode(event.attendees))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return EventEntity(
            eventId: event.eventId,
            title: event.title,
            date: event.date,
            time: event.time,
            location: event.location,
            creatorUserId: event.creatorUserId,
            createdAt: event.createdAt,
            createdInConversationId: event.createdInConversationId,
            createdAtMessageId: event.createdAtMessageId,
            invitationsJSON: invitationsJSON,
            attendeesJSON: attendeesJSON
        )
    }
    
    /// Convert to Event model
    func toEvent() -> Event? {
        let decoder = JSONDecoder()
        
        // Decode invitations
        let invitations = invitationsJSON.data(using: .utf8)
            .flatMap { try? decoder.decode([String: Invitation].self, from: $0) } ?? [:]
        
        // Decode attendees
        let attendees = attendeesJSON.data(using: .utf8)
            .flatMap { try? decoder.decode([String: Attendee].self, from: $0) } ?? [:]
        
        return Event(
            eventId: eventId,
            title: title,
            date: date,
            time: time,
            location: location,
            creatorUserId: creatorUserId,
            createdAt: createdAt,
            createdInConversationId: createdInConversationId,
            createdAtMessageId: createdAtMessageId,
            invitations: invitations,
            attendees: attendees
        )
    }
}

