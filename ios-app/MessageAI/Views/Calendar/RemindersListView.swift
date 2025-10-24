//
//  RemindersListView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/24/25.
//

import SwiftUI

/// List view showing reminders grouped by time
struct RemindersListView: View {
    
    // MARK: - Properties
    
    let reminders: [Reminder]
    var onReminderTap: (Reminder) -> Void
    var onMarkComplete: (Reminder) -> Void
    var onDelete: (Reminder) -> Void
    
    @State private var showCompletedSection = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            if activeReminders.isEmpty && completedReminders.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    // Active reminders by time group
                    ForEach(timeGroups, id: \.self) { group in
                        if let groupReminders = groupedReminders[group], !groupReminders.isEmpty {
                            Section {
                                ForEach(groupReminders) { reminder in
                                    ReminderRowView(
                                        reminder: reminder,
                                        onTap: { onReminderTap(reminder) },
                                        onMarkComplete: { onMarkComplete(reminder) },
                                        onDelete: { onDelete(reminder) }
                                    )
                                }
                            } header: {
                                SectionHeaderView(
                                    title: group,
                                    isOverdue: group == "Overdue"
                                )
                            }
                        }
                    }
                    
                    // Completed reminders section
                    if !completedReminders.isEmpty {
                        Section {
                            if showCompletedSection {
                                ForEach(completedReminders) { reminder in
                                    ReminderRowView(
                                        reminder: reminder,
                                        onTap: { onReminderTap(reminder) },
                                        onMarkComplete: { onMarkComplete(reminder) },
                                        onDelete: { onDelete(reminder) }
                                    )
                                }
                            }
                        } header: {
                            Button {
                                withAnimation {
                                    showCompletedSection.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Completed (\(completedReminders.count))")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: showCompletedSection ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No reminders set")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Create reminders in your conversations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var activeReminders: [Reminder] {
        reminders.filter { !$0.completed }
    }
    
    private var completedReminders: [Reminder] {
        reminders.filter { $0.completed }
            .sorted { $0.dueDate > $1.dueDate }
    }
    
    private let timeGroups = ["Overdue", "Today", "Tomorrow", "This Week", "Later"]
    
    private var groupedReminders: [String: [Reminder]] {
        let now = Date()
        let calendar = Calendar.current
        var groups: [String: [Reminder]] = [:]
        
        for reminder in activeReminders {
            let group: String
            
            if reminder.dueDate < now {
                group = "Overdue"
            } else if calendar.isDateInToday(reminder.dueDate) {
                group = "Today"
            } else if calendar.isDateInTomorrow(reminder.dueDate) {
                group = "Tomorrow"
            } else if calendar.isDate(reminder.dueDate, equalTo: now, toGranularity: .weekOfYear) {
                group = "This Week"
            } else {
                group = "Later"
            }
            
            groups[group, default: []].append(reminder)
        }
        
        // Sort each group by due date
        for key in groups.keys {
            groups[key] = groups[key]?.sorted { $0.dueDate < $1.dueDate }
        }
        
        return groups
    }
}

// MARK: - Section Header View

struct SectionHeaderView: View {
    let title: String
    let isOverdue: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(isOverdue ? .red : .primary)
            if isOverdue {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Reminder Row View

struct ReminderRowView: View {
    let reminder: Reminder
    var onTap: () -> Void
    var onMarkComplete: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion checkbox
            Button {
                onMarkComplete()
            } label: {
                Image(systemName: reminder.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(reminder.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Reminder content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                    .strikethrough(reminder.completed)
                    .foregroundColor(reminder.completed ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    // Due date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formattedDueDate)
                            .font(.caption)
                    }
                    .foregroundColor(isOverdue ? .red : .secondary)
                    
                    // Conversation indicator
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.caption2)
                        Text("Chat")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onMarkComplete()
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(reminder.dueDate) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: reminder.dueDate))"
        } else if calendar.isDateInTomorrow(reminder.dueDate) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: reminder.dueDate))"
        } else if calendar.isDate(reminder.dueDate, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: reminder.dueDate)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: reminder.dueDate)
        }
    }
    
    private var isOverdue: Bool {
        !reminder.completed && reminder.dueDate < Date()
    }
}

// MARK: - Preview

#Preview {
    RemindersListView(
        reminders: [
            Reminder(
                userId: "user1",
                title: "Submit report",
                dueDate: Date().addingTimeInterval(-3600),
                conversationId: "conv1",
                sourceMessageId: "msg1"
            ),
            Reminder(
                userId: "user1",
                title: "Call dentist",
                dueDate: Date().addingTimeInterval(3600),
                conversationId: "conv1",
                sourceMessageId: "msg2"
            ),
            Reminder(
                userId: "user1",
                title: "Completed task",
                dueDate: Date(),
                conversationId: "conv1",
                sourceMessageId: "msg3",
                completed: true
            )
        ],
        onReminderTap: { _ in },
        onMarkComplete: { _ in },
        onDelete: { _ in }
    )
}

