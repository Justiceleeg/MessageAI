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
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: isSentByCurrentUser ? .trailing : .leading, spacing: 4) {
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
                            .fill(isSentByCurrentUser ? Color.blue : Color(uiColor: .systemGray5))
                    )
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !isSentByCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            
            // Timestamp below bubble
            Text(formattedTimestamp)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Computed Properties
    
    /// Format timestamp as "10:30 AM"
    private var formattedTimestamp: String {
        DateFormatters.messageTime.string(from: message.timestamp)
    }
    
    /// VoiceOver accessibility label
    private var accessibilityLabel: String {
        let sender = isSentByCurrentUser ? "You" : "Other user"
        return "\(sender) sent: \(message.text), at \(formattedTimestamp)"
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

#Preview("Received Message") {
    MessageBubbleView(
        message: Message(
            id: "2",
            messageId: "2",
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
            id: "3",
            messageId: "3",
            senderId: "user1",
            text: "This is a much longer message that should wrap to multiple lines to test how the bubble handles multiline text content properly.",
            timestamp: Date(),
            status: "sent"
        ),
        isSentByCurrentUser: true
    )
}

