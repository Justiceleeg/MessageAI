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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
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
        userCalendar: [String]? = nil  // Simplified for MVP
    ) async throws -> MessageAnalysisResponse {
        let request = MessageAnalysisRequest(
            messageId: messageId,
            text: text,
            userId: userId,
            conversationId: conversationId,
            userCalendar: userCalendar
        )
        
        return try await post(endpoint: "/api/v1/analyze-message", body: request)
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
        time: String?,
        location: String?,
        userId: String,
        conversationId: String,
        messageId: String
    ) async throws -> EventCreateResponse {
        let request = EventCreateRequest(
            title: title,
            date: date,
            time: time,
            location: location,
            userId: userId,
            conversationId: conversationId,
            messageId: messageId
        )
        
        return try await post(endpoint: "/api/v1/events/create", body: request)
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(DecisionSearchResponse.self, from: data)
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
    let userCalendar: [String]? // Simplified - not used in MVP
}

/// Event create request
struct EventCreateRequest: Codable {
    let title: String
    let date: String
    let time: String?
    let location: String?
    let userId: String
    let conversationId: String
    let messageId: String
}

/// Event search request
struct EventSearchRequest: Codable {
    let userId: String
    let query: String
    let k: Int
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
}

/// Calendar event detection
struct CalendarDetection: Codable {
    let detected: Bool
    let title: String?
    let date: String?  // ISO 8601
    let time: String?  // HH:MM
    let location: String?
}

/// Reminder detection
struct ReminderDetection: Codable {
    let detected: Bool
    let title: String?
    let dueDate: String?  // ISO 8601
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
    let conflictingEvents: [String]
}

// MARK: - Event Response Models

/// Event create response
struct EventCreateResponse: Codable {
    let success: Bool
    let eventId: String?
    let suggestLink: Bool
    let similarEvent: SimilarEvent?
    let message: String
}

/// Similar event info
struct SimilarEvent: Codable {
    let eventId: String?
    let title: String?
    let date: String?
    let similarity: Double?
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

// MARK: - Error Types

/// Errors that can occur when communicating with the AI backend
enum AIBackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid response from backend"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
