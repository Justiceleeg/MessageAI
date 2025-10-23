//
//  DecisionService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
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
    
    /// Lists all decisions for a user
    /// - Parameter userId: User ID
    /// - Returns: Array of decisions
    /// - Throws: Error if fetch fails
    func listDecisions(userId: String) async throws -> [Decision] {
        logger.info("Listing decisions for user: \(userId)")
        
        do {
            let query = db.collection(decisionsCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
            
            let snapshot = try await query.getDocuments()
            let decisions = snapshot.documents.compactMap { try? $0.data(as: Decision.self) }
            
            logger.info("Fetched \(decisions.count) decisions for user: \(userId)")
            return decisions
            
        } catch {
            logger.error("Failed to list decisions: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all decisions for a conversation
    /// - Parameter conversationId: Conversation ID
    /// - Returns: Array of decisions
    /// - Throws: Error if fetch fails
    func listDecisionsForConversation(conversationId: String) async throws -> [Decision] {
        logger.info("Listing decisions for conversation: \(conversationId)")
        
        do {
            let query = db.collection(decisionsCollection)
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: true)
            
            let snapshot = try await query.getDocuments()
            let decisions = snapshot.documents.compactMap { try? $0.data(as: Decision.self) }
            
            logger.info("Fetched \(decisions.count) decisions for conversation: \(conversationId)")
            return decisions
            
        } catch {
            logger.error("Failed to list decisions for conversation: \(error.localizedDescription)")
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
            
        } catch {
            logger.error("Failed to delete decision: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Real-time Listeners
    
    /// Observes changes to a specific decision
    /// - Parameters:
    ///   - id: Decision ID
    ///   - onChange: Callback with updated decision or nil if deleted
    /// - Returns: ListenerRegistration to stop observing
    func observeDecision(id: String, onChange: @escaping (Decision?) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for decision: \(id)")
        
        let docRef = db.collection(decisionsCollection).document(id)
        
        return docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Decision listener error: \(error.localizedDescription)")
                onChange(nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                self.logger.info("Decision deleted or not found: \(id)")
                onChange(nil)
                return
            }
            
            do {
                let decision = try snapshot.data(as: Decision.self)
                self.logger.info("Decision updated via listener: \(id)")
                onChange(decision)
            } catch {
                self.logger.error("Failed to decode decision: \(error.localizedDescription)")
                onChange(nil)
            }
        }
    }
    
    /// Observes all decisions for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - onChange: Callback with array of decisions
    /// - Returns: ListenerRegistration to stop observing
    func observeUserDecisions(userId: String, onChange: @escaping ([Decision]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for user decisions: \(userId)")
        
        let query = db.collection(decisionsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("User decisions listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            let decisions = snapshot.documents.compactMap { try? $0.data(as: Decision.self) }
            self.logger.info("User decisions updated via listener: \(decisions.count) decisions")
            onChange(decisions)
        }
    }
    
    /// Observes all decisions for a conversation
    /// - Parameters:
    ///   - conversationId: Conversation ID
    ///   - onChange: Callback with array of decisions
    /// - Returns: ListenerRegistration to stop observing
    func observeConversationDecisions(conversationId: String, onChange: @escaping ([Decision]) -> Void) -> ListenerRegistration {
        logger.info("Starting real-time listener for conversation decisions: \(conversationId)")
        
        let query = db.collection(decisionsCollection)
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: true)
        
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Conversation decisions listener error: \(error.localizedDescription)")
                onChange([])
                return
            }
            
            guard let snapshot = snapshot else {
                onChange([])
                return
            }
            
            let decisions = snapshot.documents.compactMap { try? $0.data(as: Decision.self) }
            self.logger.info("Conversation decisions updated via listener: \(decisions.count) decisions")
            onChange(decisions)
        }
    }
}

