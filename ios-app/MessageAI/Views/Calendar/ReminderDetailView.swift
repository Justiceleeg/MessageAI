//
//  ReminderDetailView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/24/25.
//

import SwiftUI

/// Detailed view for a single reminder
struct ReminderDetailView: View {
    
    // MARK: - Properties
    
    let reminder: Reminder
    var onDelete: () -> Void
    var onMarkComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var conversationName: String = "Loading..."
    @State private var currentUserId: String?
    
    private let firestoreService = FirestoreService()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Reminder Title
                    reminderTitleSection
                    
                    // Due Date & Time
                    dueDateSection
                    
                    // Completion Status
                    completionStatusSection
                    
                    // Conversation
                    conversationSection
                    
                    // Created Date
                    createdDateSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Reminder", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this reminder? This action cannot be undone.")
            }
            .task {
                await loadConversationData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var reminderTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reminder", systemImage: "bell.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(reminder.title)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Due Date", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(formattedDueDate)
                    .font(.body)
                
                if isOverdue && !reminder.completed {
                    Badge(text: "Overdue", color: .red)
                }
            }
        }
    }
    
    private var completionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Status", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                if reminder.completed {
                    Badge(text: "Completed", color: .green)
                } else {
                    Badge(text: "Pending", color: .orange)
                }
            }
        }
    }
    
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(conversationName)
                .font(.body)
        }
    }
    
    private var createdDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Created", systemImage: "calendar.badge.plus")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(formattedCreatedDate)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Jump to Message button
            Button {
                // TODO: Implement navigation to message
                // This requires navigation coordination
            } label: {
                Label("Jump to Message", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            // Mark Complete/Incomplete button
            if !reminder.completed {
                Button {
                    onMarkComplete()
                    dismiss()
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            // Delete button
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Reminder", systemImage: "trash")
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
    
    private func loadConversationData() async {
        // Get current user ID from shared AuthService
        currentUserId = AuthService.shared.currentUser?.userId
        
        if let conversation = try? await firestoreService.getConversation(conversationId: reminder.conversationId) {
            await loadConversationName(conversation)
        } else {
            conversationName = "Unknown Conversation"
        }
    }
    
    private func loadConversationName(_ conversation: Conversation) async {
        // For group chats, use the group name
        if conversation.isGroupChat {
            conversationName = conversation.groupName ?? "Group Chat"
            return
        }
        
        // For 1:1 chats, get the other participant's name
        guard let currentUserId = currentUserId else {
            conversationName = "Unknown"
            return
        }
        
        let otherUserId = conversation.participants.first { $0 != currentUserId } ?? ""
        
        // Load the other user's name
        if let user = try? await firestoreService.getUserProfile(userId: otherUserId) {
            conversationName = user.displayName
        } else {
            conversationName = "Unknown User"
        }
    }
    
    // MARK: - Helpers
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: reminder.dueDate)
    }
    
    private var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reminder.createdAt)
    }
    
    private var isOverdue: Bool {
        reminder.dueDate < Date()
    }
}

// MARK: - Badge View

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ReminderDetailView(
        reminder: Reminder(
            userId: "user123",
            title: "Submit quarterly report",
            dueDate: Date().addingTimeInterval(86400),
            conversationId: "conv456",
            sourceMessageId: "msg789"
        ),
        onDelete: {},
        onMarkComplete: {}
    )
}
