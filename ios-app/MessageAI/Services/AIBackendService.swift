//
//  AIBackendService.swift
//  MessageAI
//
//  AI Backend Service - Connects iOS app to Python FastAPI backend
//

import Foundation

/// Service for communicating with the AI backend
class AIBackendService {
    
    // MARK: - Singleton
    
    static let shared = AIBackendService()
    
    // MARK: - Properties
    
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - Initialization
    
    /// Initialize with base URL (defaults to environment-based config)
    /// - Parameter baseURL: Backend server URL (defaults to Config.backendURL)
    init(baseURL: String = Config.backendURL) {
        self.baseURL = baseURL
        
        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Health Check
    
    /// Check if the backend is healthy and reachable
    /// - Returns: HealthResponse indicating backend status
    /// - Throws: AIBackendError if request fails
    func healthCheck() async throws -> HealthResponse {
        let endpoint = "\(baseURL)/health"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(HealthResponse.self, from: data)
    }
    
    // MARK: - Test Services
    
    /// Test that AI services (OpenAI, Pinecone) are connected
    /// - Returns: ServiceTestResponse with connection status
    /// - Throws: AIBackendError if request fails
    func testServices() async throws -> ServiceTestResponse {
        let endpoint = "\(baseURL)/test-services"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(ServiceTestResponse.self, from: data)
    }
    
    // MARK: - Generic Request Helper
    
    /// Generic POST request helper for future AI endpoints
    /// - Parameters:
    ///   - endpoint: API endpoint path (e.g., "/api/v1/analyze/sentiment")
    ///   - body: Encodable request body
    /// - Returns: Decoded response of type T
    private func post<T: Decodable, U: Encodable>(
        endpoint: String,
        body: U
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AIBackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Message Analysis
    
    /// Analyze a message for events, reminders, decisions, RSVPs, priority, and conflicts
    /// - Parameters:
    ///   - messageId: Unique message identifier
    ///   - text: Message text to analyze
    ///   - userId: User who sent the message
    ///   - conversationId: Conversation identifier
    ///   - userCalendar: Optional array of user's existing events for conflict detection
    /// - Returns: MessageAnalysisResponse with all detections
    /// - Throws: AIBackendError if request fails
    func analyzeMessage(
        messageId: String,
        text: String,
        userId: String,
        conversationId: String,
        timestamp: Date? = nil,  // Message timestamp for accurate date parsing
        userCalendar: [String]? = nil  // Simplified for MVP
    ) async throws -> MessageAnalysisResponse {
        // Convert timestamp to ISO 8601 string
        let timestampString: String?
        if let timestamp = timestamp {
            timestampString = ISO8601DateFormatter().string(from: timestamp)
        } else {
            timestampString = nil
        }
        
        let request = MessageAnalysisRequest(
            messageId: messageId,
            text: text,
            userId: userId,
            conversationId: conversationId,
            timestamp: timestampString,
            userCalendar: userCalendar
        )
        
        do {
            let result: MessageAnalysisResponse = try await post(endpoint: "/api/v1/analyze-message", body: request)
            return result
        } catch {
            throw error
        }
    }
    
    // MARK: - Event Management
    
    /// Create an event with automatic deduplication check
    /// - Parameters:
    ///   - title: Event title
    ///   - date: Event date (ISO 8601 string)
    ///   - time: Event time (HH:MM string, optional)
    ///   - location: Event location (optional)
    ///   - userId: User creating the event
    ///   - conversationId: Conversation where event was created
    ///   - messageId: Message that created the event
    /// - Returns: EventCreateResponse with success status and deduplication info
    /// - Throws: AIBackendError if request fails
    func createEvent(
        title: String,
        date: String,
        startTime: String?,
        endTime: String?,
        duration: Int?,
        location: String?,
        userId: String,
        conversationId: String,
        messageId: String
    ) async throws -> EventCreateResponse {
        let request = EventCreateRequest(
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            location: location,
            userId: userId,
            conversationId: conversationId,
            messageId: messageId
        )
        
        do {
            let response: EventCreateResponse = try await post(endpoint: "/api/v1/events/create", body: request)
            return response
        } catch {
            throw error
        }
    }
    
    /// Search for similar events
    /// - Parameters:
    ///   - userId: User ID for filtering results
    ///   - query: Search query (event title + date)
    ///   - k: Number of results to return (default 3)
    /// - Returns: EventSearchResponse with similar events
    /// - Throws: AIBackendError if request fails
    func searchEvents(
        userId: String,
        query: String,
        k: Int = 3
    ) async throws -> EventSearchResponse {
        let request = EventSearchRequest(
            userId: userId,
            query: query,
            k: k
        )
        
        return try await post(endpoint: "/api/v1/events/search", body: request)
    }
    
    // MARK: - Decision Management (Story 5.2)
    
    /// Search decisions semantically using Pinecone
    /// - Parameters:
    ///   - userId: User ID for filtering results
    ///   - query: Search query
    ///   - conversationId: Optional conversation ID filter
    ///   - k: Number of results to return (default 10)
    /// - Returns: DecisionSearchResponse with similar decisions
    /// - Throws: AIBackendError if request fails
    func searchDecisions(
        userId: String,
        query: String,
        conversationId: String? = nil,
        k: Int = 10
    ) async throws -> DecisionSearchResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/decisions/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "k", value: "\(k)")
        ]
        if let conversationId = conversationId {
            urlComponents.queryItems?.append(URLQueryItem(name: "conversation_id", value: conversationId))
        }
        
