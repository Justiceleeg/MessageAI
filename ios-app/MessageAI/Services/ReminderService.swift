//
//  ReminderService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import FirebaseFirestore
import OSLog

/// Service responsible for Reminder CRUD operations and Firestore synchronization
@MainActor
class ReminderService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let remindersCollection = "reminders"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ReminderService")
    
    // MARK: - CRUD Methods
    
    /// Creates a new reminder in Firestore
    /// - Parameter reminder: Reminder to create
    /// - Returns: Created reminder
    /// - Throws: Error if creation fails
    func createReminder(_ reminder: Reminder) async throws -> Reminder {
        logger.info("Creating reminder: \(reminder.reminderId)")
        
        do {
            let docRef = db.collection(remindersCollection).document(reminder.reminderId)
            let data = try Firestore.Encoder().encode(reminder)
            try await docRef.setData(data)
            logger.info("Reminder created successfully: \(reminder.reminderId)")
            return reminder
            
        } catch {
            logger.error("Failed to create reminder: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches a reminder by ID
    /// - Parameter id: Reminder ID
    /// - Returns: Reminder if found, nil otherwise
    /// - Throws: Error if fetch fails
    func getReminder(id: String) async throws -> Reminder? {
        logger.info("Fetching reminder: \(id)")
        
        do {
            let docRef = db.collection(remindersCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Reminder not found: \(id)")
                return nil
            }
            
            let reminder = try snapshot.data(as: Reminder.self)
            logger.info("Reminder fetched successfully: \(id)")
            return reminder
            
        } catch {
            logger.error("Failed to fetch reminder: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists reminders for a user with optional completion filter
    /// - Parameters:
    ///   - userId: User ID
    ///   - completed: Optional filter for completed status (nil = all)
    /// - Returns: Array of reminders
    /// - Throws: Error if fetch fails
    func listReminders(userId: String, completed: Bool? = nil) async throws -> [Reminder] {
        logger.info("Listing reminders for user: \(userId), completed filter: \(String(describing: completed))")
        
        do {
            var query = db.collection(remindersCollection)
                .whereField("userId", isEqualTo: userId)
            
            if let completed = completed {
                query = query.whereField("completed", isEqualTo: completed)
            }
            
            query = query.order(by: "dueDate", descending: false)
            
            let snapshot = try await query.getDocuments()
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            
            logger.info("Fetched \(reminders.count) reminders for user: \(userId)")
            return reminders
            
        } catch {
            logger.error("Failed to list reminders: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all reminders for a conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Array of reminders
    /// - Throws: Error if fetch fails
    func listRemindersForConversation(conversationId: String) async throws -> [Reminder] {
        logger.info("Listing reminders for conversation: \(conversationId)")
        
        do {
            let query = db.collection(remindersCollection)
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "dueDate", descending: false)
            
            let snapshot = try await query.getDocuments()
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            
            logger.info("Fetched \(reminders.count) reminders for conversation: \(conversationId)")
            return reminders
            
        } catch {
            logger.error("Failed to list reminders for conversation: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates an existing reminder
    /// - Parameter reminder: Reminder with updated data
    /// - Throws: Error if update fails
    func updateReminder(_ reminder: Reminder) async throws {
        logger.info("Updating reminder: \(reminder.reminderId)")
        
        do {
            let docRef = db.collection(remindersCollection).document(reminder.reminderId)
            let data = try Firestore.Encoder().encode(reminder)
            try await docRef.setData(data, merge: true)
            logger.info("Reminder updated successfully: \(reminder.reminderId)")
            
        } catch {
            logger.error("Failed to update reminder: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a reminder
    /// - Parameter id: Reminder ID
    /// - Throws: Error if deletion fails
    func deleteReminder(id: String) async throws {
        logger.info("Deleting reminder: \(id)")
        
        do {
            let docRef = db.collection(remindersCollection).document(id)
            try await docRef.delete()
            logger.info("Reminder deleted successfully: \(id)")
            
        } catch {
            logger.error("Failed to delete reminder: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Completion Management
    
    /// Marks a reminder as complete
    /// - Parameter reminderId: Reminder ID
    /// - Throws: Error if update fails
    func markComplete(reminderId: String) async throws {
        logger.info("Marking reminder as complete: \(reminderId)")
        
        do {
            let docRef = db.collection(remindersCollection).document(reminderId)
            try await docRef.updateData([
                "completed": true
            ])
            logger.info("Reminder marked complete: \(reminderId)")
            
        } catch {
            logger.error("Failed to mark reminder complete: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Real-time Listeners
    
    /// Observes changes to a specific reminder
    /// - Parameters:
    ///   - id: Reminder ID
    ///   - onChange: Callback with updated reminder or nil if deleted
    /// - Returns: ListenerRegistration to stop observing
    func observeReminder(id: String, onChange: @escaping (Reminder?) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for reminder: \(id)")
        
        let docRef = db.collection(remindersCollection).document(id)
        
        return docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Reminder listener error: \(error.localizedDescription)")
                onChange(nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                self.logger.info("Reminder deleted or not found: \(id)")
                onChange(nil)
                return
            }
            
            do {
                let reminder = try snapshot.data(as: Reminder.self)
                self.logger.info("Reminder updated via listener: \(id)")
                onChange(reminder)
            } catch {
                self.logger.error("Failed to decode reminder: \(error.localizedDescription)")
                onChange(nil)
            }
        }
    }
    
    /// Observes all reminders for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - onChange: Callback with array of reminders
    /// - Returns: ListenerRegistration to stop observing
    func observeUserReminders(userId: String, onChange: @escaping ([Reminder]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for user reminders: \(userId)")
        
        let query = db.collection(remindersCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "dueDate", descending: false)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("User reminders listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            self.logger.info("User reminders updated via listener: \(reminders.count) reminders")
            onChange(reminders)
        }
    }
    
    /// Alias for observeUserReminders for global reminders view
    /// - Parameters:
    ///   - onChange: Callback with array of reminders
    /// - Returns: ListenerRegistration to stop observing
    func observeAllReminders(onChange: @escaping ([Reminder]) -> Void) -> ListenerRegistration {
        guard let userId = AuthService.shared.currentUser?.userId else {
            logger.error("No authenticated user for observeAllReminders")
            onChange([])
            // Return a dummy listener that does nothing
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        return observeUserReminders(userId: userId, onChange: onChange)
    }
    
    /// Observes all reminders for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - onChange: Callback with array of reminders
    /// - Returns: ListenerRegistration to stop observing
    func observeConversationReminders(conversationId: String, onChange: @escaping ([Reminder]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for conversation reminders: \(conversationId)")
        
        guard let userId = AuthService.shared.currentUser?.userId else {
            logger.error("No authenticated user for observeConversationReminders")
            onChange([])
            return db.collection("dummy").addSnapshotListener { _, _ in }
        }
        
        // Use the existing observeUserReminders and filter client-side
        // This avoids the compound index requirement
        let query = db.collection(remindersCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "dueDate", descending: false)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Conversation reminders listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            // Get all user reminders and filter by conversation on client side
            let allReminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            let conversationReminders = allReminders.filter { $0.conversationId == conversationId }
            
            self.logger.info("Conversation reminders updated via listener: \(conversationReminders.count) reminders")
            onChange(conversationReminders)
        }
    }
    
    // MARK: - Vector Storage Integration (Story 5.5)
    
    /// Creates a reminder with vector storage for semantic search
    /// - Parameter reminder: Reminder to create
    /// - Throws: Error if creation fails
    func createReminderWithVectorStorage(_ reminder: Reminder) async throws {
        logger.info("Creating reminder with vector storage: \(reminder.reminderId)")
        
        do {
            // Store in Firestore
            _ = try await createReminder(reminder)
            
            // Store vector embedding in backend
            try await storeReminderVector(reminder)
            
            logger.info("Reminder created with vector storage: \(reminder.reminderId)")
            
        } catch {
            logger.error("Failed to create reminder with vector storage: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Stores reminder vector embedding in backend
    /// - Parameter reminder: Reminder to store
    /// - Throws: Error if storage fails
    private func storeReminderVector(_ reminder: Reminder) async throws {
        logger.info("Storing reminder vector: \(reminder.reminderId)")
        
        let request = ReminderVectorRequest(
            reminderId: reminder.reminderId,
            title: reminder.title,
            userId: reminder.userId,
            conversationId: reminder.conversationId,
            sourceMessageId: reminder.sourceMessageId,
            dueDate: ISO8601DateFormatter().string(from: reminder.dueDate),
            timestamp: ISO8601DateFormatter().string(from: reminder.createdAt)
        )
        
        _ = try await AIBackendService.shared.storeReminderVector(request)
        logger.info("Reminder vector stored successfully: \(reminder.reminderId)")
    }
    
    /// Deletes reminder vector from backend
    /// - Parameter reminderId: Reminder ID
    /// - Throws: Error if deletion fails
    func deleteReminderVector(reminderId: String) async throws {
        logger.info("Deleting reminder vector: \(reminderId)")
        
        _ = try await AIBackendService.shared.deleteReminderVector(reminderId)
        logger.info("Reminder vector deleted successfully: \(reminderId)")
    }
    
    /// Searches reminders using semantic search
    /// - Parameters:
    ///   - query: Search query
    ///   - userId: User ID
    /// - Returns: Array of search results
    /// - Throws: Error if search fails
    func searchReminders(query: String, userId: String) async throws -> [ReminderSearchResult] {
        logger.info("Searching reminders: \(query)")
        
        do {
            let response = try await AIBackendService.shared.searchReminders(query: query, userId: userId)
            logger.info("Found \(response.results.count) reminder search results")
            return response.results
            
        } catch {
            logger.error("Failed to search reminders: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Notification Scheduling (Story 5.5)
    
    /// Schedules a reminder notification
    /// - Parameters:
    ///   - reminder: Reminder to schedule
    ///   - timing: Reminder timing option
    /// - Throws: Error if scheduling fails
    func scheduleReminder(_ reminder: Reminder, timing: ReminderTiming) async throws {
        logger.info("Scheduling reminder notification: \(reminder.reminderId)")
        
        // TODO: Implement notification scheduling
        // This requires NotificationManager to be passed as a parameter
        // or accessed through environment/dependency injection
        logger.warning("Notification scheduling not implemented - requires NotificationManager instance")
        
        // For now, just update the reminder without notification ID
        try await updateReminder(reminder)
        
        logger.info("Reminder updated (notification scheduling pending): \(reminder.reminderId)")
    }
    
    /// Cancels a reminder notification
    /// - Parameter reminderId: Reminder ID
    /// - Throws: Error if cancellation fails
    func cancelReminderNotification(reminderId: String) async throws {
        logger.info("Cancelling reminder notification: \(reminderId)")
        
        do {
            // Get reminder to find notification ID
            guard let reminder = try await getReminder(id: reminderId),
                  let _ = reminder.notificationId else {
                logger.info("No notification ID found for reminder: \(reminderId)")
                return
            }
            
            // Cancel notification
            // TODO: Implement notification cancellation
            // This requires NotificationManager to be passed as a parameter
            logger.warning("Notification cancellation not implemented - requires NotificationManager instance")
            
            // Clear notification ID from reminder
            var updatedReminder = reminder
            updatedReminder.notificationId = nil
            try await updateReminder(updatedReminder)
            
            logger.info("Reminder notification cancelled: \(reminderId)")
            
        } catch {
            logger.error("Failed to cancel reminder notification: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Completes a reminder and cancels its notification
    /// - Parameter reminderId: Reminder ID
    /// - Throws: Error if completion fails
    func completeReminder(reminderId: String) async throws {
        logger.info("Completing reminder: \(reminderId)")
        
        do {
            // Cancel notification first
            try await cancelReminderNotification(reminderId: reminderId)
            
            // Mark as complete
            try await markComplete(reminderId: reminderId)
            
            logger.info("Reminder completed: \(reminderId)")
            
        } catch {
            logger.error("Failed to complete reminder: \(error.localizedDescription)")
            throw error
        }
    }
}

