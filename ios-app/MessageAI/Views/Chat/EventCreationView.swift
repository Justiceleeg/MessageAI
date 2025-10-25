//
//  EventCreationView.swift
//  MessageAI
//
//  Modal for creating calendar events from AI-detected information
//  Story 5.1 - Smart Calendar Extraction
//

import SwiftUI

/// Modal view for creating and editing calendar events
struct EventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Pre-filled data from AI
    let initialData: CalendarDetection
    let messageId: String
    let conversationId: String
    
    // Editable fields
    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var location: String
    
    // State
    @State private var isCreating = false
    @State private var showingDuplicateAlert = false
    @State private var similarEvent: SimilarEvent?
    @State private var errorMessage: String?
    
    // Services
    private let eventService = EventService()
    private let aiBackendService = AIBackendService.shared
    private let firestoreService = FirestoreService()
    
    // Callbacks
    let onEventCreated: (Event) -> Void
    
    // MARK: - Initialization
    
    init(
        initialData: CalendarDetection,
        messageId: String,
        conversationId: String,
        onEventCreated: @escaping (Event) -> Void
    ) {
        self.initialData = initialData
        self.messageId = messageId
        self.conversationId = conversationId
        self.onEventCreated = onEventCreated
        
        // Initialize state from AI data
        _title = State(initialValue: initialData.title ?? "")
        _date = State(initialValue: Self.parseDate(initialData.date) ?? Date())
        _hasTime = State(initialValue: initialData.time != nil)
        _time = State(initialValue: Self.parseTime(initialData.time) ?? Date())
        _location = State(initialValue: initialData.location ?? "")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                        .font(.system(size: 18, weight: .semibold))
                } header: {
                    Text("Event Details")
                }
                
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Toggle("Specific Time", isOn: $hasTime)
                    
                    if hasTime {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("When")
                }
                
                Section {
                    TextField("Location (Optional)", text: $location)
                } header: {
                    Text("Where")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createEvent()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .disabled(isCreating)
            .alert("Similar Event Found", isPresented: $showingDuplicateAlert) {
                Button("Link to Existing", role: .destructive) {
                    // TODO: Implement linking in future story
                    dismiss()
                }
                Button("Create New") {
                    Task {
                        await createNewEventAnyway()
                    }
                }
                Button("Cancel", role: .cancel) {
                    isCreating = false
                }
            } message: {
                if let similar = similarEvent {
                    Text("A similar event '\(similar.title ?? "Unknown")' on \(similar.date ?? "unknown date") already exists. Would you like to link to it or create a new event?")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createEvent() async {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Get current user ID
            guard let userId = AuthService.shared.currentUser?.userId else {
                throw NSError(domain: "EventCreation", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Format date and time
            let dateString = formatDateISO(date)
            let timeString = hasTime ? formatTimeHHMM(time) : nil
            
            // Call backend to check for duplicates and create event
            let response = try await aiBackendService.createEvent(
                title: title,
                date: dateString,
                time: timeString,
                location: location.isEmpty ? nil : location,
                userId: userId,
                conversationId: conversationId,
                messageId: messageId
            )
            
            if response.suggestLink, let similar = response.similarEvent {
                // Found similar event - show alert
                similarEvent = similar
                showingDuplicateAlert = true
                return
            }
            
            // Success - create local Event object and save to Firestore
            guard let eventId = response.eventId else {
                throw NSError(domain: "EventCreation", code: 500, userInfo: [NSLocalizedDescriptionKey: "No event ID returned"])
            }
            
            // Get conversation to find all participants
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            
            // Create attendees dictionary with all OTHER participants (not the creator)
            var attendees: [String: Attendee] = [:]
            for participantId in conversation.participants where participantId != userId {
                attendees[participantId] = Attendee(status: .pending)
            }
            
            let newEvent = Event(
                eventId: eventId,
                title: title,
                date: date,
                time: timeString,
                location: location.isEmpty ? nil : location,
                creatorUserId: userId,
                createdAt: Date(),
                createdInConversationId: conversationId,
                createdAtMessageId: messageId,
                invitations: [:],
                attendees: attendees
            )
            
            // Save to Firestore
            _ = try await eventService.createEvent(newEvent)
            
            // Notify parent and dismiss
            await MainActor.run {
                onEventCreated(newEvent)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create event: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
    
    private func createNewEventAnyway() async {
        // Same as createEvent but skip duplicate check
        // For now, just call createEvent again (backend will return same result)
        await createEvent()
    }
    
    // MARK: - Helper Functions
    
    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // Use DateFormatter with local timezone to avoid UTC interpretation
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current  // Use local timezone
        return formatter.date(from: dateString)
    }
    
    private static func parseTime(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
    
    private func formatDateISO(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
    
    private func formatTimeHHMM(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

// MARK: - Preview

#Preview {
    EventCreationView(
        initialData: CalendarDetection(
            detected: true,
            title: "Coffee meeting",
            date: "2025-10-27",
            time: "15:00",
            location: "Starbucks",
            isInvitation: false
        ),
        messageId: "msg_123",
        conversationId: "conv_456"
    ) { event in
        print("Event created: \(event.title)")
    }
}

