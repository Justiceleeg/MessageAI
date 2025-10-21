//
//  MessageInputBar.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-21.
//

import SwiftUI

/// Reusable message input bar component for chat interface
struct MessageInputBar: View {
    
    @Binding var messageText: String
    @FocusState private var isTextFieldFocused: Bool
    
    let isSending: Bool
    let onSend: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Message text field
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .systemGray6))
                )
                .font(.system(size: 16))
                .lineLimit(1...5)  // Multiline support, up to 5 lines
                .focused($isTextFieldFocused)
                .disabled(isSending)
                .accessibilityLabel("Message input field")
                .accessibilityHint("Type your message here")
            
            // Send button
            Button(action: {
                onSend()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isSendButtonEnabled ? .blue : .secondary)
            }
            .disabled(!isSendButtonEnabled || isSending)
            .accessibilityLabel("Send message")
            .accessibilityHint("Double tap to send your message")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(uiColor: .separator)),
            alignment: .top
        )
        .onAppear {
            // Auto-focus text field when view appears
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Computed Properties
    
    /// Enable send button only when text is not empty/whitespace
    private var isSendButtonEnabled: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#Preview("Empty Input") {
    MessageInputBar(
        messageText: .constant(""),
        isSending: false,
        onSend: { print("Send tapped") }
    )
}

#Preview("With Text") {
    MessageInputBar(
        messageText: .constant("Hello there!"),
        isSending: false,
        onSend: { print("Send tapped") }
    )
}

#Preview("Sending State") {
    MessageInputBar(
        messageText: .constant("Sending..."),
        isSending: true,
        onSend: { print("Send tapped") }
    )
}

#Preview("Long Text") {
    MessageInputBar(
        messageText: .constant("This is a much longer message that should wrap to multiple lines to test the multiline input behavior."),
        isSending: false,
        onSend: { print("Send tapped") }
    )
}

