import SwiftUI

struct SimilarEventModal: View {
    let messageId: String
    let conversationId: String
    let calendarData: CalendarDetection
    let analysis: MessageAnalysisResponse
    let onDismiss: () -> Void
    let onLinkToEvent: (String) -> Void
    let onCreateNewEvent: () -> Void
    
    @State private var selectedEventId: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Similar Event Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("We found a similar event that might be the same as what you're discussing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Event details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detected Event:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(calendarData.title ?? "Untitled Event")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        if let date = calendarData.date {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                Text(formatEventTime(date: date, startTime: calendarData.startTime, endTime: calendarData.endTime))
                                    .font(.subheadline)
                            }
                        }
                        
                        if let location = calendarData.location, !location.isEmpty {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.blue)
                                Text(location)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    // Link to existing event
                    Button(action: {
                        if let firstEventId = calendarData.similarEvents?.first {
                            onLinkToEvent(firstEventId)
                        }
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("Link to Event")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Create new event
                    Button(action: onCreateNewEvent) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create New Event")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    // Cancel
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Link Event")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                onDismiss()
            })
        }
    }
    
    private func formatEventTime(date: String, startTime: String?, endTime: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let eventDate = formatter.date(from: date) else {
            return date
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        
        var timeString = displayFormatter.string(from: eventDate)
        
        if let startTime = startTime, !startTime.isEmpty {
            timeString += " at \(formatTime(startTime))"
            
            if let endTime = endTime, !endTime.isEmpty {
                timeString += " - \(formatTime(endTime))"
            }
        }
        
        return timeString
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let time = formatter.date(from: timeString) else {
            return timeString
        }
        
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}

#Preview {
    SimilarEventModal(
        messageId: "preview",
        conversationId: "preview",
        calendarData: CalendarDetection(
            detected: true,
            title: "Skateboarding",
            date: "2025-10-26",
            startTime: "19:00",
            endTime: "20:00",
            duration: 60,
            location: "Central Park",
            isInvitation: true,
            similarEvents: ["evt_123", "evt_456"]
        ),
        analysis: MessageAnalysisResponse(
            messageId: "preview",
            calendar: CalendarDetection(
                detected: true,
                title: "Skateboarding",
                date: "2025-10-26",
                startTime: "19:00",
                endTime: "20:00",
                duration: 60,
                location: "Central Park",
                isInvitation: true,
                similarEvents: ["evt_123", "evt_456"]
            ),
            reminder: ReminderDetection(detected: false, title: nil, dueDate: nil),
            decision: DecisionDetection(detected: false, text: nil),
            rsvp: RSVPDetection(detected: false, status: nil, eventReference: nil),
            priority: PriorityDetection(detected: false, level: nil, reason: nil),
            conflict: ConflictDetection(
                detected: false,
                conflictingEvents: [],
                reasoning: nil,
                sameEventDetected: nil
            )
        ),
        onDismiss: {},
        onLinkToEvent: { _ in },
        onCreateNewEvent: {}
    )
}
