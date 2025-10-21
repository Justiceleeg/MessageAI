//
//  User.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// User model matching Firestore schema
struct User: Codable, Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier matching Firebase Auth UID
    var id: String { userId }
    
    /// User's unique identifier (matches Firebase Auth UID)
    let userId: String
    
    /// User's display name
    var displayName: String
    
    /// User's email address (optional)
    var email: String?
    
    /// User's presence status
    var presence: PresenceStatus
    
    /// Last time user was active
    var lastSeen: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case userId
        case displayName
        case email
        case presence
        case lastSeen
    }
    
    // MARK: - Initialization
    
    init(userId: String, displayName: String, email: String? = nil, presence: PresenceStatus = .offline, lastSeen: Date = Date()) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.presence = presence
        self.lastSeen = lastSeen
    }
    
    // MARK: - Firestore Conversion
    
    /// Initialize from Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let displayName = data["displayName"] as? String,
              let presenceString = data["presence"] as? String,
              let presence = PresenceStatus(rawValue: presenceString),
              let lastSeenTimestamp = data["lastSeen"] as? Timestamp else {
            return nil
        }
        
        self.userId = userId
        self.displayName = displayName
        self.email = data["email"] as? String
        self.presence = presence
        self.lastSeen = lastSeenTimestamp.dateValue()
    }
    
    /// Convert to Firestore dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "displayName": displayName,
            "presence": presence.rawValue,
            "lastSeen": Timestamp(date: lastSeen)
        ]
        
        if let email = email {
            data["email"] = email
        }
        
        return data
    }
}

// MARK: - Presence Status

/// User presence status enum
enum PresenceStatus: String, Codable {
    case online
    case offline
}

// MARK: - Extensions

extension User {
    /// Create User from Firebase Auth User
    static func from(firebaseUser: FirebaseAuth.User, displayName: String) -> User {
        return User(
            userId: firebaseUser.uid,
            displayName: displayName,
            email: firebaseUser.email,
            presence: .offline,
            lastSeen: Date()
        )
    }
}


