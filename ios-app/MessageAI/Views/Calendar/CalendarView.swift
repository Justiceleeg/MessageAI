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
    private let reminderService = ReminderService()
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var selectedTab: CalendarTab = .events
    @State private var events: [Event] = []
    @State private var reminders: [Reminder] = []
    @State private var selectedDate: Date = Date()
    @State private var selectedEvent: Event?
    @State private var selectedReminder: Reminder?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Firestore listeners
    @State private var eventListener: ListenerRegistration?
    @State private var reminderListener: ListenerRegistration?
    
    // MARK: - Initialization
    
    init(conversationId: String? = nil) {
        self.conversationId = conversationId
    }
    
    enum CalendarTab: String, CaseIterable {
        case events = "Events"
        case reminders = "Reminders"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    ForEach(CalendarTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
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
            .sheet(item: $selectedReminder) { reminder in
                ReminderDetailView(reminder: reminder, onDelete: {
                    deleteReminder(reminder)
                }, onMarkComplete: {
                    markReminderComplete(reminder)
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
        if selectedTab == .events {
            EventsCalendarView(
                events: events,
                selectedDate: $selectedDate,
                onEventTap: { event in
                    selectedEvent = event
                }
            )
        } else {
            RemindersListView(
                reminders: reminders,
                onReminderTap: { reminder in
                    selectedReminder = reminder
                },
                onMarkComplete: { reminder in
                    markReminderComplete(reminder)
                },
                onDelete: { reminder in
                    deleteReminder(reminder)
                }
            )
        }
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
                async let eventsTask = eventService.listEvents(userId: userId)
                async let remindersTask = reminderService.listReminders(userId: userId)
                
                let allEvents = try await eventsTask
                let allReminders = try await remindersTask
                
                // Filter by conversationId if provided
                if let conversationId = conversationId {
                    events = allEvents.filter { $0.createdInConversationId == conversationId }
                    reminders = allReminders.filter { $0.conversationId == conversationId }
                } else {
                    events = allEvents
                    reminders = allReminders
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
        eventListener = eventService.observeUserEvents(userId: userId) { updatedEvents in
            // Filter by conversationId if provided
            if let conversationId = conversationId {
                events = updatedEvents.filter { $0.createdInConversationId == conversationId }
            } else {
                events = updatedEvents
            }
        }
        
        reminderListener = reminderService.observeUserReminders(userId: userId) { updatedReminders in
            // Filter by conversationId if provided
            if let conversationId = conversationId {
                reminders = updatedReminders.filter { $0.conversationId == conversationId }
            } else {
                reminders = updatedReminders
            }
        }
    }
    
    private func removeListeners() {
        eventListener?.remove()
        reminderListener?.remove()
        eventListener = nil
        reminderListener = nil
    }
    
    // MARK: - Actions
    
    private func deleteEvent(_ event: Event) {
        Task {
            do {
                try await eventService.deleteEvent(id: event.eventId)
                selectedEvent = nil
            } catch {
                errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        Task {
            do {
                try await reminderService.deleteReminder(id: reminder.reminderId)
                selectedReminder = nil
            } catch {
                errorMessage = "Failed to delete reminder: \(error.localizedDescription)"
            }
        }
    }
    
    private func markReminderComplete(_ reminder: Reminder) {
        Task {
            do {
                try await reminderService.markComplete(reminderId: reminder.reminderId)
                selectedReminder = nil
            } catch {
                errorMessage = "Failed to mark reminder complete: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environmentObject(AuthViewModel())
}

