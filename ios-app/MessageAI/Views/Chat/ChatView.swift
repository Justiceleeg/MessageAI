//
//  ChatView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//  Updated by Dev Agent on 2025-10-21.
//

import SwiftUI

/// Chat view for displaying and sending messages in a conversation
struct ChatView: View {
    
    // MARK: - Properties
    
    /// The conversation ID (optional for new conversations)
    let conversationId: String?
    
    /// The other user's ID (for 1:1 chats)
    let otherUserId: String
    
    /// Group participants (for group chats - lazy creation)
    let groupParticipants: [User]?
    
    /// Group name (optional, for group chats)
    let groupName: String?
    
    /// Message ID to highlight when view appears (for navigation from events/reminders/decisions)
    let highlightMessageId: String?
    
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // Services
    private let eventService = EventService()
    
    // State for retry action sheet
    @State private var showRetryActionSheet = false
    @State private var selectedMessageForRetry: Message?
    
    // State for AI features (Story 5.1 & 5.2)
    @State private var showEventCreationModal = false
    @State private var selectedEventData: CalendarDetection?
    @State private var selectedMessageId: String?
    
    @State private var showDecisionConfirmationModal = false
    @State private var selectedDecisionData: DecisionDetection?
    
    // State for unified event creation (Story 5.1 & 5.4)
    @State private var showEventInvitationModal = false
    
    // State for similar event detection (Story 5.6)
    @State private var showSimilarEventModal = false
    
    // State for conflict warning modal (Story 5.6)
    @State private var showConflictWarningModal = false
    
    // State for reminder features (Story 5.5)
    @State private var showReminderCreationModal = false
    @State private var selectedReminderData: ReminderDetection?
    
    @State private var showPerChatDecisions = false  // NEW - Story 5.2 AC5
    @State private var showCalendar = false  // NEW - Story 5.1.5
    @State private var showPerChatReminders = false  // NEW - Story 5.5 AC5
    
    // Message highlighting state (Story 5.1.6)
    @State private var highlightedMessageId: String? = nil
    
    // MARK: - Initialization
    
    init(conversationId: String?, otherUserId: String, groupParticipants: [User]? = nil, groupName: String? = nil, highlightMessageId: String? = nil) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.groupParticipants = groupParticipants
        self.groupName = groupName
        self.highlightMessageId = highlightMessageId
        
