//
//  MessageBubbleView.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import SwiftUI

/// Reusable message bubble component for chat interface
struct MessageBubbleView<AIPrompt: View>: View {
    
    let message: Message
    let isSentByCurrentUser: Bool
    let status: String  // Computed status from ChatViewModel (Story 3.2)
    let onRetry: (() -> Void)?
    let isGroupChat: Bool
    let senderName: String?
    let isOnline: Bool?  // Presence indicator for group chat sender (Story 3.3)
    let readCount: Int  // Number of users who have read this message (Story 4.1)
    let shouldShowReadReceipt: Bool  // Whether to show read receipt on this message (Story 4.1 UX)
    let aiPrompt: AIPrompt?  // Optional AI prompt view (Story 5.1)
    let isHighlighted: Bool  // Whether this message should be highlighted (Story 5.1.6)
    let conversationId: String?  // Conversation ID for RSVP actions (Story 5.4)
    
    // RSVP Modal State
    @State private var rsvpModalState: RSVPModalState = .hidden
    @State private var userRSVPStatus: RSVPStatus? = nil
    @State private var eventDate: Date? = nil
    @State private var isLoadingEventData = true
    
    // Enum to track which RSVP modal to show
    private enum RSVPModalState {
        case hidden
        case accept
        case decline
        
        var isPresented: Bool {
            self != .hidden
        }
        
