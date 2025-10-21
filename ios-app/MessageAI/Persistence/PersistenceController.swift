//
//  PersistenceController.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import OSLog
import SwiftData

/// Controller responsible for managing SwiftData persistence
@MainActor
final class PersistenceController {

    // MARK: - Singleton

    static let shared = PersistenceController()

    // MARK: - Properties

    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "PersistenceController")

    // MARK: - Initialization

    private init() {
        do {
            // Configure the model container with UserEntity, ConversationEntity, and MessageEntity
            let schema = Schema([
                UserEntity.self,
                ConversationEntity.self,
                MessageEntity.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            logger.info("SwiftData ModelContainer initialized successfully")

        } catch {
            logger.error("Failed to initialize ModelContainer: \(error.localizedDescription)")
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    // MARK: - Preview Support

    /// Creates an in-memory model container for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        // Add sample data for previews
        let context = controller.modelContainer.mainContext

        let sampleUser = UserEntity(
            userId: "preview-user-1",
            displayName: "Preview User",
            email: "preview@example.com",
            presence: PresenceStatus.online.rawValue,
            lastSeen: Date()
        )

        context.insert(sampleUser)

        return controller
    }()

    /// Private initializer for preview/testing with in-memory storage
    private init(inMemory: Bool) {
        do {
            let schema = Schema([
                UserEntity.self,
                ConversationEntity.self,
                MessageEntity.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            logger.info("SwiftData ModelContainer initialized (inMemory: \(inMemory))")

        } catch {
            logger.error("Failed to initialize ModelContainer: \(error.localizedDescription)")
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
}

// MARK: - ModelContext Extensions

extension ModelContext {
    /// Saves changes to the context on a background thread
    func saveInBackground() async throws {
        try await Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            try self.save()
        }.value
    }
}