        // Initialize ViewModel with parameters (uses convenience initializer)
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            otherUserId: otherUserId,
            groupParticipants: groupParticipants,
            groupName: groupName
        ))
    }
    
    // Initializer for testing with custom services
    init(conversationId: String?, otherUserId: String, viewModel: ChatViewModel, highlightMessageId: String? = nil) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.groupParticipants = nil
        self.groupName = nil
        self.highlightMessageId = highlightMessageId
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ZStack(alignment: .bottomLeading) {
                messageListView
                
                // Typing indicator (Story 3.5) - positioned at bottom left, flush to bottom
                if !viewModel.typingUsers.isEmpty {
                    TypingIndicatorView(typingUsers: viewModel.typingUsers)
                        .padding(.leading, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.typingUsers.count)
                }
            }
            
            // Message input bar
            MessageInputBar(
                messageText: $viewModel.messageText,
                isSending: viewModel.isSending,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
            .onChange(of: viewModel.messageText) { oldValue, newValue in
                // Handle typing state change (Story 3.5)
                viewModel.handleTypingChange(oldValue: oldValue, newValue: newValue)
            }
        }
        .navigationTitle(viewModel.otherUserDisplayName.isEmpty ? "Chat" : viewModel.otherUserDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Presence subtitle for 1:1 chats (Story 3.3)
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(viewModel.otherUserDisplayName.isEmpty ? "Chat" : viewModel.otherUserDisplayName)
                        .font(.headline)
                    
                    // Show presence subtitle only for 1:1 chats
                    if !viewModel.isGroupChat {
                        Text(viewModel.formatLastSeen(userId: otherUserId))
                            .font(.caption)
                            .foregroundColor(viewModel.participantPresence[otherUserId] == true ? .green : .gray)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.participantPresence[otherUserId])
                            .accessibilityLabel(viewModel.formatLastSeen(userId: otherUserId))
                    }
                }
            }
            
            // Chat menu button (consolidated from three separate buttons)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Calendar option
                    Button(action: {
                        showCalendar = true
                    }) {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .accessibilityLabel("Calendar")
                    .accessibilityHint("View events and reminders")
                    
                    // Decisions option
                    Button(action: {
                        showPerChatDecisions = true
                    }) {
                        Label("Chat Decisions", systemImage: "checkmark.circle")
                    }
                    .accessibilityLabel("Chat Decisions")
                    .accessibilityHint("View decisions from this conversation")
                    
                    // Reminders option
                    Button(action: {
                        showPerChatReminders = true
                    }) {
                        Label("Chat Reminders", systemImage: "bell")
                    }
                    .accessibilityLabel("Chat Reminders")
                    .accessibilityHint("View reminders from this conversation")
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Chat Menu")
                .accessibilityHint("Open chat options menu")
            }
        }
        .onAppear {
            viewModel.onAppear()
            
            // Set currently viewed conversation for notification suppression (Story 3.4)
            if let conversationId = conversationId {
                notificationManager.currentlyViewedConversationId = conversationId
            }
        }
        .onDisappear {
            viewModel.onDisappear()
            
            // Clear currently viewed conversation (Story 3.4)
            notificationManager.currentlyViewedConversationId = nil
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
        .sheet(isPresented: $showEventCreationModal) {
            if let eventData = selectedEventData,
               let messageId = selectedMessageId,
               let conversationId = conversationId {
                EventCreationView(
                    initialData: eventData,
                    messageId: messageId,
                    conversationId: conversationId
                ) { event in
                    // Event created successfully - dismiss AI prompt
                    viewModel.dismissAISuggestion(for: messageId)
                    print("Event created: \(event.title)")
                }
            }
        }
        .sheet(isPresented: $showDecisionConfirmationModal) {
            if let decisionData = selectedDecisionData,
               let messageId = selectedMessageId,
               let conversationId = conversationId {
                DecisionConfirmationView(
                    initialData: decisionData,
                    messageId: messageId,
                    conversationId: conversationId
                ) { decision in
                    // Decision saved successfully - dismiss AI prompt
                    viewModel.dismissAISuggestion(for: messageId)
                    print("Decision saved: \(decision.text)")
                }
            }
        }
        .sheet(isPresented: $showEventInvitationModal) {
            if let messageId = selectedMessageId,
               let conversationId = conversationId,
               let analysis = viewModel.aiSuggestions[messageId] {
                EventInvitationModal(
                    analysis: analysis,
                    messageId: messageId,
                    conversationId: conversationId
                ) { event in
                    // Event created with invitations successfully - create via AI backend (indexes in Pinecone), store in Firestore, link to chat, and dismiss AI prompt
                    Task {
                        do {
                            // Create event via AI backend first (this indexes it in Pinecone for conflict detection)
                            let backendResponse = try await AIBackendService.shared.createEvent(
                                title: event.title,
                                date: formatDateISO(event.date),
                                startTime: event.startTime,
                                endTime: event.endTime,
                                duration: event.duration,
                                location: event.location,
                                userId: AuthService.shared.currentUser?.userId ?? "unknown",
                                conversationId: conversationId,
                                messageId: messageId
                            )
                            
                            if backendResponse.success {
                                print("Event created and indexed in Pinecone: \(event.title)")
                                
                                // Store event in Firestore for local persistence
                                _ = try await eventService.createEvent(event)
                                print("Event stored in Firestore: \(event.title)")
                                
                                // Link event to chat if there are invitations
                                if !event.invitations.isEmpty {
                                    let invitation = event.invitations[conversationId]
                                    if let invitation = invitation {
                                        try await eventService.linkEventToChat(
                                            eventId: event.eventId,
                                            conversationId: conversationId,
                                            messageId: messageId,
                                            invitedUserIds: invitation.invitedUserIds
                                        )
                                        print("Event linked to chat with \(invitation.invitedUserIds.count) participants")
                                    }
                                }
                            } else {
                                print("Backend event creation failed: \(backendResponse.message)")
                                // Still store in Firestore as fallback
                                _ = try await eventService.createEvent(event)
                                print("Event stored in Firestore as fallback: \(event.title)")
                            }
                        } catch {
                            print("Failed to create/store/link event: \(error.localizedDescription)")
                            // Fallback: store in Firestore only
                            do {
                                _ = try await eventService.createEvent(event)
                                print("Event stored in Firestore as fallback: \(event.title)")
                            } catch {
                                print("Failed to store event in Firestore: \(error.localizedDescription)")
                            }
                        }
                    }
                    viewModel.dismissAISuggestion(for: messageId)
                }
            }
        }
        .sheet(isPresented: $showReminderCreationModal) {
            if let _ = selectedReminderData,
               let messageId = selectedMessageId,
               let conversationId = conversationId,
               let analysis = viewModel.aiSuggestions[messageId] {
                ReminderCreationModal(
                    analysis: analysis,
                    messageId: messageId,
                    conversationId: conversationId
                ) { reminder in
                    // Reminder created successfully - dismiss AI prompt
                    viewModel.dismissAISuggestion(for: messageId)
                    print("Reminder created: \(reminder.title)")
                }
            }
        }
        .sheet(isPresented: $showPerChatDecisions) {
            // Per-Chat Decisions View (Story 5.2 AC5)
            if let conversationId = conversationId {
                NavigationStack {
                    DecisionsListView(conversationId: conversationId)
                }
            }
        }
        .sheet(isPresented: $showCalendar) {
            // Calendar & Reminders View (Story 5.1.5)
            // Filter to show only events/reminders from this conversation
            NavigationStack {
                CalendarView(conversationId: conversationId)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showPerChatReminders) {
            // Per-Chat Reminders View (Story 5.5 AC5)
            if let conversationId = conversationId {
                ChatRemindersView(conversationId: conversationId)
            }
        }
        .sheet(isPresented: $showSimilarEventModal) {
            // Similar Event Detection Modal (Story 5.6)
            if let messageId = selectedMessageId,
               let conversationId = conversationId,
               let analysis = viewModel.aiSuggestions[messageId],
               let eventData = selectedEventData {
                SimilarEventModal(
                    messageId: messageId,
                    conversationId: conversationId,
                    calendarData: eventData,
                    analysis: analysis,
                    onDismiss: {
                        showSimilarEventModal = false
                    },
                    onLinkToEvent: { eventId in
                        // Link to existing event - invite participants
                        Task {
                            do {
                                // Get conversation participants (excluding current user)
                                    guard let currentUser = AuthService.shared.currentUser else {
                                        return
                                    }
                                
                                // Get conversation to find participants
                                let firestoreService = FirestoreService()
                                let conversation = try await firestoreService.getConversation(conversationId: conversationId)
                                
                                // Get participants to invite (exclude current user)
                                let participantsToInvite = conversation.participants.filter { $0 != currentUser.userId }
                                
                                if participantsToInvite.isEmpty {
                                    return
                                }
                                
                                // Link the existing event to this conversation
                                try await eventService.linkEventToChat(
                                    eventId: eventId,
                                    conversationId: conversationId,
                                    messageId: messageId,
                                    invitedUserIds: participantsToInvite
                                )
                                
                                // Dismiss the AI suggestion
                                await MainActor.run {
                                    viewModel.dismissAISuggestion(for: messageId)
                                }
                                
                            } catch {
                                // Still dismiss the AI suggestion to avoid confusion
                                await MainActor.run {
                                    viewModel.dismissAISuggestion(for: messageId)
                                }
                            }
                        }
                        showSimilarEventModal = false
                    },
                    onCreateNewEvent: {
                        // Create new event - show normal event creation modal
                        showSimilarEventModal = false
                        showEventInvitationModal = true
                    }
                )
            }
        }
        .sheet(isPresented: $showConflictWarningModal) {
            // Conflict Warning Modal (Story 5.6)
            if let messageId = selectedMessageId,
               let conversationId = conversationId,
               let analysis = viewModel.aiSuggestions[messageId],
               let eventData = selectedEventData {
                ConflictWarningModal(
                    messageId: messageId,
                    conversationId: conversationId,
                    calendarData: eventData,
                    analysis: analysis,
                    onDismiss: {
                        showConflictWarningModal = false
                    },
                    onCreateAnyway: {
                        // Create event anyway - show normal event creation modal
                        showConflictWarningModal = false
                        showEventInvitationModal = true
                    }
                )
            }
        }
    }
    
    // MARK: - Message List View
    
    private var messageListView: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading messages...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if viewModel.messages.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Messages list
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                VStack(alignment: .leading, spacing: 0) {
                                    let isSentByCurrentUser = viewModel.isSentByCurrentUser(message: message)
                                    let messageStatus = viewModel.computeMessageStatus(for: message)
                                    let isGroupChat = viewModel.conversation?.isGroupChat ?? false
                                    let senderName = !isSentByCurrentUser ? viewModel.getSenderDisplayName(userId: message.senderId) : nil
                                    let isOnline = viewModel.participantPresence[message.senderId]
                                    let readCount = viewModel.calculateReadCount(for: message)
                                    let shouldShowReadReceipt = viewModel.shouldShowReadReceipt(for: message)
                                    let isHighlighted = highlightedMessageId == message.id
                                    
                                    MessageBubbleView(
                                        message: message,
                                        isSentByCurrentUser: isSentByCurrentUser,
                                        status: messageStatus,
                                        onRetry: message.status == "failed" ? {
                                            selectedMessageForRetry = message
                                            showRetryActionSheet = true
                                        } : nil,
                                        isGroupChat: isGroupChat,
                                        senderName: senderName,
                                        isOnline: isOnline,
                                        readCount: readCount,
                                        shouldShowReadReceipt: shouldShowReadReceipt,
                                        isHighlighted: isHighlighted,
                                        conversationId: conversationId
                                    ) {
                                        // AI Prompt (Story 5.1) - Inline with timestamp
                                        // Only show if not dismissed
                                        if viewModel.isSentByCurrentUser(message: message),
                                           let analysis = viewModel.aiSuggestions[message.messageId],
                                           !viewModel.dismissedAISuggestions.contains(message.messageId) {
                                            Group {
                                                // Calendar events - unified flow (Story 5.6)
                                                if analysis.calendar.detected {
                                                    // Check for conflicts first (Story 5.6 - Event Conflict Detection)
                                                    if analysis.conflict.detected {
                                                        AIPromptButtonCompact(
                                                            icon: "exclamationmark.triangle.fill",
                                                            text: "Add to calendar",
                                                            tintColor: .orange
                                                        ) {
                                                            // Show conflict warning modal
                                                            selectedEventData = analysis.calendar
                                                            selectedMessageId = message.messageId
                                                            showConflictWarningModal = true
                                                        }
                                                    }
                                                    // Check for similar events (Story 5.6 - Similar Event Detection)
                                                    else if analysis.calendar.similarEvents?.isEmpty == false {
                                                        AIPromptButtonCompact(
                                                            icon: "link",
                                                            text: "Link to Event",
                                                            tintColor: .blue
                                                        ) {
                                                            // Show similar event modal
                                                            selectedEventData = analysis.calendar
                                                            selectedMessageId = message.messageId
                                                            showSimilarEventModal = true
                                                        }
                                                    }
                                                    // Regular calendar events
                                                    else {
                                                        AIPromptButtonCompact(
                                                            icon: "calendar.badge.plus",
                                                            text: "Add to calendar",
                                                            tintColor: .blue
                                                        ) {
                                                            // Normal event creation
                                                            selectedEventData = analysis.calendar
                                                            selectedMessageId = message.messageId
                                                            showEventInvitationModal = true
                                                        }
                                                    }
                                                }
                                                else if analysis.reminder.detected {
                                                    AIPromptButtonCompact(
                                                        icon: "bell.badge.fill",
                                                        text: "Set reminder",
                                                        tintColor: .orange
                                                    ) {
                                                        selectedReminderData = analysis.reminder
                                                        selectedMessageId = message.messageId
                                                        showReminderCreationModal = true
                                                    }
                                                } else if analysis.decision.detected {
                                                    AIPromptButtonCompact(
                                                        icon: "checkmark.circle.fill",
                                                        text: "Save decision",
                                                        tintColor: .green
                                                    ) {
                                                        selectedDecisionData = analysis.decision
                                                        selectedMessageId = message.messageId
                                                        showDecisionConfirmationModal = true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .id(message.id)
                                .onAppear {
                                    // Mark message as read when it appears (Story 3.2)
                                    _ = viewModel.markMessageAsReadIfVisible(messageId: message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 20)  // Space at bottom for typing indicator
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .onChange(of: viewModel.messages) { _, newMessages in
                        // Auto-scroll to bottom when new message arrives
                        if let lastMessage = newMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to bottom on initial load with delay to account for RSVP button loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let lastMessage = viewModel.messages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        
                        // Handle message highlighting (Story 5.1.6)
                        if let messageId = highlightMessageId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    scrollProxy.scrollTo(messageId, anchor: .center)
                                }
                                scrollToMessage(messageId: messageId)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Message Failed",
            isPresented: $showRetryActionSheet,
            presenting: selectedMessageForRetry
        ) { message in
            Button("Try Again") {
                Task {
                    await viewModel.retryMessage(message)
                }
            }
            
            Button("Delete Message", role: .destructive) {
                viewModel.deleteMessage(message)
            }
            
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: { _ in
            Text("This message couldn't be sent. What would you like to do?")
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            if conversationId == nil {
                // New conversation
                Text("Start the conversation")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if !viewModel.otherUserDisplayName.isEmpty {
                    Text("Say hi to \(viewModel.otherUserDisplayName)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            } else {
                // Existing conversation with no messages
                Text("No messages yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Send a message to start chatting")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Message Highlighting (Story 5.1.6)
    
    private func scrollToMessage(messageId: String) {
        // Check if message exists in the current messages
        guard viewModel.messages.contains(where: { $0.id == messageId }) else {
            // Could show an alert here if needed
            return
        }
        
        // Highlight the message (scrolling will be handled by the ScrollViewReader in the view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            highlightMessage(messageId)
        }
    }
    
    private func highlightMessage(_ messageId: String) {
        highlightedMessageId = messageId
        
        // Remove highlight after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                highlightedMessageId = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDateISO(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Existing Conversation") {
    NavigationStack {
        ChatView(
            conversationId: "conv_preview_123",
            otherUserId: "user_456"
        )
    }
}

#Preview("New Conversation") {
    NavigationStack {
        ChatView(
            conversationId: nil,
            otherUserId: "user_789"
        )
    }
}