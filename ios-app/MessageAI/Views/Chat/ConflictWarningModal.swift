//
//  ConflictWarningModal.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-26.
//

import SwiftUI

struct ConflictWarningModal: View {
    let messageId: String
    let conversationId: String
    let calendarData: CalendarDetection
    let analysis: MessageAnalysisResponse
    let onDismiss: () -> Void
    let onCreateAnyway: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with warning icon
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Time Conflict Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("You have a scheduling conflict with an existing event.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // New Event Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Event")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text(calendarData.title ?? "Untitled Event")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let date = calendarData.date {
                        Text("Date: \(Self.formatDate(date))")
                            .font(.subheadline)
                    }
                    
                    if let startTime = calendarData.startTime, let endTime = calendarData.endTime {
                        Text("Time: \(Self.formatTime(startTime)) - \(Self.formatTime(endTime))")
                            .font(.subheadline)
                    } else if let startTime = calendarData.startTime {
                        Text("Time: \(Self.formatTime(startTime))")
                            .font(.subheadline)
                    }
                    
                    if let location = calendarData.location, !location.isEmpty {
                        Text("Location: \(location)")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Conflicting Events
                if !analysis.conflict.conflictingEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conflicting Events")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ForEach(analysis.conflict.conflictingEvents, id: \.id) { conflict in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let startTime = conflict.startTime, let endTime = conflict.endTime {
                                    Text("\(Self.formatTime(startTime)) - \(Self.formatTime(endTime))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let startTime = conflict.startTime {
                                    Text(Self.formatTime(startTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let location = conflict.location, !location.isEmpty {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    // Fallback when conflictingEvents is empty but conflict is detected
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Existing Event")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("You have an existing event at this time.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button {
                        onCreateAnyway()
                    } label: {
                        Label("Create Anyway", systemImage: "calendar.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle("Schedule Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private static func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private static func formatTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let time = formatter.date(from: timeString) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: time)
        }
        return timeString
    }
}

#Preview {
    ConflictWarningModal(
        messageId: "preview",
        conversationId: "preview",
        calendarData: CalendarDetection(
            detected: true,
            title: "Shopping",
            date: "2025-10-26",
            startTime: "19:00",
            endTime: "20:00",
            duration: 60,
            location: "Mall",
            isInvitation: true,
            similarEvents: []
        ),
        analysis: MessageAnalysisResponse(
            messageId: "preview",
            calendar: CalendarDetection(
                detected: true,
                title: "Shopping",
                date: "2025-10-26",
                startTime: "19:00",
                endTime: "20:00",
                duration: 60,
                location: "Mall",
                isInvitation: true,
                similarEvents: []
            ),
            reminder: ReminderDetection(detected: false, title: nil, dueDate: nil),
            decision: DecisionDetection(detected: false, text: nil),
            rsvp: RSVPDetection(detected: false, status: nil, eventReference: nil),
            priority: PriorityDetection(detected: false, level: nil, reason: nil),
            conflict: ConflictDetection(
                detected: true,
                conflictingEvents: [
                    ConflictEvent(
                        id: "conflict1",
                        title: "Skateboarding",
                        date: "2025-10-26",
                        startTime: "19:00",
                        endTime: "20:00",
                        location: "Park",
                        similarityScore: 0.15
                    )
                ],
                reasoning: "This conflicts with your existing 'Skateboarding' event at the same time",
                sameEventDetected: false
            )
        ),
        onDismiss: {},
        onCreateAnyway: {}
    )
}
