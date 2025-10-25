import SwiftUI

/// Modal for creating events with invitation capabilities
/// Unified event creation flow that handles both calendar events and invitations
struct EventInvitationModal: View {
    let analysis: MessageAnalysisResponse?
    let calendarData: CalendarDetection?
    let messageId: String
    let conversationId: String
    let onEventCreated: (Event) -> Void
    
    // Form fields
    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var location: String
    
    // Invitation settings
    @State private var inviteAllParticipants: Bool = true
    
    // State
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showLinkingSuggestion = false
    @State private var suggestedEvent: SimilarEvent?
    
    // Services
    private let aiBackendService = AIBackendService()
    private let eventService = EventService()
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    
    init(analysis: MessageAnalysisResponse? = nil, calendarData: CalendarDetection? = nil, messageId: String, conversationId: String, onEventCreated: @escaping (Event) -> Void) {
        self.analysis = analysis
        self.calendarData = calendarData
        self.messageId = messageId
        self.conversationId = conversationId
        self.onEventCreated = onEventCreated
        
        // Initialize form fields with priority: calendarData > analysis > defaults
        if let calendarData = calendarData {
            self._title = State(initialValue: calendarData.title ?? "")
            self._date = State(initialValue: Self.parseDate(from: calendarData.date) ?? Date())
            self._hasTime = State(initialValue: calendarData.startTime != nil)
            
            let parsedStartTime = Self.parseTime(from: calendarData.startTime) ?? Date()
            self._startTime = State(initialValue: parsedStartTime)
            
            if let endTimeStr = calendarData.endTime {
                self._endTime = State(initialValue: Self.parseTime(from: endTimeStr) ?? Self.addHour(to: parsedStartTime))
            } else {
                self._endTime = State(initialValue: Self.addHour(to: parsedStartTime))
            }
            
            self._location = State(initialValue: calendarData.location ?? "")
        } else if let analysis = analysis {
            self._title = State(initialValue: analysis.calendar.title ?? "")
            self._date = State(initialValue: Self.parseDate(from: analysis.calendar.date) ?? Date())
            self._hasTime = State(initialValue: analysis.calendar.startTime != nil)
            
            let parsedStartTime = Self.parseTime(from: analysis.calendar.startTime) ?? Date()
            self._startTime = State(initialValue: parsedStartTime)
            
            if let endTimeStr = analysis.calendar.endTime {
                self._endTime = State(initialValue: Self.parseTime(from: endTimeStr) ?? Self.addHour(to: parsedStartTime))
            } else {
                self._endTime = State(initialValue: Self.addHour(to: parsedStartTime))
            }
            
            self._location = State(initialValue: analysis.calendar.location ?? "")
        } else {
            self._title = State(initialValue: "")
            self._date = State(initialValue: Date())
            self._hasTime = State(initialValue: false)
            self._startTime = State(initialValue: Date())
            self._endTime = State(initialValue: Self.addHour(to: Date()))
            self._location = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Event title", text: $title)
                } header: {
                    Text("What")
                }
                
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Toggle("Add time", isOn: $hasTime)
                    
                    if hasTime {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                            .onChange(of: startTime) { oldValue, newValue in
                                // Auto-update end time to maintain duration
                                if endTime <= newValue {
                                    endTime = Self.addHour(to: newValue)
                                }
                            }
                        
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        
                        // Show duration
                        let duration = Self.calculateDuration(from: startTime, to: endTime)
                        if duration > 0 {
                            Text("Duration: \(Self.formatDuration(duration))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("End time must be after start time")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("When")
                }
                
                Section {
                    TextField("Location (optional)", text: $location)
                } header: {
                    Text("Where")
                }
                
                Section {
                        Toggle("Invite participants", isOn: $inviteAllParticipants)
                    
                    if inviteAllParticipants {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All chat participants will be automatically invited to this event.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("They will receive a notification and can RSVP directly from the chat.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Invitations")
                } footer: {
                    if inviteAllParticipants {
                        Text("All chat participants will be invited to this event and can RSVP.")
                    } else {
                        Text("Create a personal event without sending invitations.")
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if showLinkingSuggestion {
                    Section {
                        if let suggestedEvent = suggestedEvent {
                            Text("Found similar event: '\(suggestedEvent.title ?? "")' on \(suggestedEvent.date ?? ""). Would you like to link to this existing event instead of creating a new one?")
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(inviteAllParticipants ? "Create & Invite" : "Create Event") {
                        Task {
                            if showLinkingSuggestion {
                                await linkToExistingEvent()
                            } else {
                                await createEventWithInvitations()
                            }
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
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
            let startTimeString = hasTime ? formatTimeHHMM(startTime) : nil
            let endTimeString = hasTime ? formatTimeHHMM(endTime) : nil
            let duration = hasTime ? Self.calculateDuration(from: startTime, to: endTime) : nil
            
            // Validate end time is after start time
            if hasTime && duration != nil && duration! <= 0 {
                throw NSError(domain: "EventInvitation", code: 400, userInfo: [NSLocalizedDescriptionKey: "End time must be after start time"])
            }
            
            // Call backend to create event
            print("🔍 Creating event: title=\(title), date=\(dateString), startTime=\(startTimeString ?? "nil"), endTime=\(endTimeString ?? "nil"), duration=\(duration ?? 0), location=\(location.isEmpty ? "nil" : location)")
            let response = try await aiBackendService.createEvent(
                title: title,
                date: dateString,
                startTime: startTimeString,
                endTime: endTimeString,
                duration: duration,
                location: location.isEmpty ? nil : location,
                userId: userId,
                conversationId: conversationId,
                messageId: messageId
            )
            print("🔍 Backend response: success=\(response.success), eventId=\(response.eventId ?? "nil"), suggestLink=\(response.suggestLink)")
            
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
            
            // Get conversation to determine participants
            let conversation = try await FirestoreService().getConversation(conversationId: conversationId)
            
            // Determine participants to invite
            let participantsToInvite: [String]
            if inviteAllParticipants {
                participantsToInvite = conversation.participants.filter { $0 != userId }
            } else {
                participantsToInvite = []
            }
            
            // Create attendees dictionary with invited participants (only if inviting)
            var attendees: [String: String] = [:]
            if inviteAllParticipants && !participantsToInvite.isEmpty {
                for participantId in participantsToInvite {
                    attendees[participantId] = "pending"
                }
            }
            
            // Create invitation if inviting participants
            var invitation: Invitation? = nil
            if inviteAllParticipants && !participantsToInvite.isEmpty {
                invitation = Invitation(
                    messageId: messageId,
                    invitedUserIds: participantsToInvite
                )
            }
            
            // Note: Event linking will be handled by the parent view after event is stored in Firestore
            
            // Create Event object for callback
            if let eventId = response.eventId {
                print("🔍 Creating Event object: eventId=\(eventId), attendees=\(attendees), invitation=\(invitation != nil)")
                let event = Event(
                    eventId: eventId,
                    title: title,
                    date: date,
                    startTime: startTimeString,
                    endTime: endTimeString,
                    duration: duration,
                    location: location.isEmpty ? nil : location,
                    creatorUserId: userId,
                    createdAt: Date(),
                    createdInConversationId: conversationId,
                    createdAtMessageId: messageId,
                    invitations: invitation != nil ? [conversationId: invitation!] : [:],
                    attendees: Dictionary(uniqueKeysWithValues: attendees.map { ($0.key, Attendee()) })
                )
                
                await MainActor.run {
                    onEventCreated(event)
                    dismiss()
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
    
    private func linkToExistingEvent() async {
        guard let suggestedEvent = suggestedEvent else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Get current user ID
            guard let userId = AuthService.shared.currentUser?.userId else {
                throw NSError(domain: "EventInvitation", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Get conversation to determine participants
            let conversation = try await FirestoreService().getConversation(conversationId: conversationId)
            
            // Determine participants to invite
            let participantsToInvite: [String]
            if inviteAllParticipants {
                participantsToInvite = conversation.participants.filter { $0 != userId }
            } else {
                participantsToInvite = []
            }
            
            // Create invitation if inviting participants
            var invitation: Invitation? = nil
            if inviteAllParticipants && !participantsToInvite.isEmpty {
                invitation = Invitation(
                    messageId: messageId,
                    invitedUserIds: participantsToInvite
                )
            }
            
            // Note: Event linking will be handled by the parent view after event is stored in Firestore
            
            // Create Event object for callback
            let event = Event(
                eventId: suggestedEvent.eventId ?? "",
                title: suggestedEvent.title ?? title,
                date: Self.parseDate(from: suggestedEvent.date) ?? date,
                startTime: hasTime ? formatTimeHHMM(startTime) : nil,
                endTime: hasTime ? formatTimeHHMM(endTime) : nil,
                duration: hasTime ? Self.calculateDuration(from: startTime, to: endTime) : nil,
                location: location.isEmpty ? nil : location,
                creatorUserId: userId,
                createdAt: Date(),
                createdInConversationId: conversationId,
                createdAtMessageId: messageId,
                invitations: invitation != nil ? [conversationId: invitation!] : [:],
                attendees: Dictionary(uniqueKeysWithValues: (invitation?.invitedUserIds ?? []).map { ($0, Attendee()) })
            )
            
            await MainActor.run {
                onEventCreated(event)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getConversationParticipants() async -> [String] {
        do {
            let conversation = try await FirestoreService().getConversation(conversationId: conversationId)
            return conversation.participants
        } catch {
            return []
        }
    }
    
    private static func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private static func parseTime(from timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
    
    private static func addHour(to date: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
    }
    
    private static func calculateDuration(from startTime: Date, to endTime: Date) -> Int {
        // Return duration in minutes
        let components = Calendar.current.dateComponents([.minute], from: startTime, to: endTime)
        return components.minute ?? 0
    }
    
    private static func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
    
    private func formatDateISO(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatTimeHHMM(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
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
                startTime: "20:00",
                endTime: "23:00",
                duration: 180,
                location: "My place",
                isInvitation: true
            ),
            reminder: ReminderDetection(detected: false, title: nil, dueDate: nil),
            decision: DecisionDetection(detected: false, text: nil),
            rsvp: RSVPDetection(detected: false, status: nil, eventReference: nil),
            priority: PriorityDetection(detected: false, level: nil, reason: nil),
            conflict: ConflictDetection(detected: false, conflictingEvents: [])
        ),
        messageId: "msg_123",
        conversationId: "conv_456"
    ) { event in
        print("Event created: \(event.title)")
    }
}