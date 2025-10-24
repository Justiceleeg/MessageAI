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
    
    // Group chat state
    @State private var isGroupMode: Bool = false
    @State private var selectedUsers: [User] = []
    @State private var showGroupNameEntry: Bool = false
    @State private var pendingGroupName: String?
    @State private var pendingGroupParticipants: [User] = []
    @State private var isCreatingGroup: Bool = false
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService, isGroupMode: Bool = false) {
        _viewModel = StateObject(wrappedValue: UserSearchViewModel(
            firestoreService: firestoreService,
            authService: authService
        ))
        _isGroupMode = State(initialValue: isGroupMode)
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
            .navigationTitle(isGroupMode ? "New Group" : "New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Show Next button in group mode when 2+ users selected
                if isGroupMode && selectedUsers.count >= 2 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Next") {
                            showGroupNameEntry = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if !pendingGroupParticipants.isEmpty {
                    // Group chat navigation (lazy creation)
                    ChatView(
                        conversationId: nil,
                        otherUserId: "", // Not used for groups
                        groupParticipants: pendingGroupParticipants,
                        groupName: pendingGroupName
                    )
                } else if let otherUserId = selectedOtherUserId {
                    // 1:1 chat navigation
                    ChatView(
                        conversationId: selectedConversationId,
                        otherUserId: otherUserId
                    )
                }
            }
            .sheet(isPresented: $showGroupNameEntry) {
                GroupNameEntryView(
                    selectedUsers: selectedUsers,
                    onCreateGroup: { name in
                        createGroupChat(withName: name)
                    }
                )
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
                HStack {
                    UserSearchRow(user: user)
                    
                    // Show checkmark in group mode if user is selected
                    if isGroupMode && selectedUsers.contains(where: { $0.userId == user.userId }) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 24))
                    }
                }
            }
            .listRowSeparator(.visible)
            .accessibilityLabel("User: \(user.displayName)\(user.email != nil ? ", \(user.email!)" : "")")
            .accessibilityHint(isGroupMode ? "Tap to select for group" : "Select user to message")
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    /// Handle user selection from search results
    private func handleUserSelection(_ user: User) {
        if isGroupMode {
            // Group mode: Toggle selection
            toggleUserSelection(user)
        } else {
            // 1:1 mode: Navigate to chat
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
    
    /// Toggle user selection in group mode
    private func toggleUserSelection(_ user: User) {
        if let index = selectedUsers.firstIndex(where: { $0.userId == user.userId }) {
            // User already selected, remove them
            selectedUsers.remove(at: index)
        } else {
            // User not selected, add them
            selectedUsers.append(user)
        }
    }
    
    /// Prepare to navigate to group chat (lazy creation - no Firestore write yet)
    private func createGroupChat(withName name: String?) {
        guard selectedUsers.count >= 2 else {
            viewModel.errorMessage = "Please select at least 2 other users to create a group chat."
            return
        }
        
        // Store group data for lazy creation
        pendingGroupName = name?.isEmpty == false ? name : nil
        pendingGroupParticipants = selectedUsers
        
        // Clear 1:1 chat state
        selectedConversationId = nil
        selectedOtherUserId = nil
        
        // Close the group name entry sheet
        showGroupNameEntry = false
        
        // Navigate to chat view (will create conversation on first message)
        navigateToChat = true
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

// MARK: - Group Name Entry View

/// Sheet for entering optional group name
struct GroupNameEntryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedUsers: [User]
    let onCreateGroup: (String?) -> Void
    
    @State private var groupName: String = ""
    @State private var validationError: String?
    @FocusState private var isTextFieldFocused: Bool
    
    // Maximum group name length
    private let maxNameLength = 50
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Selected users preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Participants")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(formatParticipantNames())
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Group name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name (Optional)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onChange(of: groupName) { _, newValue in
                            // Validate on change
                            validateGroupName(newValue)
                            
                            // Enforce max length
                            if newValue.count > maxNameLength {
                                groupName = String(newValue.prefix(maxNameLength))
                            }
                        }
                        .onSubmit {
                            createGroup()
                        }
                    
                    // Character count and validation feedback
                    HStack {
                        if let error = validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if !groupName.isEmpty {
                            Text("\(groupName.count)/\(maxNameLength)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(validationError != nil)
                }
            }
            .onAppear {
                // Auto-focus text field after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private func validateGroupName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset validation error
        validationError = nil
        
        // Empty is allowed (optional field)
        guard !trimmed.isEmpty else {
            return
        }
        
        // Firebase doesn't allow these characters: . # $ [ ]
        let forbiddenCharacters = CharacterSet(charactersIn: ".#$[]")
        if trimmed.unicodeScalars.contains(where: { forbiddenCharacters.contains($0) }) {
            validationError = "Cannot use . # $ [ ] characters"
            return
        }
        
        // Check minimum length if not empty
        if trimmed.count < 2 {
            validationError = "Group name must be at least 2 characters"
            return
        }
    }
    
    private func formatParticipantNames() -> String {
        let names = selectedUsers.map { $0.displayName }
        if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let shown = names.prefix(3).joined(separator: ", ")
            return "\(shown), +\(names.count - 3) more"
        }
    }
    
    private func createGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreateGroup(trimmedName.isEmpty ? nil : trimmedName)
        dismiss()
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

