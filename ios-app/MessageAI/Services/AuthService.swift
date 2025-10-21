//
//  AuthService.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import Combine
import FirebaseAuth
import OSLog

/// Service responsible for Firebase Authentication operations
@MainActor
class AuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentUser: FirebaseAuth.User?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "AuthService")
    
    // MARK: - Initialization
    
    init() {
        // Check if user is already signed in
        if let firebaseUser = Auth.auth().currentUser {
            self.currentUser = firebaseUser
            logger.info("User already signed in: \(firebaseUser.uid)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Signs up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Firebase User object
    /// - Throws: AuthError with user-friendly message
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        logger.info("Attempting sign up for email: \(email)")
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            self.currentUser = authResult.user
            
            logger.info("Sign up successful for user: \(authResult.user.uid)")
            return authResult.user
            
        } catch let error as NSError {
            logger.error("Sign up failed: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: AuthError with user-friendly message
    func signIn(email: String, password: String) async throws {
        logger.info("Attempting sign in for email: \(email)")
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = authResult.user
            
            logger.info("Sign in successful for user: \(authResult.user.uid)")
            
        } catch let error as NSError {
            logger.error("Sign in failed: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Signs out the current user
    /// - Throws: AuthError if sign out fails
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            logger.info("User signed out successfully")
            
        } catch let error as NSError {
            logger.error("Sign out failed: \(error.localizedDescription)")
            throw AuthError.signOutFailed
        }
    }
    
    // MARK: - Private Methods
    
    /// Maps Firebase error codes to user-friendly error messages
    /// - Parameter error: NSError from Firebase Auth
    /// - Returns: AuthError with user-friendly message
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let authErrorCode = AuthErrorCode(_bridgedNSError: error) else {
            return AuthError.unknown(error.localizedDescription)
        }
        
        switch authErrorCode.code {
        case .invalidEmail:
            return AuthError.invalidEmail
        case .emailAlreadyInUse:
            return AuthError.emailAlreadyInUse
        case .weakPassword:
            return AuthError.weakPassword
        case .wrongPassword:
            return AuthError.wrongPassword
        case .userNotFound:
            return AuthError.userNotFound
        case .networkError:
            return AuthError.networkError
        case .tooManyRequests:
            return AuthError.tooManyRequests
        default:
            return AuthError.unknown(error.localizedDescription)
        }
    }
}

// MARK: - AuthError

/// Custom error type for authentication operations with user-friendly messages
enum AuthError: LocalizedError {
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case wrongPassword
    case userNotFound
    case networkError
    case tooManyRequests
    case signOutFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Invalid email format. Please enter a valid email address."
        case .emailAlreadyInUse:
            return "This email is already registered. Please sign in or use a different email."
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email. Please sign up first."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tooManyRequests:
            return "Too many failed attempts. Please try again later."
        case .signOutFailed:
            return "Failed to sign out. Please try again."
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
}
