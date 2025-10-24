//
//  DecisionsListView.swift
//  MessageAI
//
//  Decisions list view for Story 5.2 (Per-chat and Global)
//

import SwiftUI

/// List view for displaying decisions - can be filtered by conversation
struct DecisionsListView: View {
    
    // MARK: - Properties
    
    let conversationId: String?  // nil for global view
    
    @State private var decisions: [Decision] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    private let decisionService = DecisionService()
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading decisions...")
            } else if decisions.isEmpty {
                emptyStateView
            } else {
                decisionsList
            }
        }
        .navigationTitle(conversationId == nil ? "All Decisions" : "Chat Decisions")
        .searchable(text: $searchText, prompt: "Search decisions")
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                Task {
                    await searchDecisions(query: newValue)
                }
            } else {
                Task {
                    await loadDecisions()
                }
            }
        }
        .task {
            await loadDecisions()
        }
        .refreshable {
            await loadDecisions()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No decisions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Decisions you save from messages will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Decisions List
    
    private var decisionsList: some View {
        List {
            ForEach(filteredDecisions) { decision in
                DecisionRowView(decision: decision, conversationId: conversationId)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var filteredDecisions: [Decision] {
        guard !searchText.isEmpty else { return decisions }
        return decisions.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Load Decisions
    
    private func loadDecisions() async {
        guard let userId = AuthService.shared.currentUser?.userId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Debug logging
        if let conversationId = conversationId {
            print("📋 Loading per-chat decisions for conversation: \(conversationId)")
        } else {
            print("📋 Loading global decisions for user: \(userId)")
        }
        
        do {
            let fetchedDecisions = try await decisionService.listDecisions(
                userId: userId,
                conversationId: conversationId
            )
            
            print("✅ Fetched \(fetchedDecisions.count) decisions")
            
            await MainActor.run {
                decisions = fetchedDecisions
                isLoading = false
            }
        } catch {
            print("❌ Error loading decisions: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Search Decisions
    
    private func searchDecisions(query: String) async {
        guard let userId = AuthService.shared.currentUser?.userId else {
            return
        }
        
        isLoading = true
        
        do {
            let response = try await AIBackendService.shared.searchDecisions(
                userId: userId,
                query: query,
                conversationId: conversationId
            )
            
            await MainActor.run {
                // Convert search results to Decision objects
                decisions = response.results.compactMap { result in
                    // Try to parse timestamp
                    guard let timestamp = ISO8601DateFormatter().date(from: result.timestamp) else {
                        return nil
                    }
                    
                    return Decision(
                        decisionId: result.decisionId,
                        userId: userId,
                        text: result.text,
                        conversationId: result.conversationId,
                        sourceMessageId: result.messageId,
                        timestamp: timestamp
                    )
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Decision Row View

struct DecisionRowView: View {
    let decision: Decision
    let conversationId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decision.text)
                .font(.body)
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatTimestamp(decision.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show "Go to message" button (Story 5.1.5 deferred)
                Button(action: {
                    // TODO: Navigate to message (Story 5.1.5)
                    print("📍 Navigate to message: \(decision.sourceMessageId) in conversation: \(decision.conversationId)")
                    // This will be implemented in Story 5.1.5
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.caption2)
                        Text("Go to message")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                .disabled(true)  // Disabled until Story 5.1.5
                .opacity(0.5)    // Visual feedback that it's disabled
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview("Global Decisions") {
    NavigationStack {
        DecisionsListView(conversationId: nil)
    }
}

#Preview("Per-Chat Decisions") {
    NavigationStack {
        DecisionsListView(conversationId: "conv_123")
    }
}

