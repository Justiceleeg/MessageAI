//
//  EventsCalendarView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/24/25.
//

import SwiftUI

/// Calendar grid view showing events with native SwiftUI implementation
struct EventsCalendarView: View {
    
    // MARK: - Properties
    
    let events: [Event]
    @Binding var selectedDate: Date
    var onEventTap: (Event) -> Void
    
    @State private var displayedMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Month/Year header with navigation
            monthYearHeader
            
            // Days of week header
            daysOfWeekHeader
            
            // Calendar grid
            calendarGrid
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            // Events for selected date
            eventsForDateSection
        }
    }
    
    // MARK: - Subviews
    
    private var monthYearHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    // Empty cell for padding
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
    }
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = eventsForDate(date).count > 0
        
        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16))
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                
                // Event indicator dots
                if hasEvents {
                    Circle()
                        .fill(isSelected ? Color.white : Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var eventsForDateSection: some View {
        Group {
            if eventsForSelectedDate.isEmpty {
                emptyDateView
            } else {
                eventsList
            }
        }
    }
    
    private var emptyDateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No events on this day")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(eventsForSelectedDate) { event in
                    EventRowView(event: event)
                        .onTapGesture {
                            onEventTap(event)
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let _ = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)?.start else {
            return []
        }
        
        var days: [Date?] = []
        let daysBefore = calendar.component(.weekday, from: monthInterval.start) - 1
        
        // Add empty cells for days before month starts
        for _ in 0..<daysBefore {
            days.append(nil)
        }
        
        // Add all days in the month
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private var eventsForSelectedDate: [Event] {
        eventsForDate(selectedDate)
            .sorted { $0.date < $1.date }
    }
    
    private func eventsForDate(_ date: Date) -> [Event] {
        events.filter { event in
            calendar.isDate(event.date, inSameDayAs: date)
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 4) {
                if let time = event.time {
                    Text(time)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("All day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Attendee count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(event.attendees.count) attending")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
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
    }
}

// MARK: - Preview

#Preview {
    EventsCalendarView(
        events: [
            Event(
                title: "Team Meeting",
                date: Date(),
                time: "10:00 AM",
                location: "Conference Room",
                creatorUserId: "user1",
                createdInConversationId: "conv1",
                createdAtMessageId: "msg1"
            ),
            Event(
                title: "Lunch with Client",
                date: Date(),
                time: "12:30 PM",
                location: "Downtown Cafe",
                creatorUserId: "user1",
                createdInConversationId: "conv1",
                createdAtMessageId: "msg2"
            )
        ],
        selectedDate: .constant(Date()),
        onEventTap: { _ in }
    )
}
