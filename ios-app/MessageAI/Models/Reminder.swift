//
//  Reminder.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation

/// Reminder model matching Firestore schema
struct Reminder: Identifiable, Codable, Hashable {
    
    // MARK: - Properties
    
    /// Unique identifier
    var id: String { reminderId }
    
    let reminderId: String
    let userId: String
    let title: String
    let dueDate: Date
    let conversationId: String
    let sourceMessageId: String
    var completed: Bool
    let createdAt: Date
    var notificationId: String?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case reminderId
        case userId
        case title
        case dueDate
        case conversationId
        case sourceMessageId
        case completed
        case createdAt
        case notificationId
    }
    
    // MARK: - Initialization
    
    init(
        reminderId: String = UUID().uuidString,
        userId: String,
        title: String,
        dueDate: Date,
        conversationId: String,
        sourceMessageId: String,
        completed: Bool = false,
        createdAt: Date = Date(),
        notificationId: String? = nil
    ) {
        self.reminderId = reminderId
        self.userId = userId
        self.title = title
        self.dueDate = dueDate
        self.conversationId = conversationId
        self.sourceMessageId = sourceMessageId
        self.completed = completed
        self.createdAt = createdAt
        self.notificationId = notificationId
    }
}

