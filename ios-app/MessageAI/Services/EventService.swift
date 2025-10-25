//
//  EventService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import FirebaseFirestore
import OSLog

/// Service responsible for Event CRUD operations and Firestore synchronization
@MainActor
class EventService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let eventsCollection = "events"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "EventService")
    
    // MARK: - CRUD Methods
    
    /// Creates a new event in Firestore
    /// - Parameter event: Event to create
    /// - Returns: Created event
    /// - Throws: Error if creation fails
    func createEvent(_ event: Event) async throws -> Event {
        logger.info("Creating event: \(event.eventId)")
        
        do {
            let docRef = db.collection(eventsCollection).document(event.eventId)
            let data = try Firestore.Encoder().encode(event)
            try await docRef.setData(data)
            logger.info("Event created successfully: \(event.eventId)")
            return event
            
        } catch {
            logger.error("Failed to create event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches an event by ID
    /// - Parameter id: Event ID
    /// - Returns: Event if found, nil otherwise
    /// - Throws: Error if fetch fails
    func getEvent(id: String) async throws -> Event? {
        logger.info("Fetching event: \(id)")
        
        do {
            let docRef = db.collection(eventsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Event not found: \(id)")
                return nil
            }
            
            let event = try snapshot.data(as: Event.self)
            logger.info("Event fetched successfully: \(id)")
            return event
            
        } catch {
            logger.error("Failed to fetch event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all events created by a user
    /// - Parameter userId: User ID
    /// - Returns: Array of events
    /// - Throws: Error if fetch fails
    func listEvents(userId: String) async throws -> [Event] {
        logger.info("Listing events for user: \(userId)")
        
        do {
            let query = db.collection(eventsCollection)
                .whereField("creatorUserId", isEqualTo: userId)
                .order(by: "date", descending: false)
            
            let snapshot = try await query.getDocuments()
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            
            logger.info("Fetched \(events.count) events for user: \(userId)")
            return events
            
        } catch {
            logger.error("Failed to list events: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all events where user is an attendee (Story 5.4)
    /// - Parameter userId: User ID
    /// - Returns: Array of events where user is an attendee
    /// - Note: This method fetches all events and filters client-side to avoid dynamic field path queries
    func listAttendedEvents(userId: String) async throws -> [Event] {
        logger.info("Listing attended events for user: \(userId)")
        
        do {
            // Get all events and filter client-side to avoid dynamic field path queries
            // This is more efficient than creating indexes for each user ID
            let query = db.collection(eventsCollection)
                .order(by: "date", descending: false)
            
            let snapshot = try await query.getDocuments()
            let allEvents = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            
            // Filter to only events where user is an attendee
            let attendedEvents = allEvents.filter { event in
                event.attendees[userId] != nil
            }
            
            logger.info("Fetched \(attendedEvents.count) attended events for user: \(userId)")
            return attendedEvents
            
        } catch {
            logger.error("Failed to list attended events: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all events for a user (created by them OR where they are an attendee) (Story 5.4)
    /// - Parameter userId: User ID
    /// - Returns: Array of all relevant events
    /// - Throws: Error if fetch fails
    func listAllUserEvents(userId: String) async throws -> [Event] {
        logger.info("Listing all events for user: \(userId)")
        
        do {
            // Get created events (this works with existing rules)
            let createdEvents = try await listEvents(userId: userId)
            
            // For attended events, we need a different approach since we can't query all events
            // We'll use the existing attendees index but with a different strategy
            let attendedEvents = try await listAttendedEventsAlternative(userId: userId)
            
            // Combine and deduplicate (in case user is both creator and attendee)
            var allEvents = createdEvents
            for attendedEvent in attendedEvents {
                if !allEvents.contains(where: { $0.eventId == attendedEvent.eventId }) {
                    allEvents.append(attendedEvent)
                }
            }
            
            // Sort by date
            allEvents.sort { $0.date < $1.date }
            
            logger.info("Fetched \(allEvents.count) total events for user: \(userId)")
            return allEvents
            
        } catch {
            logger.error("Failed to list all user events: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Alternative method to get attended events using conversation-based queries (Story 5.4)
    /// - Parameter userId: User ID
    /// - Returns: Array of events where user is an attendee
    /// - Throws: Error if fetch fails
    private func listAttendedEventsAlternative(userId: String) async throws -> [Event] {
        logger.info("Listing attended events for user (alternative method): \(userId)")
        
        // Since we can't query all events due to security rules, we need a different approach
        // For now, we'll return an empty array and rely on the user's created events
        // In a production app, you might want to:
        // 1. Store user's attended events in a separate collection
        // 2. Use cloud functions to maintain this list
        // 3. Or modify the security rules to allow broader access
        
        logger.info("Alternative attended events method - returning empty array for now")
        return []
    }
    
    /// Lists all events for a conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Array of events
    /// - Throws: Error if fetch fails
    func listEventsForConversation(conversationId: String) async throws -> [Event] {
        logger.info("Listing events for conversation: \(conversationId)")
        
        do {
            let query = db.collection(eventsCollection)
                .whereField("createdInConversationId", isEqualTo: conversationId)
                .order(by: "date", descending: false)
            
            let snapshot = try await query.getDocuments()
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            
            logger.info("Fetched \(events.count) events for conversation: \(conversationId)")
            return events
            
        } catch {
            logger.error("Failed to list events for conversation: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates an existing event
    /// - Parameter event: Event with updated data
    /// - Throws: Error if update fails
    func updateEvent(_ event: Event) async throws {
        logger.info("Updating event: \(event.eventId)")
        
        do {
            let docRef = db.collection(eventsCollection).document(event.eventId)
            let data = try Firestore.Encoder().encode(event)
            try await docRef.setData(data, merge: true)
            logger.info("Event updated successfully: \(event.eventId)")
            
        } catch {
            logger.error("Failed to update event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes an event
    /// - Parameter id: Event ID
    /// - Throws: Error if deletion fails
    func deleteEvent(id: String) async throws {
        logger.info("Deleting event: \(id)")
        print("🗑️ DEBUG: EventService.deleteEvent called for: \(id)")
        
        do {
            let docRef = db.collection(eventsCollection).document(id)
            print("🗑️ DEBUG: Document reference: \(docRef.path)")
            try await docRef.delete()
            print("✅ DEBUG: Event deleted from Firestore successfully: \(id)")
            logger.info("Event deleted successfully: \(id)")
            
        } catch {
            print("❌ DEBUG: EventService.deleteEvent failed: \(error.localizedDescription)")
            print("❌ DEBUG: Full error: \(error)")
            logger.error("Failed to delete event: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Attendee Management
    
    /// Adds or updates an attendee for an event
    /// - Parameters:
    ///   - eventId: Event ID
    ///   - userId: User ID
    ///   - status: RSVP status
    /// - Throws: Error if update fails
    func addAttendee(eventId: String, userId: String, status: RSVPStatus) async throws {
        logger.info("Adding attendee \(userId) to event \(eventId) with status: \(status.rawValue)")
        
        do {
            let docRef = db.collection(eventsCollection).document(eventId)
            let attendee = Attendee(status: status, rsvpAt: Date())
            
            let attendeeData = try Firestore.Encoder().encode(attendee)
            
            try await docRef.updateData([
                "attendees.\(userId)": attendeeData
            ])
            
            logger.info("Attendee added successfully to event: \(eventId)")
            
        } catch {
            logger.error("Failed to add attendee: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Submits an RSVP response for an event (Story 5.4)
    /// - Parameters:
    ///   - eventId: Event ID
    ///   - userId: User ID
    ///   - status: RSVP status
    ///   - message: Optional message to post with RSVP
    ///   - conversationId: Conversation ID to post message to
    /// - Throws: Error if RSVP submission fails
    func submitRSVP(eventId: String, userId: String, status: RSVPStatus, message: String? = nil, conversationId: String? = nil) async throws {
        logger.info("Submitting RSVP for event \(eventId), user \(userId), status: \(status.rawValue)")
        
        do {
            // Update attendee status in event
            let docRef = db.collection(eventsCollection).document(eventId)
            let attendee = Attendee(status: status, rsvpAt: Date())
            
            let attendeeData = try Firestore.Encoder().encode(attendee)
            
            try await docRef.updateData([
                "attendees.\(userId)": attendeeData
            ])
            
            // If message provided and conversation ID available, post message to chat
            if let message = message, !message.isEmpty, let conversationId = conversationId {
                try await postRSVPMessage(eventId: eventId, status: status, message: message, conversationId: conversationId, userId: userId)
            }
            
            logger.info("RSVP submitted successfully for event: \(eventId)")
            
        } catch {
            logger.error("Failed to submit RSVP: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Posts RSVP message to conversation (Story 5.4)
    /// - Parameters:
    ///   - eventId: Event ID
    ///   - status: RSVP status
    ///   - message: User's message
    ///   - conversationId: Conversation ID
    ///   - userId: User ID
    /// - Throws: Error if message posting fails
    private func postRSVPMessage(eventId: String, status: RSVPStatus, message: String, conversationId: String, userId: String) async throws {
        logger.info("Posting RSVP message to conversation: \(conversationId)")
        
        do {
            let firestoreService = FirestoreService()
            let messageId = UUID().uuidString
            
            // Create RSVP message with badge
            let rsvpBadge = status == .accepted ? "✅" : "❌"
            let rsvpText = "\(rsvpBadge) \(message)"
            
            // Post message to conversation
            _ = try await firestoreService.sendMessage(
                conversationId: conversationId,
                senderId: userId,
                text: rsvpText,
                messageId: messageId
            )
            
            logger.info("RSVP message posted successfully")
            
        } catch {
            logger.error("Failed to post RSVP message: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Link an existing event to a new chat conversation
    /// - Parameters:
    ///   - eventId: The event ID to link
    ///   - conversationId: The conversation ID to link to
    ///   - invitation: The invitation details
    ///   - attendees: List of attendee IDs to add
    /// - Throws: Error if linking fails
    func linkEventToChat(eventId: String, conversationId: String, invitation: Invitation, attendees: [String]) async throws {
        logger.info("Linking event \(eventId) to conversation \(conversationId)")
        
        do {
            let docRef = db.collection(eventsCollection).document(eventId)
            
            // Add invitation for this conversation
            let invitationData = try Firestore.Encoder().encode(invitation)
            
            // Add attendees to the event
            var attendeeUpdates: [String: Any] = [:]
            for attendeeId in attendees {
                let attendee = Attendee(status: .pending)
                let attendeeData = try Firestore.Encoder().encode(attendee)
                attendeeUpdates["attendees.\(attendeeId)"] = attendeeData
            }
            
            // Update event with new invitation and attendees
            var updateData: [String: Any] = [
                "invitations.\(conversationId)": invitationData
            ]
            updateData.merge(attendeeUpdates) { _, new in new }
            
            try await docRef.updateData(updateData)
            
            logger.info("Event linked to conversation successfully")
            
        } catch {
            logger.error("Failed to link event to conversation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Real-time Listeners
    
    /// Observes changes to a specific event
    /// - Parameters:
    ///   - id: Event ID
    ///   - onChange: Callback with updated event or nil if deleted
    /// - Returns: ListenerRegistration to stop observing
    func observeEvent(id: String, onChange: @escaping (Event?) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for event: \(id)")
        
        let docRef = db.collection(eventsCollection).document(id)
        
        return docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Event listener error: \(error.localizedDescription)")
                onChange(nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                self.logger.info("Event deleted or not found: \(id)")
                onChange(nil)
                return
            }
            
            do {
                let event = try snapshot.data(as: Event.self)
                self.logger.info("Event updated via listener: \(id)")
                onChange(event)
            } catch {
                self.logger.error("Failed to decode event: \(error.localizedDescription)")
                onChange(nil)
            }
        }
    }
    
    /// Observes all events for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - onChange: Callback with array of events
    /// - Returns: ListenerRegistration to stop observing
    func observeUserEvents(userId: String, onChange: @escaping ([Event]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for user events: \(userId)")
        
        let query = db.collection(eventsCollection)
            .whereField("creatorUserId", isEqualTo: userId)
            .order(by: "date", descending: false)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("User events listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            self.logger.info("User events updated via listener: \(events.count) events")
            onChange(events)
        }
    }
    
    /// Observes all events for a user (created by them OR where they are an attendee) (Story 5.4)
    /// - Parameters:
    ///   - userId: User ID
    ///   - onChange: Callback with array of events
    /// - Returns: ListenerRegistration to stop observing
    /// - Note: This method uses the existing observeUserEvents for now (created events only)
    func observeAllUserEvents(userId: String, onChange: @escaping ([Event]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for all user events: \(userId)")
        
        // For now, we'll use the existing observeUserEvents method which works with security rules
        // This will show created events. Attended events will need a different approach.
        return observeUserEvents(userId: userId, onChange: onChange)
    }
    
    /// Observes all events for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - onChange: Callback with array of events
    /// - Returns: ListenerRegistration to stop observing
    func observeConversationEvents(conversationId: String, onChange: @escaping ([Event]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for conversation events: \(conversationId)")
        
        let query = db.collection(eventsCollection)
            .whereField("createdInConversationId", isEqualTo: conversationId)
            .order(by: "date", descending: false)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Conversation events listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            self.logger.info("Conversation events updated via listener: \(events.count) events")
            onChange(events)
        }
    }
    
    /// Links an existing event to a new conversation
    /// - Parameters:
    ///   - eventId: ID of the event to link
    ///   - conversationId: ID of the conversation to link to
    ///   - messageId: ID of the message that triggered the link
    ///   - invitedUserIds: Array of user IDs to invite
    /// - Throws: Error if linking fails
    func linkEventToChat(
        eventId: String,
        conversationId: String,
        messageId: String,
        invitedUserIds: [String]
    ) async throws {
        logger.info("Linking event \(eventId) to conversation \(conversationId)")
        
        do {
            let eventRef = db.collection(eventsCollection).document(eventId)
            let eventDoc = try await eventRef.getDocument()
            
            guard eventDoc.exists, let event = try? eventDoc.data(as: Event.self) else {
                throw NSError(domain: "EventService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
            }
            
            // Create new invitation for this conversation
            let newInvitation = Invitation(
                messageId: messageId,
                invitedUserIds: invitedUserIds,
                timestamp: Date()
            )
            
            // Add new attendees
            var updatedAttendees = event.attendees
            for userId in invitedUserIds {
                if updatedAttendees[userId] == nil {
                    updatedAttendees[userId] = Attendee(status: .pending)
                }
            }
            
            // Update event with new invitation and attendees
            try await eventRef.updateData([
                "invitations.\(conversationId)": try Firestore.Encoder().encode(newInvitation),
                "attendees": try Firestore.Encoder().encode(updatedAttendees)
            ])
            
            logger.info("Event linked successfully: \(eventId)")
            
        } catch {
            logger.error("Failed to link event: \(error.localizedDescription)")
            throw error
        }
    }
}

