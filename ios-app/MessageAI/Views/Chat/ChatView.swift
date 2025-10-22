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
    
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationManager.self) private var notificationManager
    
    // State for retry action sheet
    @State private var showRetryActionSheet = false
    @State private var selectedMessageForRetry: Message?
    
    // MARK: - Initialization
    
    init(conversationId: String?, otherUserId: String, groupParticipants: [User]? = nil, groupName: String? = nil) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.groupParticipants = groupParticipants
        self.groupName = groupName
        
        // Initialize ViewModel with parameters (uses convenience initializer)
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            otherUserId: otherUserId,
            groupParticipants: groupParticipants,
            groupName: groupName
        ))
    }
    
    // Initializer for testing with custom services
    init(conversationId: String?, otherUserId: String, viewModel: ChatViewModel) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        self.groupParticipants = nil
        self.groupName = nil
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            messageListView
            
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
                                MessageBubbleView(
                                    message: message,
                                    isSentByCurrentUser: viewModel.isSentByCurrentUser(message: message),
                                    status: viewModel.computeMessageStatus(for: message),
                                    onRetry: message.status == "failed" ? {
                                        selectedMessageForRetry = message
                                        showRetryActionSheet = true
                                    } : nil,
                                    isGroupChat: viewModel.conversation?.isGroupChat ?? false,
                                    senderName: !viewModel.isSentByCurrentUser(message: message) ? viewModel.getSenderDisplayName(userId: message.senderId) : nil,
                                    isOnline: viewModel.participantPresence[message.senderId]  // Story 3.3: Show online status in group chats
                                )
                                .id(message.id)
                                .onAppear {
                                    // Mark message as read when it appears (Story 3.2)
                                    viewModel.markMessageAsReadIfVisible(messageId: message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
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
                        // Scroll to bottom on initial load
                        if let lastMessage = viewModel.messages.last {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
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

