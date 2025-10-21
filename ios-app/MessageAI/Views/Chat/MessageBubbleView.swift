//
//  MessageBubbleView.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import SwiftUI

/// Reusable message bubble component for chat interface
struct MessageBubbleView: View {
    
    let message: Message
    let isSentByCurrentUser: Bool
    let status: String  // Computed status from ChatViewModel (Story 3.2)
    let onRetry: (() -> Void)?
    let isGroupChat: Bool
    let senderName: String?
    
    // MARK: - Initialization
    
    init(message: Message, isSentByCurrentUser: Bool, status: String = "", onRetry: (() -> Void)? = nil, isGroupChat: Bool = false, senderName: String? = nil) {
        self.message = message
        self.isSentByCurrentUser = isSentByCurrentUser
        self.status = status.isEmpty ? message.status : status
        self.onRetry = onRetry
        self.isGroupChat = isGroupChat
        self.senderName = senderName
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: isSentByCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (only for received messages in group chats)
            if !isSentByCurrentUser && isGroupChat, let senderName = senderName {
                Text(senderName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
            }
            
            // Message bubble
            HStack {
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
                
                if !isSentByCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            
            // Timestamp and status indicator
            HStack(spacing: 4) {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onTapGesture {
            // Only tappable if failed and onRetry is provided
            if message.status == "failed", let onRetry = onRetry {
                onRetry()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Format timestamp as "10:30 AM"
    private var formattedTimestamp: String {
        DateFormatters.messageTime.string(from: message.timestamp)
    }
    
    /// Status indicator view based on message status (Story 3.2 - Read Receipts)
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
            // Double gray checkmark for delivered state
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.gray)
            .accessibilityLabel("Message delivered")
            
        case "read":
            // Double blue checkmark for read state
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.blue)
            .accessibilityLabel("Message read")
            
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
        
        // Add status to accessibility label (Story 3.2)
        switch status {
        case "sending":
            label += ", sending"
        case "sent":
            label += ", sent"
        case "delivered":
            label += ", delivered"
        case "read":
            label += ", read"
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
    )
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
    )
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
    )
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
    )
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
    )
}

