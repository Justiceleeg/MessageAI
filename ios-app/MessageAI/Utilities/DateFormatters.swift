//
//  DateFormatters.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import Foundation

/// Utility class for formatting dates in messaging contexts
final class DateFormatters {
    
    // MARK: - Singleton
    
    static let shared = DateFormatters()
    
    // MARK: - Static Formatters
    
    /// Formatter for message bubble timestamps (e.g., "10:30 AM")
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Private Properties
    
    private let calendar = Calendar.current
    
    /// Formatter for time display (e.g., "10:30 AM")
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    /// Formatter for date display (e.g., "Oct 15")
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    /// Formatter for full date with year (e.g., "Oct 15, 2024")
    private lazy var fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    /// Formatter for day of week (e.g., "Monday")
    private lazy var weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Format a timestamp for display in conversation list
    /// - Parameter date: The date to format
    /// - Returns: Formatted string (e.g., "10:30 AM", "Yesterday", "Monday", "Oct 15")
    func formatConversationTimestamp(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        
        let now = Date()
        
        // Check if today
        if calendar.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }
        
        // Check if yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        // Check if within the last week
        if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day,
           daysAgo < 7 {
            return weekdayFormatter.string(from: date)
        }
        
        // Check if this year
        let dateYear = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)
        
        if dateYear == currentYear {
            return dateFormatter.string(from: date)
        }
        
        // Older than this year
        return fullDateFormatter.string(from: date)
    }
    
    /// Format a timestamp for detailed message display
    /// - Parameter date: The date to format
    /// - Returns: Formatted string with full date and time
    func formatMessageTimestamp(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        
        if calendar.isDateInToday(date) {
            return "Today at \(timeFormatter.string(from: date))"
        }
        
        if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeFormatter.string(from: date))"
        }
        
        return "\(fullDateFormatter.string(from: date)) at \(timeFormatter.string(from: date))"
    }
    
    /// Get relative time string (e.g., "2 min ago", "1 hour ago")
    /// - Parameter date: The date to format
    /// - Returns: Relative time string
    func formatRelativeTime(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Date Extension

extension Date {
    /// Get formatted conversation timestamp using shared formatter
    var conversationTimestamp: String {
        DateFormatters.shared.formatConversationTimestamp(self)
    }
    
    /// Get formatted message timestamp using shared formatter
    var messageTimestamp: String {
        DateFormatters.shared.formatMessageTimestamp(self)
    }
    
    /// Get relative time string using shared formatter
    var relativeTime: String {
        DateFormatters.shared.formatRelativeTime(self)
    }
}

