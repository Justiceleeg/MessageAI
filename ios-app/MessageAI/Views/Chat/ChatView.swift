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
    
    /// The other user's ID
    let otherUserId: String
    
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(conversationId: String?, otherUserId: String) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        
        // Initialize ViewModel with parameters (uses convenience initializer)
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            otherUserId: otherUserId
        ))
    }
    
    // Initializer for testing with custom services
    init(conversationId: String?, otherUserId: String, viewModel: ChatViewModel) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
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
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
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
                                    isSentByCurrentUser: viewModel.isSentByCurrentUser(message: message)
                                )
                                .id(message.id)
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

