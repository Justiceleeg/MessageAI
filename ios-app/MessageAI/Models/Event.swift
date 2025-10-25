//
//  Event.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation

/// Event model matching Firestore schema
struct Event: Identifiable, Codable, Hashable {
    
    // MARK: - Properties
    
    /// Unique identifier
    var id: String { eventId }
    
    let eventId: String
    let title: String
    let date: Date
    let startTime: String?      // "HH:mm" format (24-hour), optional
    let endTime: String?        // "HH:mm" format (24-hour), optional  
    let duration: Int?          // Duration in minutes
    let location: String?
    let creatorUserId: String
    let createdAt: Date
    let createdInConversationId: String
    let createdAtMessageId: String
    
    // Multi-chat tracking
    var invitations: [String: Invitation]  // conversationId -> Invitation
    var attendees: [String: Attendee]      // userId -> Attendee
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case eventId
        case title
        case date
        case startTime
        case endTime
        case duration
        case location
        case creatorUserId
        case createdAt
        case createdInConversationId
        case createdAtMessageId
        case invitations
        case attendees
    }
    
    // MARK: - Custom Encoding
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(eventId, forKey: .eventId)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(creatorUserId, forKey: .creatorUserId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(createdInConversationId, forKey: .createdInConversationId)
        try container.encode(createdAtMessageId, forKey: .createdAtMessageId)
        try container.encode(invitations, forKey: .invitations)
        try container.encode(attendees, forKey: .attendees)
        
        // Only encode optional fields if they have values
        if let startTime = startTime, !startTime.isEmpty {
            try container.encode(startTime, forKey: .startTime)
        }
        if let endTime = endTime, !endTime.isEmpty {
            try container.encode(endTime, forKey: .endTime)
        }
        if let duration = duration {
            try container.encode(duration, forKey: .duration)
        }
        if let location = location, !location.isEmpty {
            try container.encode(location, forKey: .location)
        }
    }
    
    // MARK: - Initialization
    
    init(
        eventId: String = UUID().uuidString,
        title: String,
        date: Date,
        startTime: String? = nil,
        endTime: String? = nil,
        duration: Int? = nil,
        location: String? = nil,
        creatorUserId: String,
        createdAt: Date = Date(),
        createdInConversationId: String,
        createdAtMessageId: String,
        invitations: [String: Invitation] = [:],
        attendees: [String: Attendee] = [:]
    ) {
        self.eventId = eventId
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.location = location
        self.creatorUserId = creatorUserId
        self.createdAt = createdAt
        self.createdInConversationId = createdInConversationId
        self.createdAtMessageId = createdAtMessageId
        self.invitations = invitations
        self.attendees = attendees
    }
}

// MARK: - Supporting Types

/// Invitation tracking for events across conversations
struct Invitation: Codable, Hashable {
    let messageId: String
    let invitedUserIds: [String]
    let timestamp: Date
    
    init(messageId: String, invitedUserIds: [String], timestamp: Date = Date()) {
        self.messageId = messageId
        self.invitedUserIds = invitedUserIds
        self.timestamp = timestamp
    }
}

/// Attendee information with RSVP status
struct Attendee: Codable, Hashable {
    var status: RSVPStatus
    var rsvpMessageId: String?
    var rsvpConversationId: String?
    var rsvpAt: Date?
    
    init(
        status: RSVPStatus = .pending,
        rsvpMessageId: String? = nil,
        rsvpConversationId: String? = nil,
        rsvpAt: Date? = nil
    ) {
        self.status = status
        self.rsvpMessageId = rsvpMessageId
        self.rsvpConversationId = rsvpConversationId
        self.rsvpAt = rsvpAt
    }
}

/// RSVP status for event attendees
enum RSVPStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
}