        guard let url = urlComponents.url else {
            throw AIBackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(DecisionSearchResponse.self, from: data)
    }
    
    // MARK: - Reminder Management (Story 5.5)
    
    /// Store reminder vector embedding in Pinecone
    /// - Parameter request: Reminder vector storage request
    /// - Returns: ReminderVectorResponse with success status
    /// - Throws: AIBackendError if request fails
    func storeReminderVector(_ request: ReminderVectorRequest) async throws -> ReminderVectorResponse {
        return try await post(endpoint: "/api/v1/reminders/vector", body: request)
    }
    
    /// Search reminders using semantic search
    /// - Parameters:
    ///   - query: Search query
    ///   - userId: User ID for filtering results
    ///   - limit: Number of results to return (default 10)
    /// - Returns: ReminderSearchResponse with search results
    /// - Throws: AIBackendError if request fails
    func searchReminders(
        query: String,
        userId: String,
        limit: Int = 10
    ) async throws -> ReminderSearchResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/reminders/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = urlComponents.url else {
            throw AIBackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(ReminderSearchResponse.self, from: data)
    }
    
    /// Delete reminder vector from Pinecone
    /// - Parameter reminderId: Reminder ID to delete
    /// - Returns: ReminderVectorResponse with success status
    /// - Throws: AIBackendError if request fails
    func deleteReminderVector(_ reminderId: String) async throws -> ReminderVectorResponse {
        let endpoint = "\(baseURL)/api/v1/reminders/vector/\(reminderId)"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Note: Using CodingKeys for field mapping instead of convertFromSnakeCase
        
        return try decoder.decode(ReminderVectorResponse.self, from: data)
    }
    
    // MARK: - Event Indexing Methods
    
    /// Index an event in Pinecone for conflict detection
    /// - Parameter eventData: Event data dictionary
    /// - Throws: AIBackendError if request fails
    func indexEvent(_ eventData: [String: Any]) async throws {
        let endpoint = "\(baseURL)/api/v1/events/index"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        } catch {
            throw AIBackendError.encodingError(error)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Update an indexed event in Pinecone
    /// - Parameters:
    ///   - eventId: ID of event to update
    ///   - eventData: Updated event data dictionary
    /// - Throws: AIBackendError if request fails
    func updateEvent(_ eventId: String, _ eventData: [String: Any]) async throws {
        let endpoint = "\(baseURL)/api/v1/events/\(eventId)/index"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        } catch {
            throw AIBackendError.encodingError(error)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Delete an event from Pinecone index
    /// - Parameter eventId: ID of event to delete
    /// - Throws: AIBackendError if request fails
    func deleteEvent(_ eventId: String) async throws {
        let endpoint = "\(baseURL)/api/v1/events/\(eventId)/index"
        guard let url = URL(string: endpoint) else {
            throw AIBackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIBackendError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Models

/// Health check response
struct HealthResponse: Codable {
    let status: String
    let service: String?
}

/// Service test response
struct ServiceTestResponse: Codable {
    let status: String
    let vectorStore: String?
    let openaiService: String?
    let pineconeIndex: String?
    let stats: PineconeStats?
}

/// Pinecone statistics
struct PineconeStats: Codable {
    let dimensions: Int?
    let totalVectorCount: Int?
    let namespaces: [String]?
}

// MARK: - Request Models

/// Message analysis request
struct MessageAnalysisRequest: Codable {
    let messageId: String
    let text: String
    let userId: String
    let conversationId: String
    let timestamp: String?  // ISO 8601 timestamp for accurate date calculations
    let userCalendar: [String]? // Simplified - not used in MVP
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case text
        case userId = "user_id"
        case conversationId = "conversation_id"
        case timestamp
        case userCalendar = "user_calendar"
    }
}

/// Event create request
struct EventCreateRequest: Codable {
    let title: String
    let date: String
    let startTime: String?
    let endTime: String?
    let duration: Int?
    let location: String?
    let userId: String
    let conversationId: String
    let messageId: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case location
        case userId = "user_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
    }
}

/// Event search request
struct EventSearchRequest: Codable {
    let userId: String
    let query: String
    let k: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case query
        case k
    }
}

// MARK: - Analysis Response Models

/// Message analysis response
struct MessageAnalysisResponse: Codable {
    let messageId: String
    let calendar: CalendarDetection
    let reminder: ReminderDetection
    let decision: DecisionDetection
    let rsvp: RSVPDetection
    let priority: PriorityDetection
    let conflict: ConflictDetection
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case calendar
        case reminder
        case decision
        case rsvp
        case priority
        case conflict
    }
}

/// Calendar event detection
struct CalendarDetection: Codable {
    let detected: Bool
    let title: String?
    let date: String?  // ISO 8601
    let startTime: String?  // HH:MM (24-hour)
    let endTime: String?  // HH:MM (24-hour)
    let duration: Int?  // Duration in minutes
    let location: String?
    let isInvitation: Bool?  // Whether this event contains invitation language (optional with default)
    let similarEvents: [String]?  // List of similar event IDs (Story 5.6)
    
