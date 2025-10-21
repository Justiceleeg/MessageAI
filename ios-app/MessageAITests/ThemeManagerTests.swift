//
//  ThemeManagerTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 10/21/25.
//

import XCTest
import SwiftUI
@testable import MessageAI

@MainActor
final class ThemeManagerTests: XCTestCase {
    
    var themeManager: ThemeManager!
    var mockDefaults: UserDefaults!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        // Use separate UserDefaults suite for testing to avoid affecting real app data
        mockDefaults = UserDefaults(suiteName: "TestDefaults")!
        mockDefaults.removePersistentDomain(forName: "TestDefaults")
        themeManager = ThemeManager(userDefaults: mockDefaults)
    }
    
    override func tearDown() async throws {
        mockDefaults.removePersistentDomain(forName: "TestDefaults")
        mockDefaults = nil
        themeManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Default Theme Tests
    
    func testDefaultTheme_IsSystem() {
        // Assert: Default theme should be system
        XCTAssertEqual(themeManager.currentTheme, .system, "Default theme should be .system")
    }
    
    func testPreferredColorScheme_DefaultTheme_ReturnsNil() {
        // Assert: Default (system) theme should return nil to respect system setting
        XCTAssertNil(themeManager.preferredColorScheme, "System theme should return nil for preferredColorScheme")
    }
    
    // MARK: - Set Theme Tests
    
    func testSetTheme_Light_UpdatesCurrentTheme() {
        // Act: Set theme to light
        themeManager.setTheme(.light)
        
        // Assert: Current theme should be light
        XCTAssertEqual(themeManager.currentTheme, .light, "Current theme should be .light after setting")
    }
    
    func testSetTheme_Light_PersistsToUserDefaults() {
        // Act: Set theme to light
        themeManager.setTheme(.light)
        
        // Assert: Theme should be persisted to UserDefaults
        let savedTheme = mockDefaults.string(forKey: "userThemePreference")
        XCTAssertEqual(savedTheme, "light", "Light theme should be persisted to UserDefaults")
    }
    
    func testSetTheme_Dark_UpdatesCurrentTheme() {
        // Act: Set theme to dark
        themeManager.setTheme(.dark)
        
        // Assert: Current theme should be dark
        XCTAssertEqual(themeManager.currentTheme, .dark, "Current theme should be .dark after setting")
    }
    
    func testSetTheme_Dark_PersistsToUserDefaults() {
        // Act: Set theme to dark
        themeManager.setTheme(.dark)
        
        // Assert: Theme should be persisted to UserDefaults
        let savedTheme = mockDefaults.string(forKey: "userThemePreference")
        XCTAssertEqual(savedTheme, "dark", "Dark theme should be persisted to UserDefaults")
    }
    
    func testSetTheme_System_UpdatesCurrentTheme() {
        // Arrange: Set theme to light first
        themeManager.setTheme(.light)
        
        // Act: Set theme back to system
        themeManager.setTheme(.system)
        
        // Assert: Current theme should be system
        XCTAssertEqual(themeManager.currentTheme, .system, "Current theme should be .system after setting")
    }
    
    func testSetTheme_System_PersistsToUserDefaults() {
        // Arrange: Set theme to light first
        themeManager.setTheme(.light)
        
        // Act: Set theme back to system
        themeManager.setTheme(.system)
        
        // Assert: Theme should be persisted to UserDefaults
        let savedTheme = mockDefaults.string(forKey: "userThemePreference")
        XCTAssertEqual(savedTheme, "system", "System theme should be persisted to UserDefaults")
    }
    
    // MARK: - Load Theme Tests
    
    func testLoadThemePreference_WhenNoSavedValue_DefaultsToSystem() {
        // Act: Load theme when nothing is saved
        themeManager.loadThemePreference()
        
        // Assert: Should default to system
        XCTAssertEqual(themeManager.currentTheme, .system, "Should default to .system when no saved value")
    }
    
    func testLoadThemePreference_WithSavedLight_LoadsLightTheme() {
        // Arrange: Save light theme to UserDefaults
        mockDefaults.set("light", forKey: "userThemePreference")
        
        // Act: Load theme preference
        themeManager.loadThemePreference()
        
        // Assert: Should load light theme
        XCTAssertEqual(themeManager.currentTheme, .light, "Should load .light from UserDefaults")
    }
    
    func testLoadThemePreference_WithSavedDark_LoadsDarkTheme() {
        // Arrange: Save dark theme to UserDefaults
        mockDefaults.set("dark", forKey: "userThemePreference")
        
        // Act: Load theme preference
        themeManager.loadThemePreference()
        
        // Assert: Should load dark theme
        XCTAssertEqual(themeManager.currentTheme, .dark, "Should load .dark from UserDefaults")
    }
    
    func testLoadThemePreference_WithInvalidValue_DefaultsToSystem() {
        // Arrange: Save invalid theme value to UserDefaults
        mockDefaults.set("invalid_theme", forKey: "userThemePreference")
        
        // Act: Load theme preference
        themeManager.loadThemePreference()
        
        // Assert: Should default to system
        XCTAssertEqual(themeManager.currentTheme, .system, "Should default to .system with invalid saved value")
    }
    
    // MARK: - Preferred ColorScheme Tests
    
    func testPreferredColorScheme_SystemTheme_ReturnsNil() {
        // Arrange: Set theme to system
        themeManager.setTheme(.system)
        
        // Act: Get preferred color scheme
        let colorScheme = themeManager.preferredColorScheme
        
        // Assert: Should return nil to respect system setting
        XCTAssertNil(colorScheme, "System theme should return nil for preferredColorScheme")
    }
    
    func testPreferredColorScheme_LightTheme_ReturnsLight() {
        // Arrange: Set theme to light
        themeManager.setTheme(.light)
        
        // Act: Get preferred color scheme
        let colorScheme = themeManager.preferredColorScheme
        
        // Assert: Should return .light
        XCTAssertEqual(colorScheme, .light, "Light theme should return .light for preferredColorScheme")
    }
    
    func testPreferredColorScheme_DarkTheme_ReturnsDark() {
        // Arrange: Set theme to dark
        themeManager.setTheme(.dark)
        
        // Act: Get preferred color scheme
        let colorScheme = themeManager.preferredColorScheme
        
        // Assert: Should return .dark
        XCTAssertEqual(colorScheme, .dark, "Dark theme should return .dark for preferredColorScheme")
    }
    
    // MARK: - Persistence Integration Tests
    
    func testThemePersistence_AcrossInstances() async {
        // Arrange: Set theme to light
        themeManager.setTheme(.light)
        
        // Flush UserDefaults to ensure write completes
        mockDefaults.synchronize()
        
        // Small delay to ensure persistence completes
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Act: Create new ThemeManager instance with same UserDefaults
        let newThemeManager = ThemeManager(userDefaults: mockDefaults)
        
        // Assert: New instance should load the saved theme
        XCTAssertEqual(newThemeManager.currentTheme, .light, "New ThemeManager instance should load saved theme")
    }
    
    func testThemePersistence_MultipleChanges() {
        // Act: Change theme multiple times
        themeManager.setTheme(.light)
        themeManager.setTheme(.dark)
        themeManager.setTheme(.system)
        
        // Assert: Final theme should be persisted
        let savedTheme = mockDefaults.string(forKey: "userThemePreference")
        XCTAssertEqual(savedTheme, "system", "Final theme change should be persisted")
        XCTAssertEqual(themeManager.currentTheme, .system, "Current theme should match final change")
    }
}

