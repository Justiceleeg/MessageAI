//
//  ReminderCreationModal.swift
//  MessageAI
//
//  Modal for creating reminders from AI detection
//  Story 5.5 - Deadline/Reminder Extraction
//

import SwiftUI
import FirebaseFirestore

/// Modal view for creating reminders from AI detection
struct ReminderCreationModal: View {
    @Environment(\.dismiss) private var dismiss
    
    // Pre-filled data from AI analysis
    let analysis: MessageAnalysisResponse
    let messageId: String
    let conversationId: String
    
    // Editable fields
    @State private var title: String
    @State private var dueDate: Date
    @State private var reminderTiming: ReminderTiming = .atDueTime
    
    // State
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    // Services
    private let reminderService = ReminderService()
    private let aiBackendService = AIBackendService.shared
    
    // Callbacks
    let onReminderCreated: (Reminder) -> Void
    
    // MARK: - Initialization
    
    init(
        analysis: MessageAnalysisResponse,
        messageId: String,
        conversationId: String,
        onReminderCreated: @escaping (Reminder) -> Void
    ) {
        self.analysis = analysis
        self.messageId = messageId
        self.conversationId = conversationId
        self.onReminderCreated = onReminderCreated
        
        // Initialize state from AI data
        _title = State(initialValue: analysis.reminder.title ?? "")
        
        // Parse due date from AI analysis
        let now = Date()
        var parsedDate = now.addingTimeInterval(24 * 60 * 60) // Default to tomorrow
        
        // Parse date from reminder detection (backend already processed with dateparser)
        if let dateString = analysis.reminder.dueDate {
            // Backend provides ISO date string, just parse it directly
            if let parsed = ISO8601DateFormatter().date(from: dateString) {
                parsedDate = parsed
            }
        }
        
        _dueDate = State(initialValue: parsedDate)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Reminder Title", text: $title)
                        .font(.system(size: 18, weight: .semibold))
                } header: {
                    Text("What do you need to remember?")
                } footer: {
                    Text("This will be the title of your reminder notification")
                }
                
                Section {
                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                } header: {
                    Text("When is this due?")
                } footer: {
                    Text("Set the date and time when this task should be completed")
                }
                
                Section {
                    Picker("Reminder Timing", selection: $reminderTiming) {
                        Text("At due time").tag(ReminderTiming.atDueTime)
                        Text("1 hour before").tag(ReminderTiming.oneHourBefore)
                        Text("Morning of").tag(ReminderTiming.morningOf)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("When should you be reminded?")
                } footer: {
                    Text(reminderTimingDescription)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set Reminder") {
                        createReminder()
                    }
                    .disabled(isCreating || title.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var reminderTimingDescription: String {
        switch reminderTiming {
        case .atDueTime:
            return "You'll be reminded exactly when the task is due"
        case .oneHourBefore:
            return "You'll be reminded 1 hour before the due time"
        case .morningOf:
            return "You'll be reminded at 9:00 AM on the due date"
        }
    }
    
    // MARK: - Actions
    
    private func createReminder() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Create reminder object
                let reminder = Reminder(
                    reminderId: UUID().uuidString,
                    userId: AuthService.shared.currentUser?.userId ?? "",
                    title: title,
                    dueDate: dueDate,
                    conversationId: conversationId,
                    sourceMessageId: messageId,
                    completed: false,
                    createdAt: Date(),
                    notificationId: nil
                )
                
                // Store in Firestore and vector storage
                try await reminderService.createReminderWithVectorStorage(reminder)
                
                // Schedule notification
                try await reminderService.scheduleReminder(reminder, timing: reminderTiming)
                
                await MainActor.run {
                    onReminderCreated(reminder)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create reminder: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Reminder Timing Enum

enum ReminderTiming: String, CaseIterable {
    case atDueTime = "at_due_time"
    case oneHourBefore = "one_hour_before"
    case morningOf = "morning_of"
    
    var displayName: String {
        switch self {
        case .atDueTime:
            return "At due time"
        case .oneHourBefore:
            return "1 hour before"
        case .morningOf:
            return "Morning of"
        }
    }
}

// MARK: - Previews

#Preview("Reminder Creation Modal") {
    ReminderCreationModal(
        analysis: MessageAnalysisResponse(
            messageId: "msg_123",
            calendar: CalendarDetection(
                detected: false,
                title: nil,
                date: nil,
                time: nil,
                location: nil,
                isInvitation: false
            ),
            reminder: ReminderDetection(
                detected: true,
                title: "Send project report",
                dueDate: "2025-10-25T17:00:00Z"
            ),
            decision: DecisionDetection(
                detected: false,
                text: nil
            ),
            rsvp: RSVPDetection(
                detected: false,
                status: nil,
                eventReference: nil
            ),
            priority: PriorityDetection(
                detected: false,
                level: nil,
                reason: nil
            ),
            conflict: ConflictDetection(
                detected: false,
                conflictingEvents: []
            )
        ),
        messageId: "msg_123",
        conversationId: "conv_456"
    ) { reminder in
        print("Reminder created: \(reminder.title)")
    }
}
