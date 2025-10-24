//
//  ConversationListView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct ConversationListView: View {
    
    // MARK: - Environment & State
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: ConversationListViewModel
    @State private var showSettings: Bool = false
    @State private var showNewMessage: Bool = false
    @State private var showNewGroupChat: Bool = false
    @State private var showGlobalDecisions: Bool = false  // NEW - Story 5.2 AC6
    @State private var showCalendar: Bool = false  // NEW - Story 5.1.5
    @State private var navigationPath = NavigationPath()
    @State private var pendingNavigationConversationId: String?
    @State private var pendingNavigationMessageId: String?
    
    // Store service references for UserSearchView
    private let firestoreService: FirestoreService
    private let authService: AuthService
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService) {
        self.firestoreService = firestoreService
        self.authService = authService
        _viewModel = StateObject(wrappedValue: ConversationListViewModel(
            firestoreService: firestoreService,
            authService: authService,
            modelContext: nil // Will be set via environment
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    // Loading state
                    loadingView
                } else if viewModel.conversations.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Conversation list
                    conversationListView
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { conversationId in
                // Navigate to conversation when tapped from notification (Story 3.4)
                if let conversation = viewModel.conversations.first(where: { $0.conversationId == conversationId }) {
                    let otherUserId = viewModel.getOtherParticipantId(for: conversation)
                    
                    // Check if this is a navigation with message highlighting (Story 5.1.6)
                    let highlightMessageId = (pendingNavigationConversationId == conversationId) ? 
                        pendingNavigationMessageId : nil
                    
                    ChatView(
                        conversationId: conversationId,
                        otherUserId: otherUserId,
                        highlightMessageId: highlightMessageId
                    )
                    .onAppear {
                        // Clear pending navigation after use
                        if pendingNavigationConversationId == conversationId {
                            pendingNavigationConversationId = nil
                            pendingNavigationMessageId = nil
                        }
                    }
                } else {
                    // Conversation not found in list, show error
                    Text("Conversation not found")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open settings and account options")
                }
                
                // Calendar button (Story 5.1.5)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCalendar = true
                    }) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Calendar")
                    .accessibilityHint("View events and reminders")
                }
                
                // Global Decisions button (Story 5.2 AC6)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showGlobalDecisions = true
                    }) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    .accessibilityLabel("All Decisions")
                    .accessibilityHint("View all decisions across conversations")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showNewMessage = true
                        }) {
                            Label("New Message", systemImage: "bubble.left")
                        }
                        
                        Button(action: {
                            showNewGroupChat = true
                        }) {
                            Label("New Group Chat", systemImage: "person.3.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("New conversation menu")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.preferredColorScheme)
            }
            .sheet(isPresented: $showNewMessage) {
                UserSearchView(
                    firestoreService: firestoreService,
                    authService: authService,
                    isGroupMode: false
                )
            }
            .sheet(isPresented: $showNewGroupChat) {
                UserSearchView(
                    firestoreService: firestoreService,
                    authService: authService,
                    isGroupMode: true
                )
            }
            .sheet(isPresented: $showGlobalDecisions) {
                // Global Decisions View (Story 5.2 AC6)
                NavigationStack {
                    DecisionsListView(conversationId: nil)
                }
            }
            .sheet(isPresented: $showCalendar) {
                // Calendar View (Story 5.1.5)
                CalendarView()
                    .environmentObject(authViewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onAppear {
                // Set the model context now that we have environment access
                viewModel.setModelContext(modelContext)
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                // Handle navigation from notification tap (Story 3.4)
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    print("📱 ConversationListView: Navigating to conversation from notification: \(conversationId)")
                    navigationPath.append(conversationId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversationWithMessage)) { notification in
                // Handle navigation with message highlighting (Story 5.1.6)
                if let conversationId = notification.userInfo?["conversationId"] as? String,
                   let messageId = notification.userInfo?["messageId"] as? String {
                    print("📱 ConversationListView: Navigating to conversation with message highlight: \(conversationId), message: \(messageId)")
                    
                    // Check if conversation exists
                    guard viewModel.conversations.contains(where: { $0.conversationId == conversationId }) else {
                        print("⚠️ ConversationListView: Conversation \(conversationId) not found")
                        // Could show an alert here if needed
                        return
                    }
                    
                    // Dismiss any open sheets first
                    showCalendar = false
                    showGlobalDecisions = false
                    
                    // Store the message ID for highlighting
                    pendingNavigationConversationId = conversationId
                    pendingNavigationMessageId = messageId
                    // Navigate to conversation
                    navigationPath.append(conversationId)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Loading spinner view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Empty state view when no conversations exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation to see it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    /// Main conversation list view
    private var conversationListView: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: chatDestination(for: conversation)) {
                ConversationRow(
                    conversation: conversation,
                    displayName: viewModel.getOtherParticipantName(for: conversation),
                    currentUserId: authViewModel.authService.currentUser?.userId ?? "",
                    isOnline: getPresenceStatus(for: conversation)
                )
            }
            .listRowSeparator(.visible)
            .listRowBackground(priorityBackground(for: conversation))  // Story 5.3 AC3
            .accessibilityLabel(conversationAccessibilityLabel(for: conversation))
            .accessibilityHint("Tap to open conversation")
            .onAppear {
                // Start presence listener when row becomes visible (1:1 only)
                if !conversation.isGroupChat {
                    let otherUserId = viewModel.getOtherParticipantId(for: conversation)
                    if !otherUserId.isEmpty {
                        viewModel.startPresenceListener(for: otherUserId)
                    }
                }
                
                // Start priority listener when row becomes visible (Story 5.3)
                viewModel.startPriorityListener(for: conversation.conversationId)
            }
            .onDisappear {
                // Stop presence listener when row disappears (1:1 only)
                if !conversation.isGroupChat {
                    let otherUserId = viewModel.getOtherParticipantId(for: conversation)
                    if !otherUserId.isEmpty {
                        viewModel.stopPresenceListener(for: otherUserId)
                    }
                }
                
                // NOTE: We do NOT stop priority listeners here because we want them
                // to continue running even when the row is off-screen or when the user
                // navigates to a chat. This ensures unread counts stay accurate.
                // Priority listeners are stopped in ConversationListViewModel.onDisappear()
            }
        }
        .listStyle(.plain)
    }
    
    /// Get priority background color for conversation (Story 5.3 AC3)
    private func priorityBackground(for conversation: Conversation) -> Color {
        guard let priority = viewModel.conversationPriorityMap[conversation.conversationId] else {
            return Color.clear
        }
        
        switch priority {
        case .medium:
            return Color.yellow.opacity(0.1)
        case .high:
            return Color.red.opacity(0.1)
        }
    }
    
    /// Get presence status for a conversation (nil for groups or not loaded)
    private func getPresenceStatus(for conversation: Conversation) -> Bool? {
        // Only show presence for 1:1 conversations
        guard !conversation.isGroupChat else { return nil }
        
        let otherUserId = viewModel.getOtherParticipantId(for: conversation)
        return viewModel.userPresenceMap[otherUserId]
    }
    
    /// Generate chat destination for navigation
    private func chatDestination(for conversation: Conversation) -> some View {
        let otherUserId = viewModel.getOtherParticipantId(for: conversation)
        return ChatView(
            conversationId: conversation.conversationId,
            otherUserId: otherUserId
        )
    }
    
    /// Generate accessibility label for conversation row
    private func conversationAccessibilityLabel(for conversation: Conversation) -> String {
        let displayName = viewModel.getOtherParticipantName(for: conversation)
        let preview = conversation.lastMessageText ?? "No messages yet"
        let timestamp = DateFormatters.shared.formatConversationTimestamp(conversation.lastMessageTimestamp)
        return "Conversation with \(displayName), last message: \(preview), \(timestamp)"
    }
}

// MARK: - Conversation Row

/// Individual conversation row in the list
struct ConversationRow: View {
    let conversation: Conversation
    let displayName: String
    let currentUserId: String
    let isOnline: Bool?  // Optional: nil for group chats or when not loaded
    
    /// Check if conversation has unread messages
    private var hasUnreadMessages: Bool {
        conversation.unreadCount > 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with presence indicator (group icon for groups, initials for 1:1)
            avatarWithPresence
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Display name (with group icon if group chat)
                    HStack(spacing: 6) {
                        if conversation.isGroupChat {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                        
                        Text(displayName)
                            .font(.system(size: 17, weight: hasUnreadMessages ? .bold : .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Unread badge
                    if hasUnreadMessages {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                    
                    // Timestamp
                    Text(DateFormatters.shared.formatConversationTimestamp(conversation.lastMessageTimestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                // Message preview (with sender name prefix for groups)
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Avatar circle with initials or group icon, plus presence indicator
    private var avatarWithPresence: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main avatar circle
            Circle()
                .fill(avatarColor)
                .frame(width: 50, height: 50)
                .overlay(
                    Group {
                        if conversation.isGroupChat {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text(avatarInitials)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                )
            
            // Presence indicator (only for 1:1 chats with presence data)
            if !conversation.isGroupChat, let isOnline = isOnline {
                Circle()
                    .fill(isOnline ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: -2, y: -2)  // Position at bottom-right
                    .accessibilityLabel(isOnline ? "User is online" : "User is offline")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: isOnline)
            }
        }
    }
    
    /// Get initials from display name
    private var avatarInitials: String {
        let words = displayName.split(separator: " ")
        if words.isEmpty {
            return "?"
        } else if words.count == 1 {
            return String(words[0].prefix(1)).uppercased()
        } else {
            let first = words[0].prefix(1)
            let last = words[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
    }
    
    /// Generate avatar color based on conversation ID
    private var avatarColor: Color {
        // Generate consistent color based on conversation ID
        let hash = abs(conversation.conversationId.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Preview

#Preview {
    let authService = AuthService(firestoreService: FirestoreService())
    let firestoreService = FirestoreService()
    
    ConversationListView(
        firestoreService: firestoreService,
        authService: authService
    )
    .environmentObject(AuthViewModel())
    .environmentObject(ThemeManager())
    .modelContainer(PersistenceController.preview.modelContainer)
}

