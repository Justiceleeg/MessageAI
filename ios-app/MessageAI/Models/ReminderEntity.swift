//
//  ReminderEntity.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/23/25.
//

import Foundation
import SwiftData

/// SwiftData entity for Reminder local persistence
@Model
class ReminderEntity {
    
    // MARK: - Properties
    
    @Attribute(.unique) var reminderId: String
    var userId: String
    var title: String
    var dueDate: Date
    var conversationId: String
    var sourceMessageId: String
    var completed: Bool
    var createdAt: Date
    var notificationId: String?
    
    // MARK: - Initialization
    
    init(
        reminderId: String,
        userId: String,
        title: String,
        dueDate: Date,
        conversationId: String,
        sourceMessageId: String,
        completed: Bool = false,
        createdAt: Date,
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

// MARK: - Reminder Conversion

extension ReminderEntity {
    /// Convert from Reminder model to ReminderEntity
    static func from(_ reminder: Reminder) -> ReminderEntity {
        return ReminderEntity(
            reminderId: reminder.reminderId,
            userId: reminder.userId,
            title: reminder.title,
            dueDate: reminder.dueDate,
            conversationId: reminder.conversationId,
            sourceMessageId: reminder.sourceMessageId,
            completed: reminder.completed,
            createdAt: reminder.createdAt,
            notificationId: reminder.notificationId
        )
    }
    
    /// Convert to Reminder model
    func toReminder() -> Reminder {
        return Reminder(
            reminderId: reminderId,
            userId: userId,
            title: title,
            dueDate: dueDate,
            conversationId: conversationId,
            sourceMessageId: sourceMessageId,
            completed: completed,
            createdAt: createdAt,
            notificationId: notificationId
        )
    }
}