        var status: RSVPStatus? {
            switch self {
            case .accept: return .accepted
            case .decline: return .declined
            case .hidden: return nil
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        message: Message,
        isSentByCurrentUser: Bool,
        status: String = "",
        onRetry: (() -> Void)? = nil,
        isGroupChat: Bool = false,
        senderName: String? = nil,
        isOnline: Bool? = nil,
        readCount: Int = 0,
        shouldShowReadReceipt: Bool = false,
        isHighlighted: Bool = false,
        conversationId: String? = nil,
        @ViewBuilder aiPrompt: () -> AIPrompt? = { nil }
    ) {
        self.message = message
        self.isSentByCurrentUser = isSentByCurrentUser
        self.status = status.isEmpty ? message.status : status
        self.onRetry = onRetry
        self.isGroupChat = isGroupChat
        self.senderName = senderName
    
        self.isOnline = isOnline
        self.readCount = readCount
        self.shouldShowReadReceipt = shouldShowReadReceipt
        self.isHighlighted = isHighlighted
        self.conversationId = conversationId
        self.aiPrompt = aiPrompt()
    }
    
    // MARK: - Computed Properties
    
    /// Inline RSVP buttons (compact circular design)
    @ViewBuilder
    private var inlineRSVPButtons: some View {
        if !isSentByCurrentUser,
           let metadata = message.metadata,
           metadata.isInvitation == true,
           let eventId = metadata.eventId,
           let conversationId = conversationId,
           shouldShowRSVPButtons {
            
            HStack(spacing: 8) {
                // Accept button
                Button(action: {
                    rsvpModalState = .accept
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.green))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept invitation")
                
                // Decline button
                Button(action: {
                    rsvpModalState = .decline
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline invitation")
            }
        }
    }
    
    /// Determines if RSVP buttons should be shown
    /// Hides buttons if user has already RSVP'd or event has passed
    private var shouldShowRSVPButtons: Bool {
        guard let metadata = message.metadata,
              let eventId = metadata.eventId else {
            return false
        }
        
        // Don't show buttons while loading event data to prevent flash
        if isLoadingEventData {
            return false
        }
        
        // Debug logging
        print("🔧 DEBUG: shouldShowRSVPButtons - userRSVPStatus: \(userRSVPStatus?.rawValue ?? "nil")")
        print("🔧 DEBUG: shouldShowRSVPButtons - eventDate: \(eventDate?.description ?? "nil")")
        
        // Hide buttons if user has already RSVP'd
        if let rsvpStatus = userRSVPStatus, rsvpStatus != .pending {
            print("🔧 DEBUG: Hiding buttons - user already RSVP'd: \(rsvpStatus.rawValue)")
            return false
        }
        
        // Hide buttons if event has passed
        if let eventDate = eventDate, eventDate < Date() {
            print("🔧 DEBUG: Hiding buttons - event has passed")
            return false
        }
        
        print("🔧 DEBUG: Showing RSVP buttons")
        return true
    }
    
    // MARK: - Event Data Loading
    
    /// Loads event data to determine if RSVP buttons should be shown
    private func loadEventData() {
        guard let metadata = message.metadata,
              let eventId = metadata.eventId else {
            isLoadingEventData = false
            return
        }
        
        Task {
            do {
                let eventService = EventService()
                if let event = try await eventService.getEvent(id: eventId) {
                    await MainActor.run {
                        print("🔧 DEBUG: loadEventData - setting eventDate: \(event.date)")
                        self.eventDate = event.date
                        
                        // Check if current user has already RSVP'd
                        if let currentUserId = AuthService.shared.currentUser?.userId,
                           let attendee = event.attendees[currentUserId] {
                            print("🔧 DEBUG: loadEventData - found existing RSVP: \(attendee.status.rawValue)")
                            // Only update if we don't already have a local state (to avoid overriding user actions)
                            if self.userRSVPStatus == nil {
                                print("🔧 DEBUG: loadEventData - setting userRSVPStatus to \(attendee.status.rawValue)")
                                self.userRSVPStatus = attendee.status
                            } else {
                                print("🔧 DEBUG: loadEventData - keeping existing userRSVPStatus: \(self.userRSVPStatus?.rawValue ?? "nil")")
                            }
                        } else {
                            print("🔧 DEBUG: loadEventData - no existing RSVP found for user")
                        }
                        
                        // Mark loading as complete
                        self.isLoadingEventData = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingEventData = false
                    }
                }
            } catch {
                // Event might not exist or user doesn't have access
                print("Could not load event data: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingEventData = false
                }
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: isSentByCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name with presence indicator (only for received messages in group chats)
            if !isSentByCurrentUser && isGroupChat, let senderName = senderName {
                HStack(spacing: 4) {
                    Text(senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Green dot if sender is online (Story 3.3)
                    if let isOnline = isOnline, isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("User is online")
                    }
                }
                .padding(.leading, 12)
            }
            
            // Message bubble with inline RSVP buttons for received invitations
            HStack(alignment: .center, spacing: 8) {
                if isSentByCurrentUser {
                    Spacer(minLength: 60)
                }
                
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(isSentByCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(bubbleBackgroundColor)
                            .overlay(
                                // Red border for failed messages
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(message.status == "failed" ? Color.red : Color.clear, lineWidth: 1)
                            )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                
                // Inline RSVP buttons (Story 5.4) - right after message bubble for received invitations
                if !isSentByCurrentUser {
                    inlineRSVPButtons
                }
                
                if !isSentByCurrentUser {
                    Spacer(minLength: 8)  // Reduced from 60 to allow more room for message + buttons
                }
            }
            
            // Timestamp, AI prompt, and status indicator (all on same line)
            HStack(spacing: 4) {
                // AI Prompt (Story 5.1) - appears first, before timestamp
                if let aiPrompt = aiPrompt {
                    aiPrompt
                }
                
                Text(formattedTimestamp)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                // Status indicator (only for sent messages)
                if isSentByCurrentUser {
                    statusIndicator
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            // Highlight background (Story 5.1.6)
            isHighlighted ? Color.yellow.opacity(0.3) : Color.clear
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onTapGesture {
            // Only tappable if failed and onRetry is provided
            if message.status == "failed", let onRetry = onRetry {
                onRetry()
            }
        }
        .onAppear {
            loadEventData()
        }
        .sheet(isPresented: Binding(
            get: { rsvpModalState.isPresented },
            set: { isPresented in
                if !isPresented {
                    rsvpModalState = .hidden
                }
            }
        )) {
            if let conversationId = conversationId,
               let metadata = message.metadata,
               let eventId = metadata.eventId,
               let preSelectedStatus = rsvpModalState.status {
                RSVPModal(
                    eventId: eventId,
                    eventTitle: message.text,
                    conversationId: conversationId,
                    preSelectedStatus: preSelectedStatus
                ) { status, message in
                    print("🔧 DEBUG: RSVP confirmed: \(status), message: \(message ?? "none")")
                    print("🔧 DEBUG: Updating userRSVPStatus from \(userRSVPStatus?.rawValue ?? "nil") to \(status.rawValue)")
                    // Update local state to hide RSVP buttons
                    userRSVPStatus = status
                    print("🔧 DEBUG: userRSVPStatus updated to: \(userRSVPStatus?.rawValue ?? "nil")")
                    // Reset modal state
                    rsvpModalState = .hidden
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Format timestamp as "10:30 AM"
    private var formattedTimestamp: String {
        DateFormatters.messageTime.string(from: message.timestamp)
    }
    
    /// Status indicator view based on message status (Story 3.2 - Read Receipts, Story 4.1 - Improved UI)
    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case "sending":
            // Gray spinner for sending state
            ProgressView()
                .controlSize(.mini)
                .tint(.gray)
                .accessibilityLabel("Sending message")
            
        case "sent":
            // Single gray checkmark for sent state
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .accessibilityLabel("Message sent")
            
        case "delivered":
            // Single gray checkmark for delivered state (Story 4.1)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .accessibilityLabel("Message delivered")
            
        case "read":
            // Only show blue badge on the latest read message (Story 4.1 UX optimization)
            if shouldShowReadReceipt {
                ReadReceiptBadge(readCount: readCount)
            } else {
                // Earlier read messages show nothing (assume they're read)
                EmptyView()
            }
            
        case "failed":
            // Red exclamation mark for failed state
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
                .accessibilityLabel("Message failed to send, tap to retry")
            
        default:
            // No indicator for empty or unknown states
            EmptyView()
        }
    }
    
    /// Background color for message bubble
    private var bubbleBackgroundColor: Color {
        if isSentByCurrentUser {
            // Slightly dimmed blue for failed messages
            return message.status == "failed" ? Color.blue.opacity(0.7) : Color.blue
        } else {
            return Color(uiColor: .systemGray5)
        }
    }
    
    /// VoiceOver accessibility label
    private var accessibilityLabel: String {
        let sender = isSentByCurrentUser ? "You" : "Other user"
        var label = "\(sender) sent: \(message.text), at \(formattedTimestamp)"
        
        // Add status to accessibility label (Story 3.2, Story 4.1)
        switch status {
        case "sending":
            label += ", sending"
        case "sent":
            label += ", sent"
        case "delivered":
            label += ", delivered"
        case "read":
            label += ", read by \(readCount) \(readCount == 1 ? "person" : "people")"
        case "failed":
            label += ", failed to send, tap to retry"
        default:
            break
        }
        
        return label
    }
}

// MARK: - Preview

#Preview("Sent Message") {
    MessageBubbleView(
        message: Message(
            id: "1",
            messageId: "1",
            senderId: "user1",
            text: "Hello! How are you doing today?",
            timestamp: Date(),
            status: "sent"
        ),
        isSentByCurrentUser: true
    ) {
        EmptyView()
    }
}

#Preview("Sending Message") {
    MessageBubbleView(
        message: Message(
            id: "2",
            messageId: "2",
            senderId: "user1",
            text: "This message is sending...",
            timestamp: Date(),
            status: "sending"
        ),
        isSentByCurrentUser: true
    ) {
        EmptyView()
    }
}

#Preview("Failed Message") {
    MessageBubbleView(
        message: Message(
            id: "3",
            messageId: "3",
            senderId: "user1",
            text: "This message failed to send",
            timestamp: Date(),
            status: "failed"
        ),
        isSentByCurrentUser: true,
        onRetry: {
            print("Retry tapped")
        }
    ) {
        EmptyView()
    }
}

#Preview("Received Message") {
    MessageBubbleView(
        message: Message(
            id: "4",
            messageId: "4",
            senderId: "user2",
            text: "I'm doing great, thanks for asking! How about you?",
            timestamp: Date(),
            status: "sent"
        ),
        isSentByCurrentUser: false
    ) {
        EmptyView()
    }
}

#Preview("Long Message") {
    MessageBubbleView(
        message: Message(
            id: "5",
            messageId: "5",
            senderId: "user1",
            text: "This is a much longer message that should wrap to multiple lines to test how the bubble handles multiline text content properly.",
            timestamp: Date(),
            status: "sent"
        ),
        isSentByCurrentUser: true
    ) {
        EmptyView()
    }
}

#Preview("Message with AI Prompt") {
    MessageBubbleView(
        message: Message(
            id: "6",
            messageId: "6",
            senderId: "user1",
            text: "Let's grab coffee tomorrow at 3pm",
            timestamp: Date(),
            status: "sent"
        ),
        isSentByCurrentUser: true
    ) {
        AIPromptButtonCompact(
            icon: "calendar.badge.plus",
            text: "Add to calendar",
            tintColor: .blue
        ) {
            print("Add to calendar tapped")
        }
    }
}

