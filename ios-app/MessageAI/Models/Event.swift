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
    let time: String?           // "HH:mm" format, optional
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
        case time
        case location
        case creatorUserId
        case createdAt
        case createdInConversationId
        case createdAtMessageId
        case invitations
        case attendees
    }
    
    // MARK: - Initialization
    
    init(
        eventId: String = UUID().uuidString,
        title: String,
        date: Date,
        time: String? = nil,
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
        self.time = time
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

