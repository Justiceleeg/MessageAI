//
//  UserSearchView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/21/25.
//

import SwiftUI

/// View for searching and selecting users to start a new conversation (Story 2.0)
struct UserSearchView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UserSearchViewModel
    
    // Navigation state
    @State private var selectedConversationId: String?
    @State private var selectedOtherUserId: String?
    @State private var navigateToChat: Bool = false
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService) {
        _viewModel = StateObject(wrappedValue: UserSearchViewModel(
            firestoreService: firestoreService,
            authService: authService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                contentView
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let otherUserId = selectedOtherUserId {
                    ChatView(
                        conversationId: selectedConversationId,
                        otherUserId: otherUserId
                    )
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Search bar at the top
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search by name or email", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel("Search field")
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Main content view (shows different states)
    private var contentView: some View {
        Group {
            if viewModel.isSearching {
                loadingView
            } else if viewModel.searchQuery.isEmpty {
                emptyStateView
            } else if viewModel.searchResults.isEmpty {
                noResultsView
            } else {
                searchResultsList
            }
        }
    }
    
    /// Loading indicator
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Empty state (before user starts searching)
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.gray)
            
            Text("Search for users by name or email")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// No results state
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.gray)
            
            Text("No users found")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            
            Text("Try a different search")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Search results list
    private var searchResultsList: some View {
        List(viewModel.searchResults) { user in
            Button(action: {
                handleUserSelection(user)
            }) {
                UserSearchRow(user: user)
            }
            .listRowSeparator(.visible)
            .accessibilityLabel("User: \(user.displayName)\(user.email != nil ? ", \(user.email!)" : "")")
            .accessibilityHint("Select user to message")
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    /// Handle user selection from search results
    private func handleUserSelection(_ user: User) {
        Task {
            do {
                // Check if conversation exists
                let result = try await viewModel.selectUser(user)
                
                // Set navigation parameters
                selectedConversationId = result.conversationId
                selectedOtherUserId = result.otherUserId
                
                // Navigate to chat within the modal
                navigateToChat = true
                
            } catch {
                // Error is handled by the ViewModel and displayed via alert
            }
        }
    }
}

// MARK: - User Search Row

/// Individual user row in search results
struct UserSearchRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatar
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let email = user.email {
                    Text(email)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    /// Avatar circle with initials
    private var avatar: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 40, height: 40)
            .overlay(
                Text(avatarInitials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
    
    /// Get initials from display name
    private var avatarInitials: String {
        let words = user.displayName.split(separator: " ")
        if words.isEmpty {
            return "?"
        } else if words.count == 1 {
            return String(words[0].prefix(1)).uppercased()
        } else {
            let first = words[0].prefix(1)
            let last = words[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
    }
    
    /// Generate avatar color based on user ID
    private var avatarColor: Color {
        let hash = abs(user.userId.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Preview

#Preview {
    let firestoreService = FirestoreService()
    let authService = AuthService(firestoreService: firestoreService)
    
    UserSearchView(
        firestoreService: firestoreService,
        authService: authService
    )
}

