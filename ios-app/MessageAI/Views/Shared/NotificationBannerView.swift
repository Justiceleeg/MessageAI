//
//  NotificationBannerView.swift
//  MessageAI
//
//  Story 3.4: Implement Notification System (Mock Push for Demo)
//  In-app banner component for foreground notifications
//

import SwiftUI

/// In-app notification banner that appears at the top of the screen
struct NotificationBannerView: View {
    let title: String
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe up to dismiss
                    if value.translation.height < -50 {
                        onDismiss()
                    }
                }
        )
        .accessibilityLabel("New message notification")
        .accessibilityHint("Tap to open conversation, or swipe up to dismiss")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            NotificationBannerView(
                title: "John Doe",
                message: "Hey! How are you doing today?",
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            
            Spacer()
        }
    }
}

#Preview("Group Chat") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            NotificationBannerView(
                title: "Jane Smith in Team Project",
                message: "The deadline has been moved to next Friday!",
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            
            Spacer()
        }
    }
}

#Preview("Long Message") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        VStack {
            NotificationBannerView(
                title: "Alex Johnson",
                message: "This is a really long message that should be truncated because it's too long to fit on one line and we want to keep the banner compact",
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            
            Spacer()
        }
    }
}

