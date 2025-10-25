//
//  RSVPQuickActionsView.swift
//  MessageAI
//
//  Quick action buttons for RSVP responses on invitation messages
//  Story 5.4 - RSVP Tracking
//

import SwiftUI

/// Quick action buttons for RSVP responses
struct RSVPQuickActionsView: View {
    let eventId: String
    let eventTitle: String
    let conversationId: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Accept button
            Button(action: onAccept) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Accept")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green)
                )
            }
            .buttonStyle(.plain)
            
            // Decline button
            Button(action: onDecline) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Decline")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

/// RSVP confirmation modal
struct RSVPModal: View {
    @Environment(\.dismiss) private var dismiss
    
    let eventId: String
    let eventTitle: String
    let conversationId: String
    let preSelectedStatus: RSVPStatus
    let onConfirm: (RSVPStatus, String?) -> Void
    
    @State private var selectedStatus: RSVPStatus
    @State private var message: String = ""
    @State private var isSubmitting = false
    
    private let eventService = EventService()
    private let authService = AuthService.shared
    
    init(eventId: String, eventTitle: String, conversationId: String, preSelectedStatus: RSVPStatus, onConfirm: @escaping (RSVPStatus, String?) -> Void) {
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.conversationId = conversationId
        self.preSelectedStatus = preSelectedStatus
        self.onConfirm = onConfirm
        self._selectedStatus = State(initialValue: preSelectedStatus)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("RSVP for: \(eventTitle)")
                        .font(.headline)
                } header: {
                    Text("Event")
                }
                
                Section {
                    Picker("RSVP Status", selection: $selectedStatus) {
                        Text("Accept").tag(RSVPStatus.accepted)
                        Text("Decline").tag(RSVPStatus.declined)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Your Response")
                }
                
                Section {
                    TextField("Add a message (optional)", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Message")
                } footer: {
                    Text("This message will be posted to the chat with your RSVP confirmation.")
                }
                
                if isSubmitting {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Submitting RSVP...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            }
            .navigationTitle("RSVP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        Task {
                            await submitRSVP()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
    
    private func submitRSVP() async {
        isSubmitting = true
        
        do {
            // Get current user ID
            guard let userId = authService.currentUser?.userId else {
                print("Error: User not authenticated")
                isSubmitting = false
                return
            }
            
            // Submit RSVP using EventService
            try await eventService.submitRSVP(
                eventId: eventId,
                userId: userId,
                status: selectedStatus,
                message: message.isEmpty ? nil : message,
                conversationId: conversationId
            )
            
            // Call the onConfirm callback with the selected status and message
            onConfirm(selectedStatus, message.isEmpty ? nil : message)
            
            // Dismiss the modal
            dismiss()
            
        } catch {
            print("Error submitting RSVP: \(error.localizedDescription)")
            isSubmitting = false
        }
    }
}

// MARK: - Preview

#Preview("RSVP Quick Actions") {
    VStack(spacing: 16) {
        Text("RSVP Quick Actions")
            .font(.headline)
        
        RSVPQuickActionsView(
            eventId: "evt_123",
            eventTitle: "Party at my place Friday!",
            conversationId: "conv_456",
            onAccept: {
                print("Accept tapped")
            },
            onDecline: {
                print("Decline tapped")
            }
        )
    }
    .padding()
}

#Preview("RSVP Modal - Accept") {
    RSVPModal(
        eventId: "evt_123",
        eventTitle: "Party at my place Friday!",
        conversationId: "conv_456",
        preSelectedStatus: .accepted
    ) { status, message in
        print("RSVP confirmed: \(status), message: \(message ?? "none")")
    }
}

#Preview("RSVP Modal - Decline") {
    RSVPModal(
        eventId: "evt_123",
        eventTitle: "Party at my place Friday!",
        conversationId: "conv_456",
        preSelectedStatus: .declined
    ) { status, message in
        print("RSVP confirmed: \(status), message: \(message ?? "none")")
    }
}
