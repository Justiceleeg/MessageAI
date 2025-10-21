//
//  ChatView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import SwiftUI

/// Chat view for displaying and sending messages in a conversation
struct ChatView: View {
    
    // MARK: - Properties
    
    /// The conversation ID for this chat
    let conversationId: String
    
    /// The display name of the other participant
    let otherParticipantName: String
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Chat View")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Conversation with \(otherParticipantName)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("ID: \(conversationId)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding()
            
            Spacer()
            
            Text("Chat functionality will be implemented in Story 2.2")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Placeholder for future actions (e.g., call, video call, info)
                }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Conversation info")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(
            conversationId: "conv_preview_123",
            otherParticipantName: "John Doe"
        )
    }
}

