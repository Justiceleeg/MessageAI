//
//  ConversationListView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct ConversationListView: View {
    
    // MARK: - Environment & State
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: ConversationListViewModel
    @State private var showSettings: Bool = false
    @State private var showNewMessage: Bool = false
    @State private var showNewGroupChat: Bool = false
    
    // Store service references for UserSearchView
    private let firestoreService: FirestoreService
    private let authService: AuthService
    
    // MARK: - Initialization
    
    init(firestoreService: FirestoreService, authService: AuthService) {
        self.firestoreService = firestoreService
        self.authService = authService
        _viewModel = StateObject(wrappedValue: ConversationListViewModel(
            firestoreService: firestoreService,
            authService: authService,
            modelContext: nil // Will be set via environment
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    // Loading state
                    loadingView
                } else if viewModel.conversations.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Conversation list
                    conversationListView
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open settings and account options")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showNewMessage = true
                        }) {
                            Label("New Message", systemImage: "bubble.left")
                        }
                        
                        Button(action: {
                            showNewGroupChat = true
                        }) {
                            Label("New Group Chat", systemImage: "person.3.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel("New conversation menu")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.preferredColorScheme)
            }
            .sheet(isPresented: $showNewMessage) {
                UserSearchView(
                    firestoreService: firestoreService,
                    authService: authService,
                    isGroupMode: false
                )
            }
            .sheet(isPresented: $showNewGroupChat) {
                UserSearchView(
                    firestoreService: firestoreService,
                    authService: authService,
                    isGroupMode: true
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
            .onAppear {
                // Set the model context now that we have environment access
                viewModel.setModelContext(modelContext)
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Loading spinner view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Empty state view when no conversations exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation to see it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    /// Main conversation list view
    private var conversationListView: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: chatDestination(for: conversation)) {
                ConversationRow(
                    conversation: conversation,
                    displayName: viewModel.getOtherParticipantName(for: conversation),
                    currentUserId: authViewModel.authService.currentUser?.userId ?? ""
                )
            }
            .listRowSeparator(.visible)
            .accessibilityLabel(conversationAccessibilityLabel(for: conversation))
            .accessibilityHint("Tap to open conversation")
        }
        .listStyle(.plain)
    }
    
    /// Generate chat destination for navigation
    private func chatDestination(for conversation: Conversation) -> some View {
        let otherUserId = viewModel.getOtherParticipantId(for: conversation)
        return ChatView(
            conversationId: conversation.conversationId,
            otherUserId: otherUserId
        )
    }
    
    /// Generate accessibility label for conversation row
    private func conversationAccessibilityLabel(for conversation: Conversation) -> String {
        let displayName = viewModel.getOtherParticipantName(for: conversation)
        let preview = conversation.lastMessageText ?? "No messages yet"
        let timestamp = DateFormatters.shared.formatConversationTimestamp(conversation.lastMessageTimestamp)
        return "Conversation with \(displayName), last message: \(preview), \(timestamp)"
    }
}

// MARK: - Conversation Row

/// Individual conversation row in the list
struct ConversationRow: View {
    let conversation: Conversation
    let displayName: String
    let currentUserId: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar (group icon for groups, initials for 1:1)
            avatar
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Display name (with group icon if group chat)
                    HStack(spacing: 6) {
                        if conversation.isGroupChat {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                        
                        Text(displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(DateFormatters.shared.formatConversationTimestamp(conversation.lastMessageTimestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                // Message preview (with sender name prefix for groups)
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Avatar circle with initials or group icon
    private var avatar: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 50, height: 50)
            .overlay(
                Group {
                    if conversation.isGroupChat {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(avatarInitials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            )
    }
    
    /// Get initials from display name
    private var avatarInitials: String {
        let words = displayName.split(separator: " ")
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
    
    /// Generate avatar color based on conversation ID
    private var avatarColor: Color {
        // Generate consistent color based on conversation ID
        let hash = abs(conversation.conversationId.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .indigo, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Preview

#Preview {
    let authService = AuthService(firestoreService: FirestoreService())
    let firestoreService = FirestoreService()
    
    ConversationListView(
        firestoreService: firestoreService,
        authService: authService
    )
    .environmentObject(AuthViewModel())
    .environmentObject(ThemeManager())
    .modelContainer(PersistenceController.preview.modelContainer)
}

