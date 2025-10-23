//
//  AIBackendService.swift
//  MessageAI
//
//  AI Backend Service - Connects iOS app to Python FastAPI backend
//

import Foundation

/// Service for communicating with the AI backend
class AIBackendService {
    
    // MARK: - Configuration
    
    /// Production backend URL (update this with your Render.com URL)
    static let productionURL = "https://messageai-backend-egkh.onrender.com"
    
    /// Local development URL
    static let localURL = "http://localhost:8000"
    
    // MARK: - Properties
    
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - Initialization
    
    /// Initialize with base URL (defaults to production)
    /// - Parameter baseURL: Backend server URL
    init(baseURL: String = AIBackendService.productionURL) {
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

// MARK: - Singleton (Optional)

extension AIBackendService {
    /// Shared instance for convenience (optional pattern)
    static let shared = AIBackendService()
}

