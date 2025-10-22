//
//  NotificationManagerTests.swift
//  MessageAITests
//
//  Story 3.4: Implement Notification System (Mock Push for Demo)
//  Unit tests for NotificationManager service
//

import XCTest
@testable import MessageAI
import UserNotifications

@MainActor
final class NotificationManagerTests: XCTestCase {
    
    var sut: NotificationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = NotificationManager()
    }
    
    override func tearDown() async throws {
        sut.stopListening()
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Suppression Logic Tests
    
    /// Test that notification is suppressed when viewing the same conversation
    func testShouldSuppressNotification_WhenViewingConversation_ReturnsTrue() {
        // Given: User is viewing a conversation
        let conversationId = "test_conversation_123"
        sut.currentlyViewedConversationId = conversationId
        
        // When: Checking if notification should be suppressed for that conversation
        let shouldSuppress = sut.shouldSuppressNotification(for: conversationId)
        
        // Then: Should return true (suppress notification)
        XCTAssertTrue(shouldSuppress, "Should suppress notification when viewing the same conversation")
    }
    
    /// Test that notification is NOT suppressed when viewing a different conversation
    func testShouldSuppressNotification_WhenViewingDifferentConversation_ReturnsFalse() {
        // Given: User is viewing one conversation
        let viewingConversationId = "test_conversation_123"
        let otherConversationId = "test_conversation_456"
        sut.currentlyViewedConversationId = viewingConversationId
        
        // When: Checking if notification should be suppressed for a different conversation
        let shouldSuppress = sut.shouldSuppressNotification(for: otherConversationId)
        
        // Then: Should return false (don't suppress notification)
        XCTAssertFalse(shouldSuppress, "Should NOT suppress notification when viewing a different conversation")
    }
    
    /// Test that notification is NOT suppressed when not viewing any conversation
    func testShouldSuppressNotification_WhenNotViewingAnyConversation_ReturnsFalse() {
        // Given: User is not viewing any conversation
        sut.currentlyViewedConversationId = nil
        
        // When: Checking if notification should be suppressed
        let conversationId = "test_conversation_123"
        let shouldSuppress = sut.shouldSuppressNotification(for: conversationId)
        
        // Then: Should return false (don't suppress notification)
        XCTAssertFalse(shouldSuppress, "Should NOT suppress notification when not viewing any conversation")
    }
    
    // MARK: - Banner State Tests
    
    /// Test that showInAppBanner sets banner properties correctly
    func testShowInAppBanner_SetsBannerPropertiesCorrectly() {
        // Given: A conversation with message details
        let conversationId = "test_conversation_123"
        let title = "John Doe"
        let message = "Hello there!"
        
        // When: Showing in-app banner
        sut.showInAppBanner(conversationId: conversationId, title: title, message: message)
        
        // Then: Banner properties should be set correctly
        XCTAssertTrue(sut.showBanner, "showBanner should be true")
        XCTAssertEqual(sut.bannerConversationId, conversationId, "bannerConversationId should match")
        XCTAssertEqual(sut.bannerTitle, title, "bannerTitle should match")
        XCTAssertEqual(sut.bannerMessage, message, "bannerMessage should match")
    }
    
    /// Test that showInAppBanner is suppressed when viewing that conversation
    func testShowInAppBanner_WhenViewingConversation_DoesNotShowBanner() {
        // Given: User is viewing a conversation
        let conversationId = "test_conversation_123"
        sut.currentlyViewedConversationId = conversationId
        
        // When: Attempting to show banner for that conversation
        sut.showInAppBanner(conversationId: conversationId, title: "Test", message: "Test message")
        
        // Then: Banner should not be shown
        XCTAssertFalse(sut.showBanner, "Banner should be suppressed when viewing the same conversation")
    }
    
    /// Test that dismissBanner clears banner properties
    func testDismissBanner_ClearsBannerProperties() {
        // Given: A banner is currently showing
        let conversationId = "test_conversation_123"
        sut.showInAppBanner(conversationId: conversationId, title: "Test", message: "Test message")
        XCTAssertTrue(sut.showBanner, "Banner should be showing initially")
        
        // When: Dismissing the banner
        sut.dismissBanner()
        
        // Then: All banner properties should be cleared
        XCTAssertFalse(sut.showBanner, "showBanner should be false")
        XCTAssertNil(sut.bannerConversationId, "bannerConversationId should be nil")
        XCTAssertNil(sut.bannerTitle, "bannerTitle should be nil")
        XCTAssertNil(sut.bannerMessage, "bannerMessage should be nil")
    }
    
    /// Test that banner auto-dismisses after timeout
    func testShowInAppBanner_AutoDismissesAfterTimeout() async throws {
        // Given: A banner is shown
        let conversationId = "test_conversation_123"
        sut.showInAppBanner(conversationId: conversationId, title: "Test", message: "Test message")
        XCTAssertTrue(sut.showBanner, "Banner should be showing initially")
        
        // When: Waiting for 6 seconds (banner auto-dismisses after 5 seconds)
        try await Task.sleep(nanoseconds: 6_000_000_000)
        
        // Then: Banner should be auto-dismissed
        XCTAssertFalse(sut.showBanner, "Banner should auto-dismiss after 5 seconds")
        XCTAssertNil(sut.bannerConversationId, "bannerConversationId should be nil after auto-dismiss")
    }
    
    // MARK: - Permission Tests
    
    /// Test that permission status is stored in UserDefaults
    func testRequestNotificationPermissions_StoresResultInUserDefaults() async throws {
        // Note: This test will prompt for real permissions in test environment
        // In real tests, we would mock UNUserNotificationCenter
        
        // Given: Clean UserDefaults
        UserDefaults.standard.removeObject(forKey: "notificationPermission")
        
        // When: Requesting permissions
        let granted = await sut.requestNotificationPermissions()
        
        // Then: Permission status should be stored in UserDefaults
        let stored = UserDefaults.standard.bool(forKey: "notificationPermission")
        XCTAssertEqual(stored, granted, "Permission status should be stored in UserDefaults")
    }
    
    // MARK: - Listener Tests
    
    /// Test that startListening initializes listener
    func testStartListening_InitializesListener() {
        // Given: A user ID
        let userId = "test_user_123"
        
        // When: Starting to listen
        sut.startListening(userId: userId)
        
        // Then: Listener should be initialized (no crash)
        // Note: We can't easily test Firestore listener behavior in unit tests
        // This test just verifies the method can be called without errors
    }
    
    /// Test that stopListening cleans up listener
    func testStopListening_CleansUpListener() {
        // Given: A listener is active
        let userId = "test_user_123"
        sut.startListening(userId: userId)
        
        // When: Stopping the listener
        sut.stopListening()
        
        // Then: Listener should be cleaned up (no crash)
        // Note: We can't easily verify listener removal in unit tests
        // This test just verifies the method can be called without errors
    }
    
    // MARK: - Multiple Banner Tests
    
    /// Test that showing a new banner while one is already showing replaces it
    func testShowInAppBanner_ReplacesExistingBanner() {
        // Given: A banner is already showing
        sut.showInAppBanner(conversationId: "conv_1", title: "First", message: "First message")
        XCTAssertEqual(sut.bannerConversationId, "conv_1")
        XCTAssertEqual(sut.bannerTitle, "First")
        
        // When: Showing another banner
        sut.showInAppBanner(conversationId: "conv_2", title: "Second", message: "Second message")
        
        // Then: Banner should be replaced with new one
        XCTAssertEqual(sut.bannerConversationId, "conv_2", "Banner should be replaced")
        XCTAssertEqual(sut.bannerTitle, "Second", "Banner title should be updated")
        XCTAssertEqual(sut.bannerMessage, "Second message", "Banner message should be updated")
    }
    
    // MARK: - Edge Cases
    
    /// Test that empty conversation ID is handled
    func testShouldSuppressNotification_WithEmptyConversationId_ReturnsFalse() {
        // Given: User is viewing a conversation
        sut.currentlyViewedConversationId = "test_123"
        
        // When: Checking suppression for empty conversation ID
        let shouldSuppress = sut.shouldSuppressNotification(for: "")
        
        // Then: Should not suppress (different from viewed conversation)
        XCTAssertFalse(shouldSuppress, "Empty conversation ID should not trigger suppression")
    }
    
    /// Test that long message text is handled in banner
    func testShowInAppBanner_WithLongMessage_DoesNotCrash() {
        // Given: A very long message
        let longMessage = String(repeating: "This is a very long message that should be handled properly. ", count: 10)
        
        // When: Showing banner with long message
        sut.showInAppBanner(conversationId: "test_123", title: "Test", message: longMessage)
        
        // Then: Should not crash and banner should be shown
        XCTAssertTrue(sut.showBanner, "Banner should be shown even with long message")
        XCTAssertEqual(sut.bannerMessage, longMessage, "Long message should be stored as-is")
    }
    
    /// Test that special characters in message are handled
    func testShowInAppBanner_WithSpecialCharacters_HandlesCorrectly() {
        // Given: Message with special characters and emojis
        let message = "Hello! 👋 How are you? 🎉 #MessageAI @user"
        
        // When: Showing banner with special characters
        sut.showInAppBanner(conversationId: "test_123", title: "Test User", message: message)
        
        // Then: Should handle special characters correctly
        XCTAssertTrue(sut.showBanner, "Banner should be shown")
        XCTAssertEqual(sut.bannerMessage, message, "Special characters should be preserved")
    }
    
    // MARK: - Current Viewed Conversation Tests
    
    /// Test that currentlyViewedConversationId can be set and cleared
    func testCurrentlyViewedConversationId_CanBeSetAndCleared() {
        // Given: Initial state
        XCTAssertNil(sut.currentlyViewedConversationId, "Should start as nil")
        
        // When: Setting conversation ID
        let conversationId = "test_123"
        sut.currentlyViewedConversationId = conversationId
        
        // Then: Should be set
        XCTAssertEqual(sut.currentlyViewedConversationId, conversationId)
        
        // When: Clearing conversation ID
        sut.currentlyViewedConversationId = nil
        
        // Then: Should be nil again
        XCTAssertNil(sut.currentlyViewedConversationId, "Should be cleared to nil")
    }
}

