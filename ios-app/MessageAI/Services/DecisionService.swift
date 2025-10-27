//
//  DecisionService.swift
//  MessageAI
//
//  Service responsible for Decision CRUD operations and Firestore synchronization
//

import Foundation
import FirebaseFirestore
import OSLog
import SwiftData

/// Service responsible for Decision CRUD operations and Firestore synchronization
@MainActor
class DecisionService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let decisionsCollection = "decisions"
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "DecisionService")
    private let modelContext: ModelContext
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext ?? PersistenceController.shared.modelContainer.mainContext
    }
    
    // MARK: - SwiftData Cache Helpers
    
    /// Cache a decision to SwiftData
    private func cacheDecision(_ decision: Decision) async {
        do {
            // Check if already exists
            let predicate = #Predicate<DecisionEntity> { $0.decisionId == decision.decisionId }
            let descriptor = FetchDescriptor<DecisionEntity>(predicate: predicate)
            
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
            
            let decisionEntity = DecisionEntity.from(decision)
            modelContext.insert(decisionEntity)
            try modelContext.save()
            logger.debug("Decision cached to SwiftData: \(decision.decisionId)")
        } catch {
            logger.error("Failed to cache decision to SwiftData: \(error.localizedDescription)")
        }
    }
    
    /// Cache multiple decisions to SwiftData
    private func cacheDecisions(_ decisions: [Decision]) async {
        for decision in decisions {
            await cacheDecision(decision)
        }
    }
    
    /// Retrieve decision from SwiftData cache
    private func getDecisionFromCache(id: String) -> Decision? {
        do {
            let predicate = #Predicate<DecisionEntity> { $0.decisionId == id }
            let descriptor = FetchDescriptor<DecisionEntity>(predicate: predicate)
            
            if let cachedEntity = try modelContext.fetch(descriptor).first {
                return cachedEntity.toDecision()
            }
        } catch {
            logger.error("Failed to fetch decision from cache: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Retrieve decisions from SwiftData cache for a user
    private func getDecisionsFromCache(userId: String, conversationId: String? = nil, limit: Int = 50) -> [Decision] {
        do {
            let predicate: Predicate<DecisionEntity>
            if let conversationId = conversationId {
                predicate = #Predicate<DecisionEntity> { $0.userId == userId && $0.conversationId == conversationId }
            } else {
                predicate = #Predicate<DecisionEntity> { $0.userId == userId }
            }
            
            let descriptor = FetchDescriptor<DecisionEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let entities = try modelContext.fetch(descriptor)
            let decisions = entities.map { $0.toDecision() }
            return Array(decisions.prefix(limit))
        } catch {
            logger.error("Failed to fetch decisions from cache: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Delete decision from SwiftData cache
    private func deleteDecisionFromCache(id: String) {
        do {
            let predicate = #Predicate<DecisionEntity> { $0.decisionId == id }
            let descriptor = FetchDescriptor<DecisionEntity>(predicate: predicate)
            
            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
                logger.debug("Decision deleted from cache: \(id)")
            }
        } catch {
            logger.error("Failed to delete decision from cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD Methods
    
    /// Creates a new decision in Firestore
    /// - Parameter decision: Decision to create
    /// - Returns: Created decision
    /// - Throws: Error if creation fails
    func createDecision(_ decision: Decision) async throws -> Decision {
        logger.info("Creating decision: \(decision.decisionId)")
        
        do {
            // 1. Cache locally first for optimistic UI
            await cacheDecision(decision)
            
            // 2. Create decision in Firestore
            let docRef = db.collection(decisionsCollection).document(decision.decisionId)
            let data = try Firestore.Encoder().encode(decision)
            try await docRef.setData(data)
            logger.info("Decision created successfully: \(decision.decisionId)")
            
            // 3. Also store vector embedding in backend for semantic search
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
        
        // 1. Try local cache first
        if let cachedDecision = getDecisionFromCache(id: id) {
            logger.info("Decision found in cache: \(id)")
            
            // 2. Refresh from Firestore in background if online
            if networkMonitor.isConnected {
                Task {
                    await refreshDecisionFromFirestore(id: id)
                }
            }
            
            return cachedDecision
        }
        
        // 3. If not in cache, fetch from Firestore
        return try await fetchAndCacheDecision(id: id)
    }
    
    /// Fetch decision from Firestore and cache it
    private func fetchAndCacheDecision(id: String) async throws -> Decision? {
        do {
            let docRef = db.collection(decisionsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                logger.info("Decision not found: \(id)")
                return nil
            }
            
            let decision = try snapshot.data(as: Decision.self)
            logger.info("Decision fetched successfully: \(id)")
            
            // Cache the decision
            await cacheDecision(decision)
            
            return decision
            
        } catch {
            logger.error("Failed to fetch decision: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Refresh decision from Firestore silently (background operation)
    private func refreshDecisionFromFirestore(id: String) async {
        do {
            let docRef = db.collection(decisionsCollection).document(id)
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists, let decision = try? snapshot.data(as: Decision.self) {
                await cacheDecision(decision)
                logger.debug("Decision refreshed from Firestore: \(id)")
            }
        } catch {
            logger.debug("Failed to refresh decision from Firestore: \(error.localizedDescription)")
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
        
        // If offline, return cached decisions only
        if !networkMonitor.isConnected {
            logger.info("Offline mode - returning cached decisions for user: \(userId)")
            return getDecisionsFromCache(userId: userId, conversationId: conversationId, limit: limit)
        }
        
        // Online: fetch from Firestore and update cache
        do {
            var query: Query = db.collection(decisionsCollection)
                .whereField("userId", isEqualTo: userId)
            
            if let conversationId = conversationId {
                query = query.whereField("conversationId", isEqualTo: conversationId)
            }
            
            query = query.order(by: "timestamp", descending: true).limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            let decisions = try snapshot.documents.compactMap { try $0.data(as: Decision.self) }
            
            // Cache all fetched decisions
            await cacheDecisions(decisions)
            
            logger.info("Fetched \(decisions.count) decisions")
            return decisions
            
        } catch {
            logger.error("Failed to list decisions: \(error.localizedDescription)")
            // Fallback to cache on error
            logger.info("Falling back to cached decisions")
            return getDecisionsFromCache(userId: userId, conversationId: conversationId, limit: limit)
        }
    }
    
    /// Deletes a decision
    /// - Parameter id: Decision ID
    /// - Throws: Error if deletion fails
    func deleteDecision(id: String) async throws {
        logger.info("Deleting decision: \(id)")
        
        do {
            // 1. Delete from cache first
            deleteDecisionFromCache(id: id)
            
            // 2. Delete decision from Firestore
            let docRef = db.collection(decisionsCollection).document(id)
            try await docRef.delete()
            logger.info("Decision deleted successfully: \(id)")
            
            // 3. Also delete vector embedding from backend
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
