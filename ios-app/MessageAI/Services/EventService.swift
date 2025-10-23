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
        
        do {
            let docRef = db.collection(eventsCollection).document(id)
            try await docRef.delete()
            logger.info("Event deleted successfully: \(id)")
            
        } catch {
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
}

