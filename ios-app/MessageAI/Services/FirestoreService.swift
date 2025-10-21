//
//  FirestoreService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import Combine
import FirebaseFirestore
import OSLog

/// Service responsible for Firestore database operations
@MainActor
final class FirestoreService: ObservableObject {
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "FirestoreService")
    
    // MARK: - User Profile Methods
    
    /// Creates a new user profile in Firestore
    /// - Parameters:
    ///   - userId: Unique user identifier (Firebase Auth UID)
    ///   - displayName: User's display name
    ///   - email: User's email address (optional)
    /// - Throws: FirestoreError if the operation fails
    func createUserProfile(userId: String, displayName: String, email: String?) async throws {
        logger.info("Creating user profile for userId: \(userId)")
        
        // Create User model
        let user = User(
            userId: userId,
            displayName: displayName,
            email: email,
            presence: .offline,
            lastSeen: Date()
        )
        
        // Convert to Firestore data
        let userData = user.toFirestoreData()
        
        do {
            // Write to Firestore users collection
            try await db.collection("users").document(userId).setData(userData)
            logger.info("User profile created successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to create user profile: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    /// Fetches a user profile from Firestore
    /// - Parameter userId: Unique user identifier
    /// - Returns: User model if found
    /// - Throws: FirestoreError if the operation fails
    func getUserProfile(userId: String) async throws -> User {
        logger.info("Fetching user profile for userId: \(userId)")
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard let user = User(document: document) else {
                logger.error("Failed to parse user document for userId: \(userId)")
                throw FirestoreError.invalidData
            }
            
            logger.info("User profile fetched successfully for userId: \(userId)")
            return user
            
        } catch {
            logger.error("Failed to fetch user profile: \(error.localizedDescription)")
            throw FirestoreError.readFailed(error.localizedDescription)
        }
    }
    
    /// Updates user presence status
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - presence: New presence status
    /// - Throws: FirestoreError if the operation fails
    func updateUserPresence(userId: String, presence: PresenceStatus) async throws {
        logger.info("Updating presence for userId: \(userId) to \(presence.rawValue)")
        
        let data: [String: Any] = [
            "presence": presence.rawValue,
            "lastSeen": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("users").document(userId).updateData(data)
            logger.info("Presence updated successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to update presence: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
    
    /// Updates user profile information
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - displayName: New display name (optional)
    ///   - email: New email (optional)
    /// - Throws: FirestoreError if the operation fails
    func updateUserProfile(userId: String, displayName: String? = nil, email: String? = nil) async throws {
        logger.info("Updating user profile for userId: \(userId)")
        
        var data: [String: Any] = [:]
        
        if let displayName = displayName {
            data["displayName"] = displayName
        }
        
        if let email = email {
            data["email"] = email
        }
        
        guard !data.isEmpty else {
            logger.warning("No data to update for userId: \(userId)")
            return
        }
        
        do {
            try await db.collection("users").document(userId).updateData(data)
            logger.info("User profile updated successfully for userId: \(userId)")
            
        } catch {
            logger.error("Failed to update user profile: \(error.localizedDescription)")
            throw FirestoreError.writeFailed(error.localizedDescription)
        }
    }
}

// MARK: - FirestoreError

/// Custom error type for Firestore operations
enum FirestoreError: LocalizedError {
    case writeFailed(String)
    case readFailed(String)
    case invalidData
    case documentNotFound
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .writeFailed(let message):
            return "Failed to write to database: \(message)"
        case .readFailed(let message):
            return "Failed to read from database: \(message)"
        case .invalidData:
            return "Invalid data format received from database."
        case .documentNotFound:
            return "The requested document was not found."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}

