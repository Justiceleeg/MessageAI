//
//  UserEntity.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import SwiftData

/// SwiftData entity for local user caching
@Model
final class UserEntity {
    
    // MARK: - Properties
    
    /// Unique user identifier (matches Firebase Auth UID)
    @Attribute(.unique) var userId: String
    
    /// User's display name
    var displayName: String
    
    /// User's email address (optional)
    var email: String?
    
    /// User's presence status ("online" or "offline")
    var presence: String
    
    /// Last time user was active
    var lastSeen: Date
    
    // MARK: - Initialization
    
    init(userId: String, displayName: String, email: String? = nil, presence: String = "offline", lastSeen: Date = Date()) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.presence = presence
        self.lastSeen = lastSeen
    }
    
    // MARK: - Conversion Methods
    
    /// Convert to User model
    func toUser() -> User {
        return User(
            userId: userId,
            displayName: displayName,
            email: email,
            presence: PresenceStatus(rawValue: presence) ?? .offline,
            lastSeen: lastSeen
        )
    }
    
    /// Create UserEntity from User model
    static func from(user: User) -> UserEntity {
        return UserEntity(
            userId: user.userId,
            displayName: user.displayName,
            email: user.email,
            presence: user.presence.rawValue,
            lastSeen: user.lastSeen
        )
    }
    
    /// Update entity from User model
    func update(from user: User) {
        self.displayName = user.displayName
        self.email = user.email
        self.presence = user.presence.rawValue
        self.lastSeen = user.lastSeen
    }
}

