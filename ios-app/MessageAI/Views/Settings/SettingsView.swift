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
    
    // MARK: - State Properties
    
    @State private var showLogoutConfirmation: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
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
        authViewModel.signOut()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}

