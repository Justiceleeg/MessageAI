//
//  CalendarView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/24/25.
//

import SwiftUI
import FirebaseFirestore

/// Main calendar view with Events and Reminders tabs
struct CalendarView: View {
    
    // MARK: - Properties
    
    /// Optional conversation ID to filter events/reminders (Story 5.1.5)
    let conversationId: String?
    
    private let eventService = EventService()
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var events: [Event] = []
    @State private var selectedDate: Date = Date()
    @State private var selectedEvent: Event?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Firestore listeners
    @State private var eventListener: ListenerRegistration?
    
    // MARK: - Initialization
    
    init(conversationId: String? = nil) {
        self.conversationId = conversationId
    }
    
    enum CalendarTab: String, CaseIterable {
        case events = "Events"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle(conversationId != nil ? "Conversation Calendar" : "Calendar")
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, onDelete: {
                    deleteEvent(event)
                })
            }
            .onAppear {
                setupView()
            }
            .onDisappear {
                removeListeners()
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        EventsCalendarView(
            events: events,
            selectedDate: $selectedDate,
            onEventTap: { event in
                selectedEvent = event
            }
        )
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                setupView()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
    
    // MARK: - Setup and Lifecycle
    
    private func setupView() {
        guard let userId = authViewModel.authService.currentUser?.userId else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        loadInitialData(userId: userId)
        setupListeners(userId: userId)
    }
    
    private func loadInitialData(userId: String) {
        Task {
            do {
                // Use listAllUserEvents to get both created and attended events (Story 5.4)
                let allEvents = try await eventService.listAllUserEvents(userId: userId)
                
                // Filter by conversationId if provided
                if let conversationId = conversationId {
                    events = allEvents.filter { $0.createdInConversationId == conversationId }
                } else {
                    events = allEvents
                }
                
                isLoading = false
            } catch {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func setupListeners(userId: String) {
        // Remove existing listeners
        removeListeners()
        
        // Set up real-time listeners
        // Use observeAllUserEvents to get both created and attended events (Story 5.4)
        eventListener = eventService.observeAllUserEvents(userId: userId) { updatedEvents in
            // Filter by conversationId if provided
            if let conversationId = conversationId {
                events = updatedEvents.filter { $0.createdInConversationId == conversationId }
            } else {
                events = updatedEvents
            }
        }
    }
    
    private func removeListeners() {
        eventListener?.remove()
        eventListener = nil
    }
    
    // MARK: - Actions
    
    private func deleteEvent(_ event: Event) {
        print("🗑️ DEBUG: Starting event deletion for: \(event.eventId)")
        Task {
            do {
                print("🗑️ DEBUG: Calling eventService.deleteEvent")
                try await eventService.deleteEvent(id: event.eventId)
                print("✅ DEBUG: Event deleted successfully")
                selectedEvent = nil
                print("✅ DEBUG: selectedEvent set to nil")
            } catch {
                print("❌ DEBUG: Failed to delete event: \(error.localizedDescription)")
                print("❌ DEBUG: Full error: \(error)")
                errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
        }
    }
    
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environmentObject(AuthViewModel())
}

