//
//  TypingIndicatorView.swift
//  MessageAI
//
//  Created by Dev Agent on 10/23/25.
//  Displays typing indicators for active conversations
//

import SwiftUI

/// View that displays typing indicators when users are composing messages
struct TypingIndicatorView: View {
    let typingUsers: [User]
    @State private var animationPhase = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if !typingUsers.isEmpty {
            HStack(spacing: 4) {
                Text(typingText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Animated ellipsis dots
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear {
                startAnimation()
            }
            .accessibilityLabel("\(typingText) typing")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
    
    /// Generate the typing text based on number of users
    private var typingText: String {
        switch typingUsers.count {
        case 1:
            return "\(typingUsers[0].displayName) is typing"
        case 2:
            return "\(typingUsers[0].displayName) and \(typingUsers[1].displayName) are typing"
        case 3...Int.max:
            let names = typingUsers.prefix(2).map { $0.displayName }.joined(separator: ", ")
            let others = typingUsers.count - 2
            return "\(names), and \(others) \(others == 1 ? "other" : "others") are typing"
        default:
            return ""
        }
    }
    
    /// Start the ellipsis animation
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Preview
#Preview("Single User") {
    TypingIndicatorView(typingUsers: [
        User(userId: "1", displayName: "Alice", email: "alice@example.com")
    ])
    .padding()
}

#Preview("Two Users") {
    TypingIndicatorView(typingUsers: [
        User(userId: "1", displayName: "Alice", email: "alice@example.com"),
        User(userId: "2", displayName: "Bob", email: "bob@example.com")
    ])
    .padding()
}

#Preview("Multiple Users") {
    TypingIndicatorView(typingUsers: [
        User(userId: "1", displayName: "Alice", email: "alice@example.com"),
        User(userId: "2", displayName: "Bob", email: "bob@example.com"),
        User(userId: "3", displayName: "Charlie", email: "charlie@example.com"),
        User(userId: "4", displayName: "David", email: "david@example.com")
    ])
    .padding()
}

#Preview("Dark Mode") {
    TypingIndicatorView(typingUsers: [
        User(userId: "1", displayName: "Alice", email: "alice@example.com")
    ])
    .padding()
    .preferredColorScheme(.dark)
}

