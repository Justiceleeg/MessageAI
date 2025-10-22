//
//  NotificationManager.swift
//  MessageAI
//
//  Story 3.4: Implement Notification System (Mock Push for Demo)
//  Service to coordinate all notification logic for the app
//

import Foundation
import SwiftUI
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

/// Manages all notification functionality including in-app banners and local notifications
@Observable
class NotificationManager: NSObject {
    // MARK: - Properties
    
    /// Currently viewed conversation ID (for suppression logic)
    var currentlyViewedConversationId: String?
    
    /// In-app banner state
    var showBanner: Bool = false
    var bannerConversationId: String?
    var bannerTitle: String?
    var bannerMessage: String?
    
    /// Permission status (internal state, not observed)
    @ObservationIgnored
    private var hasPermission: Bool = false
    
    /// Firestore listeners for new messages (one per conversation)
    @ObservationIgnored
    private var messageListeners: [String: ListenerRegistration] = [:]
    
    /// Firestore listener for conversations
    @ObservationIgnored
    private var conversationsListener: ListenerRegistration?
    
    /// Track which conversations have completed their initial snapshot
    /// (to avoid triggering notifications for existing messages on login)
    @ObservationIgnored
    private var conversationsInitialLoadComplete: Set<String> = []
    
    /// Reference to Firestore (lazy to avoid accessing before Firebase configuration)
    @ObservationIgnored
    private lazy var db = Firestore.firestore()
    
    /// Banner auto-dismiss task (internal state, not observed)
    @ObservationIgnored
    private var bannerDismissTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        print("NotificationManager: Initialized")
        
