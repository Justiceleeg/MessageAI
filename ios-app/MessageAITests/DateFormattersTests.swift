//
//  DateFormattersTests.swift
//  MessageAITests
//
//  Created by Justice Perez White on 10/21/25.
//

import XCTest
@testable import MessageAI

final class DateFormattersTests: XCTestCase {
    
    var formatter: DateFormatters!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        formatter = DateFormatters.shared
        calendar = Calendar.current
    }
    
    override func tearDown() {
        formatter = nil
        calendar = nil
        super.tearDown()
    }
    
    // MARK: - Conversation Timestamp Tests
    
    func testFormatConversationTimestamp_Today_ReturnsTime() {
        // Arrange
        let now = Date()
        
        // Act
        let result = formatter.formatConversationTimestamp(now)
        
        // Assert
        // Should contain time format like "10:30 AM" or "3:45 PM"
        XCTAssertTrue(result.contains("M"), "Today's timestamp should show time with AM/PM")
        XCTAssertTrue(result.contains(":"), "Today's timestamp should contain colon")
    }
    
    func testFormatConversationTimestamp_Yesterday_ReturnsYesterday() {
        // Arrange
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        // Act
        let result = formatter.formatConversationTimestamp(yesterday)
        
        // Assert
        XCTAssertEqual(result, "Yesterday", "Yesterday's date should show 'Yesterday'")
    }
    
    func testFormatConversationTimestamp_ThisWeek_ReturnsWeekday() {
        // Arrange
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        
        // Act
        let result = formatter.formatConversationTimestamp(threeDaysAgo)
        
        // Assert
        // Should be a weekday name like "Monday", "Tuesday", etc.
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        XCTAssertTrue(weekdays.contains(result), "Recent date should show weekday name")
    }
    
    func testFormatConversationTimestamp_ThisYear_ReturnsMonthDay() {
        // Arrange
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: Date())!
        
        // Act
        let result = formatter.formatConversationTimestamp(twoMonthsAgo)
        
        // Assert
        // Should be like "Oct 15" or "Aug 21"
        XCTAssertTrue(result.count >= 5, "Should show month and day")
        XCTAssertFalse(result.contains(","), "Should not contain year separator")
    }
    
    func testFormatConversationTimestamp_OlderThanThisYear_ReturnsFullDate() {
        // Arrange
        let lastYear = calendar.date(byAdding: .year, value: -1, to: Date())!
        
        // Act
        let result = formatter.formatConversationTimestamp(lastYear)
        
        // Assert
        // Should be like "Oct 15, 2023"
        XCTAssertTrue(result.contains(","), "Should contain comma for year")
        let components = result.components(separatedBy: ", ")
        XCTAssertEqual(components.count, 2, "Should have month-day and year parts")
    }
    
    func testFormatConversationTimestamp_Nil_ReturnsEmpty() {
        // Act
        let result = formatter.formatConversationTimestamp(nil)
        
        // Assert
        XCTAssertEqual(result, "", "Nil date should return empty string")
    }
    
    // MARK: - Message Timestamp Tests
    
    func testFormatMessageTimestamp_Today_ReturnsTodayWithTime() {
        // Arrange
        let now = Date()
        
        // Act
        let result = formatter.formatMessageTimestamp(now)
        
        // Assert
        XCTAssertTrue(result.hasPrefix("Today at"), "Should start with 'Today at'")
        XCTAssertTrue(result.contains("M"), "Should contain AM/PM")
    }
    
    func testFormatMessageTimestamp_Yesterday_ReturnsYesterdayWithTime() {
        // Arrange
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        // Act
        let result = formatter.formatMessageTimestamp(yesterday)
        
        // Assert
        XCTAssertTrue(result.hasPrefix("Yesterday at"), "Should start with 'Yesterday at'")
        XCTAssertTrue(result.contains("M"), "Should contain AM/PM")
    }
    
    func testFormatMessageTimestamp_OlderDate_ReturnsFullDateWithTime() {
        // Arrange
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        
        // Act
        let result = formatter.formatMessageTimestamp(threeDaysAgo)
        
        // Assert
        XCTAssertTrue(result.contains(" at "), "Should contain ' at ' separator")
        XCTAssertTrue(result.contains("M"), "Should contain AM/PM")
    }
    
    func testFormatMessageTimestamp_Nil_ReturnsEmpty() {
        // Act
        let result = formatter.formatMessageTimestamp(nil)
        
        // Assert
        XCTAssertEqual(result, "", "Nil date should return empty string")
    }
    
    // MARK: - Relative Time Tests
    
    func testFormatRelativeTime_RecentDate_ReturnsRelativeString() {
        // Arrange
        let twoMinutesAgo = calendar.date(byAdding: .minute, value: -2, to: Date())!
        
        // Act
        let result = formatter.formatRelativeTime(twoMinutesAgo)
        
        // Assert
        XCTAssertFalse(result.isEmpty, "Should return non-empty relative time")
        // The exact format depends on iOS version and locale, so we just check it's not empty
    }
    
    func testFormatRelativeTime_Nil_ReturnsEmpty() {
        // Act
        let result = formatter.formatRelativeTime(nil)
        
        // Assert
        XCTAssertEqual(result, "", "Nil date should return empty string")
    }
    
    // MARK: - Date Extension Tests
    
    func testDateExtension_ConversationTimestamp() {
        // Arrange
        let date = Date()
        
        // Act
        let result = date.conversationTimestamp
        
        // Assert
        XCTAssertFalse(result.isEmpty, "Extension should return formatted timestamp")
    }
    
    func testDateExtension_MessageTimestamp() {
        // Arrange
        let date = Date()
        
        // Act
        let result = date.messageTimestamp
        
        // Assert
        XCTAssertTrue(result.hasPrefix("Today at"), "Extension should return message timestamp")
    }
    
    func testDateExtension_RelativeTime() {
        // Arrange
        let date = Date()
        
        // Act
        let result = date.relativeTime
        
        // Assert
        XCTAssertFalse(result.isEmpty, "Extension should return relative time")
    }
}

