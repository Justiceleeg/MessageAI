//
//  EventInvitationModal.swift
//  MessageAI
//
//  Modal for creating events with invitations and RSVP tracking
//  Story 5.4 - RSVP Tracking
//

import SwiftUI
import FirebaseFirestore

/// Modal view for creating events with invitations
struct EventInvitationModal: View {
    @Environment(\.dismiss) private var dismiss
    
    // Pre-filled data from AI analysis
    let analysis: MessageAnalysisResponse
    let messageId: String
    let conversationId: String
    
    // Editable fields
    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var location: String
    
    // Invitation settings
    @State private var inviteAllParticipants: Bool = true
    @State private var selectedParticipants: Set<String> = []
    
    // State
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showLinkingSuggestion = false
    @State private var suggestedEvent: SimilarEvent?
    
    // Services
    private let eventService = EventService()
    private let aiBackendService = AIBackendService.shared
    private let firestoreService = FirestoreService()
    
    // Callbacks
    let onEventCreated: (Event) -> Void
    
    // MARK: - Initialization
    
    init(
        analysis: MessageAnalysisResponse,
        messageId: String,
        conversationId: String,
        onEventCreated: @escaping (Event) -> Void
    ) {
        self.analysis = analysis
        self.messageId = messageId
        self.conversationId = conversationId
        self.onEventCreated = onEventCreated
        
        // Initialize state from AI data
        _title = State(initialValue: analysis.invitation.eventTitle ?? "")
        
        // Parse date and time from AI analysis
        let now = Date()
        var parsedDate = now
        var hasTime = false
        var parsedTime = now
        
        // Parse date from calendar detection (backend already processed with dateparser)
        if let dateString = analysis.calendar.date {
            // Backend provides ISO date string, just parse it directly
            if let parsed = ISO8601DateFormatter().date(from: dateString) {
                parsedDate = parsed
            }
        }
        
        // Parse time from calendar detection (backend provides HH:MM format)
        if let timeString = analysis.calendar.time {
            hasTime = true
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let parsed = formatter.date(from: timeString) {
                parsedTime = parsed
            }
        }
        
        _date = State(initialValue: parsedDate)
        _hasTime = State(initialValue: hasTime)
        _time = State(initialValue: parsedTime)
        _location = State(initialValue: analysis.calendar.location ?? "")
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
                
                Section {
                    Toggle("Invite all chat participants", isOn: $inviteAllParticipants)
                        .onChange(of: inviteAllParticipants) { _, newValue in
                            if newValue {
                                // Select all participants when toggling on
                                Task {
                                    let participants = await getConversationParticipants()
                                    selectedParticipants = Set(participants)
                                }
                            } else {
                                // Clear selection when toggling off
                                selectedParticipants.removeAll()
                            }
                        }
                    
                    if !inviteAllParticipants {
                        ParticipantSelectionView(
                            selectedParticipants: $selectedParticipants,
                            conversationId: conversationId
                        )
                    }
                } header: {
                    Text("Invitations")
                } footer: {
                    Text("All chat participants will be invited to this event and can RSVP.")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Event & Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & Invite") {
                        Task {
                            await createEventWithInvitations()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .disabled(isCreating)
            .alert("Link to Existing Event?", isPresented: $showLinkingSuggestion) {
                Button("Create New Event") {
                    // Continue with new event creation
                    Task {
                        await createEventWithInvitations()
                    }
                }
                Button("Link to Existing") {
                    // Link to existing event
                    Task {
                        await linkToExistingEvent()
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                if let suggestedEvent = suggestedEvent {
                    Text("Found similar event: '\(suggestedEvent.title ?? "")' on \(suggestedEvent.date ?? ""). Would you like to link to this existing event instead of creating a new one?")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createEventWithInvitations() async {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Get current user ID
            guard let userId = AuthService.shared.currentUser?.userId else {
                throw NSError(domain: "EventInvitation", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Format date and time
            let dateString = formatDateISO(date)
            let timeString = hasTime ? formatTimeHHMM(time) : nil
            
            // Call backend to create event
            let response = try await aiBackendService.createEvent(
                title: title,
                date: dateString,
                time: timeString,
                location: location.isEmpty ? nil : location,
                userId: userId,
                conversationId: conversationId,
                messageId: messageId
            )
            
            // Check if backend suggests linking to existing event
            if response.suggestLink, let similarEvent = response.similarEvent {
                // Show linking suggestion
                await MainActor.run {
                    showLinkingSuggestion = true
                    suggestedEvent = similarEvent
                    isCreating = false
                }
                return
            }
            
            guard let eventId = response.eventId else {
                throw NSError(domain: "EventInvitation", code: 500, userInfo: [NSLocalizedDescriptionKey: "No event ID returned"])
            }
            
            // Get conversation to find all participants
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            
            // Determine who to invite
            let participantsToInvite: [String]
            if inviteAllParticipants {
                participantsToInvite = conversation.participants.filter { $0 != userId }
            } else {
                participantsToInvite = Array(selectedParticipants).filter { $0 != userId }
            }
            
            // Create attendees dictionary with invited participants
            var attendees: [String: Attendee] = [:]
            for participantId in participantsToInvite {
                attendees[participantId] = Attendee(status: .pending)
            }
            
            // Create invitations map
            var invitations: [String: Invitation] = [:]
            invitations[conversationId] = Invitation(
                messageId: messageId,
                invitedUserIds: participantsToInvite,
                timestamp: Date()
            )
            
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
                invitations: invitations,
                attendees: attendees
            )
            
            // Save to Firestore
            _ = try await eventService.createEvent(newEvent)
            
            // Update the original message with invitation metadata
            try await updateMessageWithInvitationMetadata(eventId: eventId, messageId: messageId, conversationId: conversationId)
            
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
    
    private func getConversationParticipants() async -> [String] {
        do {
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            return conversation.participants
        } catch {
            print("Failed to get conversation participants: \(error)")
            return []
        }
    }
    
    private func updateMessageWithInvitationMetadata(eventId: String, messageId: String, conversationId: String) async throws {
        // Update the existing message in Firestore with invitation metadata
        let db = Firestore.firestore()
        let messageRef = db.collection("conversations").document(conversationId).collection("messages").document(messageId)
        
        let metadata = MessageMetadata(isInvitation: true, eventId: eventId)
        let metadataData = try Firestore.Encoder().encode(metadata)
        
        print("🔧 DEBUG: Updating message \(messageId) with metadata: isInvitation=\(metadata.isInvitation ?? false), eventId=\(metadata.eventId ?? "nil")")
        
        try await messageRef.updateData([
            "metadata": metadataData
        ])
        
        print("✅ Message updated with invitation metadata: \(messageId)")
    }
    
    private func linkToExistingEvent() async {
        guard let suggestedEvent = suggestedEvent,
              let eventId = suggestedEvent.eventId else {
            errorMessage = "Invalid event data"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Get current user ID
            guard let userId = AuthService.shared.currentUser?.userId else {
                throw NSError(domain: "EventInvitation", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Get conversation to find all participants
            let conversation = try await firestoreService.getConversation(conversationId: conversationId)
            
            // Determine who to invite
            let participantsToInvite: [String]
            if inviteAllParticipants {
                participantsToInvite = conversation.participants.filter { $0 != userId }
            } else {
                participantsToInvite = Array(selectedParticipants)
            }
            
            // Create invitation for this conversation
            let invitation = Invitation(
                messageId: messageId,
                invitedUserIds: participantsToInvite,
                timestamp: Date()
            )
            
            // Link to existing event by adding invitation and attendees
            try await eventService.linkEventToChat(
                eventId: eventId,
                conversationId: conversationId,
                invitation: invitation,
                attendees: participantsToInvite
            )
            
            // Update the original message with invitation metadata
            try await updateMessageWithInvitationMetadata(eventId: eventId, messageId: messageId, conversationId: conversationId)
            
            // Notify parent and dismiss
            await MainActor.run {
                onEventCreated(Event(
                    eventId: eventId,
                    title: title,
                    date: date,
                    time: hasTime ? formatTimeHHMM(time) : nil,
                    location: location.isEmpty ? nil : location,
                    creatorUserId: userId,
                    createdAt: Date(),
                    createdInConversationId: conversationId,
                    createdAtMessageId: messageId,
                    invitations: [conversationId: invitation],
                    attendees: [:]
                ))
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to link event: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
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

// MARK: - Participant Selection View

struct ParticipantSelectionView: View {
    @Binding var selectedParticipants: Set<String>
    let conversationId: String
    
    @State private var participants: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading participants...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .task {
                await loadParticipants()
            }
        } else {
            ForEach(participants, id: \.userId) { participant in
                HStack {
                    Text(participant.displayName)
                    Spacer()
                    if selectedParticipants.contains(participant.userId) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedParticipants.contains(participant.userId) {
                        selectedParticipants.remove(participant.userId)
                    } else {
                        selectedParticipants.insert(participant.userId)
                    }
                }
            }
        }
    }
    
    private func loadParticipants() async {
        do {
            let conversation = try await FirestoreService().getConversation(conversationId: conversationId)
            let firestoreService = FirestoreService()
            var loadedParticipants: [User] = []
            
            for participantId in conversation.participants {
                if let user = try? await firestoreService.fetchUser(userId: participantId) {
                    loadedParticipants.append(user)
                }
            }
            
            await MainActor.run {
                self.participants = loadedParticipants
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Parse date and time from AI analysis
    /// - Parameter analysis: The AI analysis response
    /// - Returns: Tuple of (date, hasTime, time)
    static func parseDateTime(from analysis: MessageAnalysisResponse) -> (Date, Bool, Date) {
        let now = Date()
        
        // Default values
        var parsedDate = now
        var hasTime = false
        var parsedTime = now
        
        // Parse date from calendar detection
        if let dateString = analysis.calendar.date {
            if let parsed = parseDateString(dateString) {
                parsedDate = parsed
            }
        }
        
        // Parse time from calendar detection
        if let timeString = analysis.calendar.time {
            hasTime = true
            if let parsed = parseTimeString(timeString) {
                parsedTime = parsed
            }
        }
        
        return (parsedDate, hasTime, parsedTime)
    }
    
    /// Parse ISO 8601 date string
    private static func parseDateString(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    /// Parse time string like "8pm", "19:00", "2pm"
    private static func parseTimeString(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Try HH:mm format first
        if let date = formatter.date(from: timeString) {
            return date
        }
        
        // Try 12-hour format
        formatter.dateFormat = "h:mm a"
        if let date = formatter.date(from: timeString) {
            return date
        }
        
        // Try without minutes
        formatter.dateFormat = "h a"
        if let date = formatter.date(from: timeString) {
            return date
        }
        
        return nil
    }
    
    private func formatDateISO(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}


// MARK: - Preview

#Preview {
    EventInvitationModal(
        analysis: MessageAnalysisResponse(
            messageId: "msg_123",
            calendar: CalendarDetection(
                detected: true,
                title: "Party at my place",
                date: "2024-01-19",
                time: "20:00",
                location: "My place"
            ),
            reminder: ReminderDetection(detected: false, title: nil, dueDate: nil),
            decision: DecisionDetection(detected: false, text: nil),
            rsvp: RSVPDetection(detected: false, status: nil, eventReference: nil),
            invitation: InvitationDetection(
                detected: true,
                type: "create",
                eventTitle: "Party at my place",
                invitationDetected: true
            ),
            priority: PriorityDetection(detected: false, level: nil, reason: nil),
            conflict: ConflictDetection(detected: false, conflictingEvents: [])
        ),
        messageId: "msg_123",
        conversationId: "conv_456"
    ) { event in
        print("Event created: \(event.title)")
    }
}