    enum CodingKeys: String, CodingKey {
        case detected
        case title
        case date
        case startTime
        case endTime
        case duration
        case location
        case isInvitation = "is_invitation"
        case similarEvents = "similar_events"
    }
}

/// Reminder detection
struct ReminderDetection: Codable {
    let detected: Bool
    let title: String?
    let dueDate: String?  // ISO 8601
    
    enum CodingKeys: String, CodingKey {
        case detected
        case title
        case dueDate = "due_date"
    }
}

/// Decision detection
struct DecisionDetection: Codable {
    let detected: Bool
    let text: String?
}

/// RSVP detection
struct RSVPDetection: Codable {
    let detected: Bool
    let status: String?  // "accepted" or "declined"
    let eventReference: String?
    
    enum CodingKeys: String, CodingKey {
        case detected
        case status
        case eventReference = "event_reference"
    }
}

/// Invitation detection (Story 5.4)
struct InvitationDetection: Codable {
    let detected: Bool
    let type: String?  // "create"
    let eventTitle: String?
    let invitationDetected: Bool
}

/// Priority detection
struct PriorityDetection: Codable {
    let detected: Bool
    let level: String?  // "low", "medium", "high"
    let reason: String?  // Brief explanation of priority assignment (Story 5.3)
}

/// Conflict detection
struct ConflictDetection: Codable {
    let detected: Bool
    let conflictingEvents: [ConflictEvent]
    let reasoning: String?
    let sameEventDetected: Bool?
    
    enum CodingKeys: String, CodingKey {
        case detected
        case conflictingEvents = "conflicting_events"
        case reasoning
        case sameEventDetected = "same_event_detected"
    }
}

/// Individual conflicting event
struct ConflictEvent: Codable {
    let id: String
    let title: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let similarityScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case startTime
        case endTime
        case location
        case similarityScore = "similarity_score"
    }
}

// MARK: - Event Response Models

/// Event create response
struct EventCreateResponse: Codable {
    let success: Bool
    let eventId: String?
    let suggestLink: Bool
    let similarEvent: SimilarEvent?
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case eventId = "event_id"
        case suggestLink = "suggest_link"
        case similarEvent = "similar_event"
        case message
    }
}

/// Similar event info
struct SimilarEvent: Codable {
    let eventId: String?
    let title: String?
    let date: String?
    let similarity: Double?
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case title
        case date
        case similarity
    }
}

/// Event search response
struct EventSearchResponse: Codable {
    let results: [EventSearchResult]
}

/// Event search result
struct EventSearchResult: Codable {
    let eventId: String
    let title: String
    let date: String
    let similarity: Double
}

// MARK: - Decision Response Models (Story 5.2)

/// Decision search response
struct DecisionSearchResponse: Codable {
    let results: [DecisionSearchResult]
}

/// Decision search result
struct DecisionSearchResult: Codable {
    let decisionId: String
    let text: String
    let conversationId: String
    let messageId: String
    let timestamp: String
    let similarity: Double
}

// MARK: - Reminder Request Models (Story 5.5)

/// Reminder vector storage request
struct ReminderVectorRequest: Codable {
    let reminderId: String
    let title: String
    let userId: String
    let conversationId: String
    let sourceMessageId: String
    let dueDate: String
    let timestamp: String
}

// MARK: - Reminder Response Models (Story 5.5)

/// Reminder vector response
struct ReminderVectorResponse: Codable {
    let success: Bool
    let reminderId: String?
    let message: String
}

/// Reminder search response
struct ReminderSearchResponse: Codable {
    let results: [ReminderSearchResult]
}

/// Reminder search result
struct ReminderSearchResult: Codable, Identifiable {
    var id: String { reminderId }
    let reminderId: String
    let title: String
    let dueDate: String
    let conversationId: String
    let sourceMessageId: String
    let similarity: Double
}

// MARK: - Error Types

/// Errors that can occur when communicating with the AI backend
enum AIBackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid response from backend"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        }
    }
}
