//
//  EventDetailView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/24/25.
//

import SwiftUI

/// Detailed view for a single event
struct EventDetailView: View {
    
    // MARK: - Properties
    
    let event: Event
    var onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var shouldNavigateToMessage = false
    
    // Data fetching
    @State private var creatorName: String = "Loading..."
    @State private var conversationName: String = "Loading..."
    @State private var attendeeNames: [String: String] = [:] // userId -> displayName
    @State private var currentUserId: String?
    
    private let firestoreService = FirestoreService()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event Title
                    eventTitleSection
                    
                    // Date & Time
                    dateTimeSection
                    
                    // Location
                    if let location = event.location {
                        locationSection(location)
                    }
                    
                    // Creator
                    creatorSection
                    
                    // Attendees
                    attendeesSection
                    
                    // Linked to Chats (Story 5.4) - only show for multi-chat events
                    if event.invitations.count > 1 {
                        linkedChatsSection
                    }
                    
                    // Conversation
                    conversationSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Event", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this event? This action cannot be undone.")
            }
            .task {
                await loadUserData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var eventTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Event", systemImage: "calendar")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date & Time", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.body)
                
                if let startTime = event.startTime {
                    HStack(spacing: 4) {
                        Text(formatTime(startTime))
                        if let endTime = event.endTime {
                            Text("–")
                            Text(formatTime(endTime))
                        }
                        
                        // Show duration
                        if let duration = event.duration {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.body)
                }
            }
        }
    }
    
    private func locationSection(_ location: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "location.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(location)
                .font(.body)
        }
    }
    
    private var creatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Created By", systemImage: "person.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(creatorName)
                .font(.body)
        }
    }
    
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Attendees (\(event.attendees.count))", systemImage: "person.2.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if event.attendees.isEmpty {
                Text("No attendees yet")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(event.attendees.keys), id: \.self) { userId in
                    if let attendee = event.attendees[userId] {
                        AttendeeRowView(
                            userId: userId,
                            displayName: attendeeNames[userId] ?? "Loading...",
                            attendee: attendee
                        )
                    }
                }
            }
        }
    }
    
    private var linkedChatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Linked to Chats", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(Array(event.invitations.keys), id: \.self) { conversationId in
                if let invitation = event.invitations[conversationId] {
                    LinkedChatRowView(
                        conversationId: conversationId,
                        invitation: invitation,
                        attendeeNames: attendeeNames
                    )
                }
            }
        }
    }
    
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(conversationName)
                .font(.body)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Jump to Message button - only show for single-chat events
            if event.invitations.count <= 1 {
                Button {
                    navigateToMessage()
                } label: {
                    Label("Jump to Message", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            // Delete button
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Event", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Data Loading
    
    private func loadUserData() async {
        // Get current user ID from shared AuthService
        currentUserId = AuthService.shared.currentUser?.userId
        print("📅 EventDetailView: Loading data, currentUserId = \(currentUserId ?? "nil")")
        
        // Load creator name
        if let creator = try? await firestoreService.getUserProfile(userId: event.creatorUserId) {
            creatorName = creator.displayName
            print("📅 EventDetailView: Loaded creator name: \(creatorName)")
        } else {
            creatorName = "Unknown User"
            print("📅 EventDetailView: Failed to load creator")
        }
        
        // Load attendee names
        for userId in event.attendees.keys {
            if let user = try? await firestoreService.getUserProfile(userId: userId) {
                attendeeNames[userId] = user.displayName
                print("📅 EventDetailView: Loaded attendee: \(user.displayName)")
            } else {
                attendeeNames[userId] = "Unknown User"
                print("📅 EventDetailView: Failed to load attendee: \(userId)")
            }
        }
        
        // Load conversation name
        print("📅 EventDetailView: Attempting to load conversation: \(event.createdInConversationId)")
        if let conversation = try? await firestoreService.getConversation(conversationId: event.createdInConversationId) {
            print("📅 EventDetailView: Conversation loaded, isGroupChat: \(conversation.isGroupChat), participants: \(conversation.participants)")
            await loadConversationName(conversation)
        } else {
            conversationName = "Unknown Conversation"
            print("📅 EventDetailView: Failed to load conversation")
        }
    }
    
    private func loadConversationName(_ conversation: Conversation) async {
        print("📅 EventDetailView: loadConversationName called")
        
        // For group chats, use the group name
        if conversation.isGroupChat {
            conversationName = conversation.groupName ?? "Group Chat"
            print("📅 EventDetailView: Set conversation name (group): \(conversationName)")
            return
        }
        
        // For 1:1 chats, get the other participant's name
        guard let currentUserId = currentUserId else {
            conversationName = "Unknown"
            print("📅 EventDetailView: No current user ID")
            return
        }
        
        let otherUserId = conversation.participants.first { $0 != currentUserId } ?? ""
        print("📅 EventDetailView: Other user ID: \(otherUserId)")
        
        // Try to find the other user's name from loaded attendees
        if let otherUserName = attendeeNames[otherUserId] {
            conversationName = otherUserName
            print("📅 EventDetailView: Found name in attendees: \(conversationName)")
            return
        }
        
        // Load the other user's name
        if let user = try? await firestoreService.getUserProfile(userId: otherUserId) {
            conversationName = user.displayName
            print("📅 EventDetailView: Loaded other user name: \(conversationName)")
        } else {
            conversationName = "Unknown User"
            print("📅 EventDetailView: Failed to load other user")
        }
    }
    
    // MARK: - Helpers
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: event.date)
    }
    
    private func formatTime(_ timeString: String) -> String {
        // Input: "HH:mm" (24-hour), Output: "h:mm a" (12-hour)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: timeString) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        
        return timeString
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "(\(minutes) min)"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "(\(hours) hr)"
            } else {
                return "(\(hours) hr \(remainingMinutes) min)"
            }
        }
    }
    
    // MARK: - Navigation (Story 5.1.6)
    
    private func navigateToMessage() {
        // Dismiss this sheet first so the conversation can be seen
        dismiss()
        
        // Post notification to navigate to conversation with message highlighting
        // Use a small delay to ensure the sheet is dismissed first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .navigateToConversationWithMessage,
                object: nil,
                userInfo: [
                    "conversationId": event.createdInConversationId,
                    "messageId": event.createdAtMessageId
                ]
            )
        }
    }
}

