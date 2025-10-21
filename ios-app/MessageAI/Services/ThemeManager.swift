//
//  ThemeManager.swift
//  MessageAI
//
//  Created by Dev Agent on 10/21/25.
//

import Combine
import SwiftUI

/// Service class that manages the app's theme preference
/// Persists user's theme selection to UserDefaults and provides the appropriate ColorScheme
class ThemeManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Current theme preference selected by the user
    @Published var currentTheme: ThemePreference = .system
    
    /// UserDefaults instance for persistence (can be injected for testing)
    private let userDefaults: UserDefaults
    
    /// Key used to store theme preference in UserDefaults
    private let userDefaultsKey = "userThemePreference"
    
    // MARK: - Initialization
    
    /// Initialize ThemeManager with optional UserDefaults instance
    /// - Parameter userDefaults: UserDefaults instance to use (defaults to .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadThemePreference()
    }
    
    // MARK: - Public Methods
    
    /// Loads the saved theme preference from UserDefaults
    /// If no saved preference exists, defaults to .system
    func loadThemePreference() {
        if let savedTheme = userDefaults.string(forKey: userDefaultsKey),
           let theme = ThemePreference(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            // Default to system theme if no saved preference
            currentTheme = .system
        }
    }
    
    /// Sets the theme preference and persists it to UserDefaults
    /// - Parameter theme: The theme preference to set
    func setTheme(_ theme: ThemePreference) {
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: userDefaultsKey)
    }
    
    // MARK: - Computed Properties
    
    /// Returns the ColorScheme to apply to the app based on current theme
    /// - Returns: nil for system (respects system setting), .light or .dark for forced themes
    var preferredColorScheme: ColorScheme? {
        switch currentTheme {
        case .system:
            return nil  // Respects system setting
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

