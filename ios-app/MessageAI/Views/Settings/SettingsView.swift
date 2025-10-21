//
//  SettingsView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//

import SwiftUI

struct SettingsView: View {
    
    // MARK: - View Model
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - State Properties
    
    @State private var showLogoutConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section("Appearance") {
                    NavigationLink(destination: ThemeSelectionView()) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(.blue)
                            Text("Theme")
                            Spacer()
                            Text(themeDisplayName(themeManager.currentTheme))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Theme")
                    .accessibilityHint("Change the app's appearance")
                    .accessibilityValue(themeDisplayName(themeManager.currentTheme))
                }
                
                // Account Section
                Section("Account") {
                    // Logout Button
                    Button(role: .destructive, action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundStyle(.red)
                            Text("Logout")
                        }
                    }
                    .accessibilityLabel("Logout")
                    .accessibilityHint("Sign out of your account")
                }
                
                // App Information Section
                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version 1.0.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Are you sure you want to log out?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    handleLogout()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLogout() {
        Task {
            await authViewModel.signOut()
            dismiss()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns a display-friendly name for a theme preference
    /// - Parameter theme: The theme preference
    /// - Returns: A readable string representation of the theme
    private func themeDisplayName(_ theme: ThemePreference) -> String {
        switch theme {
        case .system:
            return "System Default"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
}

