//
//  ChatRemindersView.swift
//  MessageAI
//
//  Per-chat reminders view for displaying and managing reminders
//  Story 5.5 - Deadline/Reminder Extraction
//

import SwiftUI
import Combine
import FirebaseFirestore

/// View for displaying reminders for a specific conversation or all conversations
struct ChatRemindersView: View {
    
    // MARK: - Properties
    
    let conversationId: String?
    
    @StateObject private var viewModel = ChatRemindersViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading reminders...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                } else if viewModel.reminders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Reminders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Reminders from this conversation will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        if !viewModel.searchQuery.isEmpty {
                            // Search results
                            if viewModel.isSearching {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Searching...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            } else if viewModel.searchResults.isEmpty {
                                Text("No reminders found for \"\(viewModel.searchQuery)\"")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Section("Search Results") {
                                    ForEach(viewModel.searchResults) { result in
                                        SearchResultRowView(result: result) {
                                            // Navigate to source message
                                            // TODO: Implement navigation to source message
                                        }
                                    }
                                }
                            }
                        } else {
                            // Active reminders
                            if !viewModel.activeReminders.isEmpty {
                                Section("Active Reminders") {
                                    ForEach(viewModel.activeReminders) { reminder in
                                        ChatReminderRowView(reminder: reminder) {
                                            Task {
                                                await viewModel.completeReminder(reminder.reminderId)
                                            }
                                        } onDelete: {
                                            Task {
                                                await viewModel.deleteReminder(reminder.reminderId)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Completed reminders
                            if !viewModel.completedReminders.isEmpty {
                                Section("Completed") {
                                    ForEach(viewModel.completedReminders) { reminder in
                                        ChatReminderRowView(reminder: reminder, isCompleted: true) {
                                            Task {
                                                await viewModel.uncompleteReminder(reminder.reminderId)
                                            }
                                        } onDelete: {
                                            Task {
                                                await viewModel.deleteReminder(reminder.reminderId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(conversationId == nil ? "All Reminders" : "Chat Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, prompt: "Search reminders...")
            .onChange(of: viewModel.searchQuery) { _, newValue in
                if !newValue.isEmpty {
                    Task {
                        await viewModel.searchReminders(query: newValue)
                    }
                } else {
                    viewModel.clearSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadReminders(conversationId: conversationId)
        }
    }
}

/// Row view for displaying a single reminder
struct ChatReminderRowView: View {
    let reminder: Reminder
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    init(
        reminder: Reminder,
        isCompleted: Bool = false,
        onToggle: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.reminder = reminder
        self.isCompleted = isCompleted
        self.onToggle = onToggle
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion indicator
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(reminder.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                
                // Due date
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(formattedDueDate)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: { showingDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            
            if !isCompleted {
                Button("Complete") {
                    onToggle()
                }
                .tint(.green)
            }
        }
        .confirmationDialog(
            "Delete Reminder",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This reminder will be permanently deleted.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(reminder.dueDate) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: reminder.dueDate))"
        } else if calendar.isDateInTomorrow(reminder.dueDate) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: reminder.dueDate))"
        } else if calendar.isDate(reminder.dueDate, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: reminder.dueDate)
        } else {
            return formatter.string(from: reminder.dueDate)
        }
    }
}

// MARK: - View Model

@MainActor
class ChatRemindersViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var reminders: [Reminder] = []
    @Published var searchResults: [ReminderSearchResult] = []
    @Published var searchQuery: String = ""
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var activeReminders: [Reminder] {
        reminders.filter { !$0.completed }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    var completedReminders: [Reminder] {
        reminders.filter { $0.completed }
            .sorted { $0.dueDate > $1.dueDate }
    }
    
    // MARK: - Services
    
    private let reminderService = ReminderService()
    private var listener: ListenerRegistration?
    
    // MARK: - Methods
    
    func loadReminders(conversationId: String?) {
        isLoading = true
        errorMessage = nil
        
        // Set up real-time listener
        if let conversationId = conversationId {
            // Load reminders for specific conversation
            listener = reminderService.observeConversationReminders(conversationId: conversationId) { [weak self] reminders in
                Task { @MainActor in
                    self?.reminders = reminders
                    self?.isLoading = false
                }
            }
        } else {
            // Load all reminders across all conversations
            listener = reminderService.observeAllReminders { [weak self] reminders in
                Task { @MainActor in
                    self?.reminders = reminders
                    self?.isLoading = false
                }
            }
        }
    }
    
    func completeReminder(_ reminderId: String) async {
        do {
            try await reminderService.completeReminder(reminderId: reminderId)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to complete reminder: \(error.localizedDescription)"
            }
        }
    }
    
    func uncompleteReminder(_ reminderId: String) async {
        do {
            // Get the reminder and update it
            guard let reminder = try await reminderService.getReminder(id: reminderId) else { return }
            var updatedReminder = reminder
            updatedReminder.completed = false
            try await reminderService.updateReminder(updatedReminder)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to uncomplete reminder: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteReminder(_ reminderId: String) async {
        do {
            try await reminderService.deleteReminder(id: reminderId)
            try await reminderService.deleteReminderVector(reminderId: reminderId)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
            }
        }
    }
    
    func searchReminders(query: String) async {
        guard !query.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let results = try await reminderService.searchReminders(query: query, userId: AuthService.shared.currentUser?.userId ?? "")
            searchResults = results
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }
    
    deinit {
        listener?.remove()
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let result: ReminderSearchResult
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Search result icon
            Image(systemName: "magnifyingglass.circle")
                .font(.title3)
                .foregroundColor(.blue)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    // Due date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formattedDueDate)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    // Similarity score
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(Int(result.similarity * 100))% match")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
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
    }
    
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: result.dueDate) else {
            return result.dueDate
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Previews

#Preview("Chat Reminders View") {
    ChatRemindersView(conversationId: "conv_123")
}

#Preview("Reminder Row") {
    List {
        ChatReminderRowView(
            reminder: Reminder(
                reminderId: "rem_123",
                userId: "user_123",
                title: "Send project report",
                dueDate: Date().addingTimeInterval(3600),
                conversationId: "conv_123",
                sourceMessageId: "msg_123",
                completed: false
            )
        ) {
            print("Toggle reminder")
        } onDelete: {
            print("Delete reminder")
        }
    }
}
