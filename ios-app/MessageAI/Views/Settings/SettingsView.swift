//
//  SettingsView.swift
//  MessageAI
//
//  Created by Dev Agent (James) on 10/21/25.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    
    // MARK: - View Model
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - State Properties
    
    @State private var showLogoutConfirmation: Bool = false
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var priorityNotificationsEnabled: Bool = false  // Story 5.3 AC5
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
                
                // Notifications Section (Story 3.4, 5.3)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(notificationStatusColor)
                            Text("Notification Status")
                            Spacer()
                            Text(notificationStatusText)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        
                        if notificationPermissionStatus == .denied {
                            Text("Enable notifications in Settings to receive alerts when you receive new messages.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                            
                            Button(action: openAppSettings) {
                                Label("Open Settings", systemImage: "gear")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Priority Notifications Toggle (Story 5.3 AC5)
                    Toggle(isOn: $priorityNotificationsEnabled) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Priority Notifications")
                        }
                    }
                    .onChange(of: priorityNotificationsEnabled) { _, newValue in
                        savePriorityNotificationSetting(newValue)
                    }
                    .accessibilityLabel("Priority Notifications")
                    .accessibilityHint("Enable special alerts for urgent messages")
                    
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationPermissionStatus != .denied {
                        Text("Priority Notifications will use a distinct alert style for urgent messages.\n\nIn-app banners will still show even if notifications are disabled.")
                            .font(.caption)
                    }
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
                    Task {
                        await handleLogout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                // Check notification permission status (Story 3.4)
                checkNotificationPermissionStatus()
                // Load priority notification setting (Story 5.3 AC5)
                loadPriorityNotificationSetting()
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLogout() async {
        await authViewModel.signOut()
        dismiss()
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
    
    /// Check the current notification permission status (Story 3.4)
    private func checkNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    /// Get the notification status text based on permission status (Story 3.4)
    private var notificationStatusText: String {
        switch notificationPermissionStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Get the color for notification status indicator (Story 3.4)
    private var notificationStatusColor: Color {
        switch notificationPermissionStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        default:
            return .gray
        }
    }
    
    /// Open iOS Settings app to notification settings (Story 3.4)
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Load priority notification setting from UserDefaults (Story 5.3 AC5)
    private func loadPriorityNotificationSetting() {
        priorityNotificationsEnabled = UserDefaults.standard.bool(forKey: "priorityNotificationsEnabled")
    }
    
    /// Save priority notification setting to UserDefaults (Story 5.3 AC5)
    private func savePriorityNotificationSetting(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "priorityNotificationsEnabled")
        print("📱 Priority notifications \(enabled ? "enabled" : "disabled")")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
}

