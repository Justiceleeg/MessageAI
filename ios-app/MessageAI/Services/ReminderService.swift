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
    
    /// Observes all reminders for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - onChange: Callback with array of reminders
    /// - Returns: ListenerRegistration to stop observing
    func observeConversationReminders(conversationId: String, onChange: @escaping ([Reminder]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for conversation reminders: \(conversationId)")
        
        let query = db.collection(remindersCollection)
            .whereField("conversationId", isEqualTo: conversationId)
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
            
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            self.logger.info("Conversation reminders updated via listener: \(reminders.count) reminders")
            onChange(reminders)
        }
    }
}