// MARK: - Attendee Row View

struct AttendeeRowView: View {
    let userId: String
    let displayName: String
    let attendee: Attendee
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                Text(attendee.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch attendee.status {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return .orange
        }
    }
    
    private var statusBadge: some View {
        Text(attendee.status.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
}

// MARK: - LinkedChatRowView

struct LinkedChatRowView: View {
    let conversationId: String
    let invitation: Invitation
    let attendeeNames: [String: String]
    
    @State private var conversationName: String = "Loading..."
    @State private var shouldNavigateToChat = false
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversationName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("\(invitation.invitedUserIds.count) invited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Jump to Chat") {
                    shouldNavigateToChat = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Show attendee status for this chat
            if !invitation.invitedUserIds.isEmpty {
                HStack(spacing: 8) {
                    ForEach(invitation.invitedUserIds.prefix(3), id: \.self) { userId in
                        if let name = attendeeNames[userId] {
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                    }
                    
                    if invitation.invitedUserIds.count > 3 {
                        Text("+\(invitation.invitedUserIds.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .task {
            await loadConversationName()
        }
        .onTapGesture {
            shouldNavigateToChat = true
        }
        .sheet(isPresented: $shouldNavigateToChat) {
            // Navigate to chat view
            NavigationStack {
                ChatView(conversationId: conversationId, otherUserId: "")
            }
        }
    }
    
    private func loadConversationName() async {
        do {
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            if conversation.isGroupChat {
                conversationName = conversation.groupName ?? "Group Chat"
            } else {
                // For 1:1 chats, get the other participant's name
                let otherUserId = conversation.participants.first { $0 != AuthService.shared.currentUser?.userId }
                if let otherUserId = otherUserId, let name = attendeeNames[otherUserId] {
                    conversationName = name
                } else {
                    conversationName = "Chat"
                }
            }
        } catch {
            conversationName = "Unknown Chat"
        }
    }
}

// MARK: - Preview

#Preview {
    EventDetailView(
        event: Event(
            title: "Team Meeting",
            date: Date(),
            startTime: "10:00",
            endTime: "11:30",
            duration: 90,
            location: "Conference Room",
            creatorUserId: "user123",
            createdInConversationId: "conv456",
            createdAtMessageId: "msg789",
            attendees: [
                "user1": Attendee(status: .accepted),
                "user2": Attendee(status: .pending),
                "user3": Attendee(status: .declined)
            ]
        ),
        onDelete: {}
    )
}
