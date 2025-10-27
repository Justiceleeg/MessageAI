//
//  EventService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import FirebaseFirestore
import OSLog
import SwiftData

/// Service responsible for Event CRUD operations and Firestore synchronization
@MainActor
class EventService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let eventsCollection = "events"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "EventService")
    private let modelContext: ModelContext
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext ?? PersistenceController.shared.modelContainer.mainContext
    }
    
    // MARK: - SwiftData Cache Helpers
    
    /// Cache an event to SwiftData
    private func cacheEvent(_ event: Event) async {
        do {
            // Check if already exists
            let predicate = #Predicate<EventEntity> { $0.eventId == event.eventId }
            let descriptor = FetchDescriptor<EventEntity>(predicate: predicate)
            
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
            
            let eventEntity = EventEntity.from(event)
            modelContext.insert(eventEntity)
            try modelContext.save()
            logger.debug("Event cached to SwiftData: \(event.eventId)")
        } catch {
            logger.error("Failed to cache event to SwiftData: \(error.localizedDescription)")
        }
    }
    
    /// Cache multiple events to SwiftData
    private func cacheEvents(_ events: [Event]) async {
        for event in events {
            await cacheEvent(event)
        }
    }
    
    /// Retrieve event from SwiftData cache
    private func getEventFromCache(id: String) -> Event? {
        do {
            let predicate = #Predicate<EventEntity> { $0.eventId == id }
            let descriptor = FetchDescriptor<EventEntity>(predicate: predicate)
            
            if let cachedEntity = try modelContext.fetch(descriptor).first {
                return cachedEntity.toEvent()
            }
        } catch {
            logger.error("Failed to fetch event from cache: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Retrieve events from SwiftData cache for a user
    private func getEventsFromCache(userId: String) -> [Event] {
        do {
            let predicate = #Predicate<EventEntity> { $0.creatorUserId == userId }
            let descriptor = FetchDescriptor<EventEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.compactMap { $0.toEvent() }
        } catch {
            logger.error("Failed to fetch events from cache: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Retrieve events from SwiftData cache for a conversation
    private func getEventsFromCacheForConversation(conversationId: String) -> [Event] {
        do {
            let predicate = #Predicate<EventEntity> { $0.createdInConversationId == conversationId }
            let descriptor = FetchDescriptor<EventEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.compactMap { $0.toEvent() }
        } catch {
            logger.error("Failed to fetch events from cache for conversation: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Delete event from SwiftData cache
    private func deleteEventFromCache(id: String) {
        do {
            let predicate = #Predicate<EventEntity> { $0.eventId == id }
            let descriptor = FetchDescriptor<EventEntity>(predicate: predicate)
            
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
                logger.debug("Event deleted from cache: \(id)")
            }
        } catch {
            logger.error("Failed to delete event from cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD Methods
    
    /// Creates a new event in Firestore and indexes it in Pinecone
    /// - Parameter event: Event to create
    /// - Returns: Created event
    /// - Throws: Error if creation fails
    func createEvent(_ event: Event) async throws -> Event {
        logger.info("Creating event: \(event.eventId)")
        
        do {
            // 1. Cache locally first for optimistic UI
            await cacheEvent(event)
            
            // 2. Create event in Firestore
            let docRef = db.collection(eventsCollection).document(event.eventId)
            let data = try Firestore.Encoder().encode(event)
            try await docRef.setData(data)
            logger.info("Event created successfully in Firestore: \(event.eventId)")
            
            // 3. Index event in Pinecone for conflict detection
            await indexEventInPinecone(event)
            
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
        
        // 1. Try local cache first
        if let cachedEvent = getEventFromCache(id: id) {
            logger.info("Event found in cache: \(id)")
            
            // 2. Refresh from Firestore in background if online
            if networkMonitor.isConnected {
                Task {
                    await refreshEventFromFirestore(id: id)
                }
            }
            
            return cachedEvent
        }
        
        // 3. If not in cache, fetch from Firestore
        return try await fetchAndCacheEvent(id: id)
    }
    
    /// Fetch event from Firestore and cache it
    private func fetchAndCacheEvent(id: String) async throws -> Event? {
        do {
            let docRef = db.collection(eventsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Event not found: \(id)")
                return nil
            }
            
            let event = try snapshot.data(as: Event.self)
            logger.info("Event fetched successfully: \(id)")
            
            // Cache the event
            await cacheEvent(event)
            
            return event
            
        } catch {
            logger.error("Failed to fetch event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Refresh event from Firestore silently (background operation)
    private func refreshEventFromFirestore(id: String) async {
        do {
            let docRef = db.collection(eventsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists, let event = try? snapshot.data(as: Event.self) {
                await cacheEvent(event)
                logger.debug("Event refreshed from Firestore: \(id)")
            }
        } catch {
            logger.debug("Failed to refresh event from Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Lists all events created by a user
    /// - Parameter userId: User ID
    /// - Returns: Array of events
    /// - Throws: Error if fetch fails
    func listEvents(userId: String) async throws -> [Event] {
        logger.info("Listing events for user: \(userId)")
        
        // If offline, return cached events only
        if !networkMonitor.isConnected {
            logger.info("Offline mode - returning cached events for user: \(userId)")
            return getEventsFromCache(userId: userId)
        }
        
        // Online: fetch from Firestore and update cache
        do {
            let query = db.collection(eventsCollection)
                .whereField("creatorUserId", isEqualTo: userId)
                .order(by: "date", descending: false)
            
            let snapshot = try await query.getDocuments()
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            
            // Cache all fetched events
            await cacheEvents(events)
            
            logger.info("Fetched \(events.count) events for user: \(userId)")
            return events
            
        } catch {
            logger.error("Failed to list events: \(error.localizedDescription)")
            // Fallback to cache on error
            logger.info("Falling back to cached events")
            return getEventsFromCache(userId: userId)
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
        
        // If offline, return cached events only
        if !networkMonitor.isConnected {
            logger.info("Offline mode - returning cached events for conversation: \(conversationId)")
            return getEventsFromCacheForConversation(conversationId: conversationId)
        }
        
        // Online: fetch from Firestore and update cache
        do {
            let query = db.collection(eventsCollection)
                .whereField("createdInConversationId", isEqualTo: conversationId)
                .order(by: "date", descending: false)
            
            let snapshot = try await query.getDocuments()
            let events = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            
            // Cache all fetched events
            await cacheEvents(events)
            
            logger.info("Fetched \(events.count) events for conversation: \(conversationId)")
            return events
            
        } catch {
            logger.error("Failed to list events for conversation: \(error.localizedDescription)")
            // Fallback to cache on error
            logger.info("Falling back to cached events")
            return getEventsFromCacheForConversation(conversationId: conversationId)
        }
    }
    
    /// Updates an existing event
    /// - Parameter event: Event with updated data
    /// - Throws: Error if update fails
    func updateEvent(_ event: Event) async throws {
        logger.info("Updating event: \(event.eventId)")
        
        do {
            // 1. Update cache first for optimistic UI
            await cacheEvent(event)
            
            // 2. Update event in Firestore
            let docRef = db.collection(eventsCollection).document(event.eventId)
            let data = try Firestore.Encoder().encode(event)
            try await docRef.setData(data, merge: true)
            logger.info("Event updated successfully in Firestore: \(event.eventId)")
            
            // 3. Update event in Pinecone
            await updateEventInPinecone(event)
            
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
            // 1. Delete from cache first
            deleteEventFromCache(id: id)
            
            // 2. Delete event from Firestore
            let docRef = db.collection(eventsCollection).document(id)
            print("🗑️ DEBUG: Document reference: \(docRef.path)")
            try await docRef.delete()
            logger.info("Event deleted successfully from Firestore: \(id)")
            
            // 3. Remove event from Pinecone
            await removeEventFromPinecone(id)
            
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
                // Delete from cache if it was removed
                Task { @MainActor in
                    self.deleteEventFromCache(id: id)
                }
                onChange(nil)
                return
            }
            
            do {
                let event = try snapshot.data(as: Event.self)
                self.logger.info("Event updated via listener: \(id)")
                
                // Cache the updated event
                Task { @MainActor in
                    await self.cacheEvent(event)
                }
                
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
            
            // Cache all events
            Task { @MainActor in
                await self.cacheEvents(events)
            }
            
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
            
            // Cache all events
            Task { @MainActor in
                await self.cacheEvents(events)
            }
            
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
            var newAttendeesAdded = 0
            for userId in invitedUserIds {
                if updatedAttendees[userId] == nil {
                    updatedAttendees[userId] = Attendee(status: .pending)
                    newAttendeesAdded += 1
                }
            }
            
            // Update event with new invitation and attendees
            try await eventRef.updateData([
                "invitations.\(conversationId)": try Firestore.Encoder().encode(newInvitation),
                "attendees": try Firestore.Encoder().encode(updatedAttendees)
            ])
            
            // Update message metadata to include eventId and isInvitation
            try await updateMessageMetadata(
                messageId: messageId,
                conversationId: conversationId,
                eventId: eventId,
                isInvitation: true
            )
            
            logger.info("Event linked successfully: \(eventId)")
            
        } catch {
            logger.error("Failed to link event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates message metadata to include eventId and isInvitation
    /// - Parameters:
    ///   - messageId: ID of the message to update
    ///   - conversationId: ID of the conversation containing the message
    ///   - eventId: ID of the event to link to the message
    ///   - isInvitation: Whether this message is an invitation
    /// - Throws: Error if update fails
    private func updateMessageMetadata(
        messageId: String,
        conversationId: String,
        eventId: String,
        isInvitation: Bool
    ) async throws {
        logger.info("Updating message metadata for message \(messageId)")
        
        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            let metadataData: [String: Any] = [
                "eventId": eventId,
                "isInvitation": isInvitation
            ]
            
            try await messageRef.updateData([
                "metadata": metadataData
            ])
            
            logger.info("Message metadata updated successfully: \(messageId)")
            
        } catch {
            logger.error("Failed to update message metadata: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Pinecone Indexing Methods
    
    /// Indexes an event in Pinecone for conflict detection
    /// - Parameter event: Event to index
    private func indexEventInPinecone(_ event: Event) async {
        do {
            let aiBackendService = AIBackendService.shared
            
            // Prepare event data for indexing
            let eventData: [String: Any] = [
                "id": event.eventId,
                "user_id": event.creatorUserId,
                "title": event.title,
                "date": event.date.formatted(.iso8601.year().month().day()),
                "startTime": event.startTime ?? "",
                "endTime": event.endTime ?? "",
                "location": event.location ?? "",
                "conversation_id": event.createdInConversationId,
                "created_at": event.createdAt.formatted(.iso8601)
            ]
            
            // Call backend to index event
            try await aiBackendService.indexEvent(eventData)
            logger.info("Event indexed successfully in Pinecone: \(event.eventId)")
            
        } catch {
            logger.error("Failed to index event in Pinecone: \(error.localizedDescription)")
            // Don't throw error - Pinecone indexing is not critical for event creation
        }
    }
    
    /// Updates an event in Pinecone index
    /// - Parameter event: Updated event
    private func updateEventInPinecone(_ event: Event) async {
        do {
            let aiBackendService = AIBackendService.shared
            
            // Prepare event data for updating
            let eventData: [String: Any] = [
                "id": event.eventId,
                "user_id": event.creatorUserId,
                "title": event.title,
                "date": event.date.formatted(.iso8601.year().month().day()),
                "startTime": event.startTime ?? "",
                "endTime": event.endTime ?? "",
                "location": event.location ?? "",
                "conversation_id": event.createdInConversationId,
                "created_at": event.createdAt.formatted(.iso8601)
            ]
            
            // Call backend to update event
            try await aiBackendService.updateEvent(event.eventId, eventData)
            logger.info("Event updated successfully in Pinecone: \(event.eventId)")
            
        } catch {
            logger.error("Failed to update event in Pinecone: \(error.localizedDescription)")
            // Don't throw error - Pinecone indexing is not critical for event updates
        }
    }
    
    /// Removes an event from Pinecone index
    /// - Parameter eventId: ID of event to remove
    private func removeEventFromPinecone(_ eventId: String) async {
        do {
            let aiBackendService = AIBackendService.shared
            
            // Call backend to remove event
            try await aiBackendService.deleteEvent(eventId)
            logger.info("Event removed successfully from Pinecone: \(eventId)")
            
        } catch {
            logger.error("Failed to remove event from Pinecone: \(error.localizedDescription)")
            // Don't throw error - Pinecone indexing is not critical for event deletion
        }
    }
}

