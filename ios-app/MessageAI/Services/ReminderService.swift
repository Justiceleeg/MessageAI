//
//  ReminderService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import FirebaseFirestore
import OSLog
import SwiftData

/// Service responsible for Reminder CRUD operations and Firestore synchronization
@MainActor
class ReminderService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let remindersCollection = "reminders"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "ReminderService")
    private let modelContext: ModelContext
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext ?? PersistenceController.shared.modelContainer.mainContext
    }
    
    // MARK: - SwiftData Cache Helpers
    
    /// Cache a reminder to SwiftData
    private func cacheReminder(_ reminder: Reminder) async {
        do {
            // Check if already exists
            let predicate = #Predicate<ReminderEntity> { $0.reminderId == reminder.reminderId }
            let descriptor = FetchDescriptor<ReminderEntity>(predicate: predicate)
            
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
            
            let reminderEntity = ReminderEntity.from(reminder)
            modelContext.insert(reminderEntity)
            try modelContext.save()
            logger.debug("Reminder cached to SwiftData: \(reminder.reminderId)")
        } catch {
            logger.error("Failed to cache reminder to SwiftData: \(error.localizedDescription)")
        }
    }
    
    /// Cache multiple reminders to SwiftData
    private func cacheReminders(_ reminders: [Reminder]) async {
        for reminder in reminders {
            await cacheReminder(reminder)
        }
    }
    
    /// Retrieve reminder from SwiftData cache
    private func getReminderFromCache(id: String) -> Reminder? {
        do {
            let predicate = #Predicate<ReminderEntity> { $0.reminderId == id }
            let descriptor = FetchDescriptor<ReminderEntity>(predicate: predicate)
            
            if let cachedEntity = try modelContext.fetch(descriptor).first {
                return cachedEntity.toReminder()
            }
        } catch {
            logger.error("Failed to fetch reminder from cache: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Retrieve reminders from SwiftData cache for a user
    private func getRemindersFromCache(userId: String, completed: Bool? = nil) -> [Reminder] {
        do {
            let predicate: Predicate<ReminderEntity>
            if let completed = completed {
                predicate = #Predicate<ReminderEntity> { $0.userId == userId && $0.completed == completed }
            } else {
                predicate = #Predicate<ReminderEntity> { $0.userId == userId }
            }
            
            let descriptor = FetchDescriptor<ReminderEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.map { $0.toReminder() }
        } catch {
            logger.error("Failed to fetch reminders from cache: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Retrieve reminders from SwiftData cache for a conversation
    private func getRemindersFromCacheForConversation(conversationId: String) -> [Reminder] {
        do {
            let predicate = #Predicate<ReminderEntity> { $0.conversationId == conversationId }
            let descriptor = FetchDescriptor<ReminderEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            return entities.map { $0.toReminder() }
        } catch {
            logger.error("Failed to fetch reminders from cache for conversation: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Delete reminder from SwiftData cache
    private func deleteReminderFromCache(id: String) {
        do {
            let predicate = #Predicate<ReminderEntity> { $0.reminderId == id }
            let descriptor = FetchDescriptor<ReminderEntity>(predicate: predicate)
            
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
                logger.debug("Reminder deleted from cache: \(id)")
            }
        } catch {
            logger.error("Failed to delete reminder from cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD Methods
    
    /// Creates a new reminder in Firestore
    /// - Parameter reminder: Reminder to create
    /// - Returns: Created reminder
    /// - Throws: Error if creation fails
    func createReminder(_ reminder: Reminder) async throws -> Reminder {
        logger.info("Creating reminder: \(reminder.reminderId)")
        
        do {
            // 1. Cache locally first for optimistic UI
            await cacheReminder(reminder)
            
            // 2. Create reminder in Firestore
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
        
        // 1. Try local cache first
        if let cachedReminder = getReminderFromCache(id: id) {
            logger.info("Reminder found in cache: \(id)")
            
            // 2. Refresh from Firestore in background if online
            if networkMonitor.isConnected {
                Task {
                    await refreshReminderFromFirestore(id: id)
                }
            }
            
            return cachedReminder
        }
        
        // 3. If not in cache, fetch from Firestore
        return try await fetchAndCacheReminder(id: id)
    }
    
    /// Fetch reminder from Firestore and cache it
    private func fetchAndCacheReminder(id: String) async throws -> Reminder? {
        do {
            let docRef = db.collection(remindersCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Reminder not found: \(id)")
                return nil
            }
            
            let reminder = try snapshot.data(as: Reminder.self)
            logger.info("Reminder fetched successfully: \(id)")
            
            // Cache the reminder
            await cacheReminder(reminder)
            
            return reminder
            
        } catch {
            logger.error("Failed to fetch reminder: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Refresh reminder from Firestore silently (background operation)
    private func refreshReminderFromFirestore(id: String) async {
        do {
            let docRef = db.collection(remindersCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists, let reminder = try? snapshot.data(as: Reminder.self) {
                await cacheReminder(reminder)
                logger.debug("Reminder refreshed from Firestore: \(id)")
            }
        } catch {
            logger.debug("Failed to refresh reminder from Firestore: \(error.localizedDescription)")
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
        
        // If offline, return cached reminders only
        if !networkMonitor.isConnected {
            logger.info("Offline mode - returning cached reminders for user: \(userId)")
            return getRemindersFromCache(userId: userId, completed: completed)
        }
        
        // Online: fetch from Firestore and update cache
        do {
            var query = db.collection(remindersCollection)
                .whereField("userId", isEqualTo: userId)
            
            if let completed = completed {
                query = query.whereField("completed", isEqualTo: completed)
            }
            
            query = query.order(by: "dueDate", descending: false)
            
            let snapshot = try await query.getDocuments()
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            
            // Cache all fetched reminders
            await cacheReminders(reminders)
            
            logger.info("Fetched \(reminders.count) reminders for user: \(userId)")
            return reminders
            
        } catch {
            logger.error("Failed to list reminders: \(error.localizedDescription)")
            // Fallback to cache on error
            logger.info("Falling back to cached reminders")
            return getRemindersFromCache(userId: userId, completed: completed)
        }
    }
    
    /// Lists all reminders for a conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Array of reminders
    /// - Throws: Error if fetch fails
    func listRemindersForConversation(conversationId: String) async throws -> [Reminder] {
        logger.info("Listing reminders for conversation: \(conversationId)")
        
        // If offline, return cached reminders only
        if !networkMonitor.isConnected {
            logger.info("Offline mode - returning cached reminders for conversation: \(conversationId)")
            return getRemindersFromCacheForConversation(conversationId: conversationId)
        }
        
        // Online: fetch from Firestore and update cache
        do {
            let query = db.collection(remindersCollection)
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "dueDate", descending: false)
            
            let snapshot = try await query.getDocuments()
            let reminders = snapshot.documents.compactMap { try? $0.data(as: Reminder.self) }
            
            // Cache all fetched reminders
            await cacheReminders(reminders)
            
            logger.info("Fetched \(reminders.count) reminders for conversation: \(conversationId)")
            return reminders
            
        } catch {
            logger.error("Failed to list reminders for conversation: \(error.localizedDescription)")
            // Fallback to cache on error
            logger.info("Falling back to cached reminders")
            return getRemindersFromCacheForConversation(conversationId: conversationId)
        }
    }
    
    /// Updates an existing reminder
    /// - Parameter reminder: Reminder with updated data
    /// - Throws: Error if update fails
    func updateReminder(_ reminder: Reminder) async throws {
        logger.info("Updating reminder: \(reminder.reminderId)")
        
        do {
            // 1. Update cache first for optimistic UI
            await cacheReminder(reminder)
            
            // 2. Update reminder in Firestore
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
            // 1. Delete from cache first
            deleteReminderFromCache(id: id)
            
            // 2. Delete reminder from Firestore
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
                // Delete from cache if it was removed
                Task { @MainActor in
                    self.deleteReminderFromCache(id: id)
                }
                onChange(nil)
                return
            }
            
            do {
                let reminder = try snapshot.data(as: Reminder.self)
                self.logger.info("Reminder updated via listener: \(id)")
                
                // Cache the updated reminder
                Task { @MainActor in
                    await self.cacheReminder(reminder)
                }
                
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
            
            // Cache all reminders
            Task { @MainActor in
                await self.cacheReminders(reminders)
            }
            
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