        // Load stored permission status
        hasPermission = UserDefaults.standard.bool(forKey: "notificationPermission")
        print("NotificationManager: Loaded permission status: \(hasPermission)")
    }
    
    // MARK: - Public Methods
    
    /// Request notification permissions from user
    /// - Returns: Bool indicating if permissions were granted
    func requestNotificationPermissions() async -> Bool {
        print("NotificationManager: Requesting notification permissions")
        
        // Check if we already have permission status stored
        let currentPermission = UserDefaults.standard.object(forKey: "notificationPermission") as? Bool
        if let currentPermission = currentPermission {
            print("NotificationManager: Already have stored permission: \(currentPermission)")
        }
        
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            hasPermission = granted
            UserDefaults.standard.set(granted, forKey: "notificationPermission")
            
            print("NotificationManager: Notification permissions \(granted ? "granted" : "denied")")
            return granted
        } catch {
            print("NotificationManager: Error requesting notification permissions: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Start listening for new messages across all user's conversations
    /// - Parameter userId: The current user's ID
    func startListening(userId: String) {
        print("NotificationManager: Starting to listen for new messages for user: \(userId)")
        
        // First, listen to all conversations where user is a participant
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("NotificationManager: Error listening to conversations: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("NotificationManager: No conversations snapshot received")
                    return
                }
                
                // Handle conversation changes
                snapshot.documentChanges.forEach { change in
                    let conversationId = change.document.documentID
                    
                    switch change.type {
                    case .added:
                        // New conversation - start listening to its messages
                        self.startListeningToConversation(conversationId: conversationId, userId: userId)
                        
                    case .removed:
                        // Conversation removed - stop listening
                        self.stopListeningToConversation(conversationId: conversationId)
                        
                    case .modified:
                        // Conversation modified - listener already exists
                        break
                    }
                }
            }
    }
    
    /// Stop listening for new messages (cleanup)
    func stopListening() {
        print("NotificationManager: Stopping all message listeners")
        
        // Remove all message listeners
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
        
        // Remove conversations listener
        conversationsListener?.remove()
        conversationsListener = nil
        
        // Clear initial load tracking (so fresh login triggers initial load again)
        conversationsInitialLoadComplete.removeAll()
    }
    
    /// Start listening to messages in a specific conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID to listen to
    ///   - userId: The current user's ID
    private func startListeningToConversation(conversationId: String, userId: String) {
        print("NotificationManager: Starting listener for conversation: \(conversationId)")
        
        // Check if already listening to this conversation
        guard messageListeners[conversationId] == nil else {
            print("NotificationManager: Already listening to conversation: \(conversationId)")
            return
        }
        
        // Set up listener for this conversation's messages
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("NotificationManager: Error listening to messages in \(conversationId): \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("NotificationManager: No messages snapshot for conversation: \(conversationId)")
                    return
                }
                
                // Check if this is the initial snapshot (first load of existing messages)
                let isInitialSnapshot = !self.conversationsInitialLoadComplete.contains(conversationId)
                
                if isInitialSnapshot {
                    // Mark this conversation as having completed initial load
                    self.conversationsInitialLoadComplete.insert(conversationId)
                    print("NotificationManager: Initial snapshot for conversation \(conversationId) - skipping notifications for existing messages")
                    return
                }
                
                // Only process new messages (not initial load or modifications)
                // After initial snapshot, any .added changes are genuinely new messages
                snapshot.documentChanges.forEach { change in
                    if change.type == .added {
                        self.handleNewMessage(
                            conversationId: conversationId,
                            messageData: change.document.data(),
                            currentUserId: userId
                        )
                    }
                }
            }
        
        // Store the listener
        messageListeners[conversationId] = listener
    }
    
    /// Stop listening to messages in a specific conversation
    /// - Parameter conversationId: The conversation ID to stop listening to
    private func stopListeningToConversation(conversationId: String) {
        print("NotificationManager: Stopping listener for conversation: \(conversationId)")
        
        messageListeners[conversationId]?.remove()
        messageListeners.removeValue(forKey: conversationId)
        conversationsInitialLoadComplete.remove(conversationId)
    }
    
    /// Check if notification should be suppressed for a conversation
    /// - Parameter conversationId: The conversation ID to check
    /// - Returns: True if notification should be suppressed
    func shouldSuppressNotification(for conversationId: String) -> Bool {
        let shouldSuppress = conversationId == currentlyViewedConversationId
        if shouldSuppress {
            print("NotificationManager: Suppressing notification for conversation: \(conversationId) (currently viewing)")
        }
        return shouldSuppress
    }
    
    /// Show in-app banner notification
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - title: Banner title (sender name or group context)
    ///   - message: Message preview text
    func showInAppBanner(conversationId: String, title: String, message: String) {
        print("NotificationManager: Attempting to show in-app banner for conversation: \(conversationId)")
        
        guard !shouldSuppressNotification(for: conversationId) else {
            print("NotificationManager: Suppressing in-app banner for conversation: \(conversationId)")
            return
        }
        
        // Cancel any existing auto-dismiss task
        bannerDismissTask?.cancel()
        
        // Update banner state
        bannerConversationId = conversationId
        bannerTitle = title
        bannerMessage = message
        showBanner = true
        
        print("NotificationManager: Showing in-app banner - Title: '\(title)', Message: '\(message)'")
        
        // Auto-dismiss after 5 seconds
        bannerDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if !Task.isCancelled {
                    self.dismissBanner()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    /// Dismiss the in-app banner
    func dismissBanner() {
        print("NotificationManager: Dismissing in-app banner")
        bannerDismissTask?.cancel()
        showBanner = false
        bannerConversationId = nil
        bannerTitle = nil
        bannerMessage = nil
    }
    
    /// Schedule a local notification
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - title: Notification title
    ///   - body: Notification body text
    func scheduleLocalNotification(conversationId: String, title: String, body: String) {
        print("NotificationManager: Attempting to schedule local notification for conversation: \(conversationId)")
        
        guard hasPermission else {
            print("NotificationManager: Cannot schedule notification - permission not granted")
            return
        }
        
        guard !shouldSuppressNotification(for: conversationId) else {
            print("NotificationManager: Suppressing local notification for conversation: \(conversationId)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.count > 100 ? String(body.prefix(100)) + "..." : body
        content.sound = .default
        content.userInfo = ["conversationId": conversationId]
        
        // Immediate trigger (0.1 seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("NotificationManager: Scheduled local notification - Title: '\(title)', Body: '\(body)'")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle a new message detected by Firestore listener
    /// - Parameters:
    ///   - conversationId: The conversation ID where the message was sent
    ///   - messageData: The message document data
    ///   - currentUserId: The current user's ID
    private func handleNewMessage(conversationId: String, messageData: [String: Any], currentUserId: String) {
        // Extract message data
        guard let senderId = messageData["senderId"] as? String,
              let text = messageData["text"] as? String else {
            print("NotificationManager: Invalid message data")
            return
        }
        
        // Don't notify for own messages
        if senderId == currentUserId {
            print("NotificationManager: Ignoring own message")
            return
        }
        
        print("NotificationManager: New message detected - ConversationID: \(conversationId), SenderId: \(senderId)")
        
        // Fetch sender name and conversation details
        Task { @MainActor in
            await self.fetchDetailsAndTriggerNotification(
                conversationId: conversationId,
                senderId: senderId,
                messageText: text
            )
        }
    }
    
    /// Fetch sender and conversation details, then trigger appropriate notification
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - senderId: The sender's user ID
    ///   - messageText: The message text
    @MainActor
    private func fetchDetailsAndTriggerNotification(
        conversationId: String,
        senderId: String,
        messageText: String
    ) async {
        print("NotificationManager: Fetching details for notification")
        
        // Fetch sender name
        var senderName = "Someone"
        do {
            let userDoc = try await db.collection("users").document(senderId).getDocument()
            if let displayName = userDoc.data()?["displayName"] as? String {
                senderName = displayName
            }
        } catch {
            print("NotificationManager: Error fetching sender name: \(error.localizedDescription)")
        }
        
        // Fetch conversation to check if it's a group chat
        var title = senderName
        do {
            let convDoc = try await db.collection("conversations").document(conversationId).getDocument()
            if let isGroup = convDoc.data()?["isGroup"] as? Bool, isGroup,
               let groupName = convDoc.data()?["groupName"] as? String {
                title = "\(senderName) in \(groupName)"
            }
        } catch {
            print("NotificationManager: Error fetching conversation: \(error.localizedDescription)")
        }
        
        // Check app state and trigger appropriate notification
        let isInForeground = UIApplication.shared.applicationState == .active
        
        if isInForeground {
            print("NotificationManager: App in foreground, showing in-app banner")
            showInAppBanner(conversationId: conversationId, title: title, message: messageText)
        } else {
            print("NotificationManager: App in background, scheduling local notification")
            scheduleLocalNotification(conversationId: conversationId, title: title, body: messageText)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Called when a notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("NotificationManager: Notification received in foreground")
        
        // Show notification banner and play sound in foreground
        completionHandler([.banner, .sound])
    }
    
    /// Called when user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("NotificationManager: User tapped notification with userInfo: \(userInfo)")
        
        if let conversationId = userInfo["conversationId"] as? String {
            print("NotificationManager: Navigating to conversation: \(conversationId)")
            
            // Post notification for navigation
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
            
            // Dismiss banner if showing
            dismissBanner()
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user taps a notification to navigate to a conversation
    static let navigateToConversation = Notification.Name("navigateToConversation")
}

