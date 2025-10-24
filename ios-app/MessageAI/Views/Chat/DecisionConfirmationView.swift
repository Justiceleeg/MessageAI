//
//  DecisionConfirmationView.swift
//  MessageAI
//
//  Decision confirmation modal for Story 5.2
//

import SwiftUI

/// Modal for confirming and saving decisions detected in messages
struct DecisionConfirmationView: View {
    
    // MARK: - Properties
    
    let initialData: DecisionDetection
    let messageId: String
    let conversationId: String
    let onSave: (Decision) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var decisionText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // MARK: - Initialization
    
    init(
        initialData: DecisionDetection,
        messageId: String,
        conversationId: String,
        onSave: @escaping (Decision) -> Void
    ) {
        self.initialData = initialData
        self.messageId = messageId
        self.conversationId = conversationId
        self.onSave = onSave
        
        // Initialize state with detected decision text
        _decisionText = State(initialValue: initialData.text ?? "")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Decision Details")) {
                    TextEditor(text: $decisionText)
                        .frame(minHeight: 100)
                        .padding(.vertical, 8)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Confirm Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveDecision()
                        }
                    }
                    .disabled(isSaving || decisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    // MARK: - Save Decision
    
    private func saveDecision() async {
        guard let userId = AuthService.shared.currentUser?.userId else {
            errorMessage = "User not authenticated"
            return
        }
        
        let trimmedText = decisionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = "Decision text cannot be empty"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // Create decision object
            let newDecision = Decision(
                userId: userId,
                text: trimmedText,
                conversationId: conversationId,
                sourceMessageId: messageId,
                timestamp: Date()
            )
            
            // Save to Firestore (DecisionService also stores vector in backend)
            let decisionService = DecisionService()
            let savedDecision = try await decisionService.createDecision(newDecision)
            
            // Call completion handler
            await MainActor.run {
                onSave(savedDecision)
                dismiss()
            }
            
        } catch {
            errorMessage = "Failed to save decision: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

// MARK: - Previews

#Preview("Decision Confirmation") {
    DecisionConfirmationView(
        initialData: DecisionDetection(
            detected: true,
            text: "Going to Luigi's Italian restaurant on Main Street"
        ),
        messageId: "msg_123",
        conversationId: "conv_456"
    ) { decision in
        print("Decision saved: \(decision.text)")
    }
}

