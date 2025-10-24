//
//  DecisionService.swift
//  MessageAI
//
//  Service responsible for Decision CRUD operations and Firestore synchronization
//

import Foundation
import FirebaseFirestore
import OSLog

/// Service responsible for Decision CRUD operations and Firestore synchronization
@MainActor
class DecisionService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let decisionsCollection = "decisions"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "DecisionService")
    
    // MARK: - CRUD Methods
    
    /// Creates a new decision in Firestore
    /// - Parameter decision: Decision to create
    /// - Returns: Created decision
    /// - Throws: Error if creation fails
    func createDecision(_ decision: Decision) async throws -> Decision {
        logger.info("Creating decision: \(decision.decisionId)")
        
        do {
            let docRef = db.collection(decisionsCollection).document(decision.decisionId)
            let data = try Firestore.Encoder().encode(decision)
            try await docRef.setData(data)
            logger.info("Decision created successfully: \(decision.decisionId)")
            
            // Also store vector embedding in backend for semantic search
            try await storeDecisionVector(decision)
            
            return decision
            
        } catch {
            logger.error("Failed to create decision: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches a decision by ID
    /// - Parameter id: Decision ID
    /// - Returns: Decision if found, nil otherwise
    /// - Throws: Error if fetch fails
    func getDecision(id: String) async throws -> Decision? {
        logger.info("Fetching decision: \(id)")
        
        do {
            let docRef = db.collection(decisionsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Decision not found: \(id)")
                return nil
            }
            
            let decision = try snapshot.data(as: Decision.self)
            logger.info("Decision fetched successfully: \(id)")
            return decision
            
        } catch {
            logger.error("Failed to fetch decision: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists decisions for a user, optionally filtered by conversation
    /// - Parameters:
    ///   - userId: User ID to filter by
    ///   - conversationId: Optional conversation ID filter
    ///   - limit: Maximum number of results (default 50)
    /// - Returns: Array of decisions sorted by timestamp (newest first)
    /// - Throws: Error if fetch fails
    func listDecisions(userId: String, conversationId: String? = nil, limit: Int = 50) async throws -> [Decision] {
        logger.info("Listing decisions for user: \(userId)")
        
        do {
            var query: Query = db.collection(decisionsCollection)
                .whereField("userId", isEqualTo: userId)
            
            if let conversationId = conversationId {
                query = query.whereField("conversationId", isEqualTo: conversationId)
            }
            
            query = query.order(by: "timestamp", descending: true).limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            let decisions = try snapshot.documents.compactMap { try $0.data(as: Decision.self) }
            
            logger.info("Fetched \(decisions.count) decisions")
            return decisions
            
        } catch {
            logger.error("Failed to list decisions: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a decision
    /// - Parameter id: Decision ID
    /// - Throws: Error if deletion fails
    func deleteDecision(id: String) async throws {
        logger.info("Deleting decision: \(id)")
        
        do {
            let docRef = db.collection(decisionsCollection).document(id)
            try await docRef.delete()
            logger.info("Decision deleted successfully: \(id)")
            
            // Also delete vector embedding from backend
            try await deleteDecisionVector(id)
            
        } catch {
            logger.error("Failed to delete decision: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Vector Storage (Backend Integration)
    
    /// Store decision vector embedding in backend for semantic search
    private func storeDecisionVector(_ decision: Decision) async throws {
        guard let url = URL(string: "\(Config.backendURL)/api/v1/decisions/vector") else {
            logger.error("Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "decisionId": decision.decisionId,
            "text": decision.text,
            "userId": decision.userId,
            "conversationId": decision.conversationId,
            "messageId": decision.sourceMessageId,
            "timestamp": ISO8601DateFormatter().string(from: decision.timestamp)
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logger.warning("Failed to store decision vector in backend")
            // Don't throw - decision is already in Firestore
            return
        }
        
        logger.info("Decision vector stored in backend: \(decision.decisionId)")
    }
    
    /// Delete decision vector embedding from backend
    private func deleteDecisionVector(_ decisionId: String) async throws {
        guard let url = URL(string: "\(Config.backendURL)/api/v1/decisions/vector/\(decisionId)") else {
            logger.error("Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logger.warning("Failed to delete decision vector from backend")
            // Don't throw - decision is already deleted from Firestore
            return
        }
        
        logger.info("Decision vector deleted from backend: \(decisionId)")
    }
}
