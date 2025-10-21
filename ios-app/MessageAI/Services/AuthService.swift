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
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    // MARK: - Published Properties
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "AuthService")
    private var firestoreService: FirestoreService?
    
    // MARK: - Initialization
    
    private init() {
        // Initialize without FirestoreService to avoid concurrency issues with singleton
        // FirestoreService will be lazily initialized when needed
        
        // Check if user is already signed in and load their data
        if let firebaseUser = Auth.auth().currentUser {
            logger.info("Firebase user already signed in: \(firebaseUser.uid)")
            
            // Load full user data from Firestore
            Task { @MainActor in
                do {
                    let user = try await self.getFirestoreService().getUserProfile(userId: firebaseUser.uid)
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.logger.info("User data loaded: \(user.displayName)")
                } catch {
                    self.logger.error("Failed to load user data on init: \(error.localizedDescription)")
                    // Firebase user exists but Firestore data doesn't - sign out
                    try? Auth.auth().signOut()
                }
            }
        }
    }
    
    // Convenience initializer for testing with dependency injection
    init(firestoreService: FirestoreService) {
        self.firestoreService = firestoreService
    }
    
    // MARK: - Private Helper
    
    /// Get or create FirestoreService instance
    private func getFirestoreService() -> FirestoreService {
        if firestoreService == nil {
            firestoreService = FirestoreService()
        }
        return firestoreService!
    }
    
    // MARK: - Public Methods
    
    /// Signs up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: User's display name
    /// - Returns: Custom User object
    /// - Throws: AuthError with user-friendly message
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        logger.info("Attempting sign up for email: \(email)")
        
        do {
            // 1. Create Firebase Auth user
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            logger.info("Firebase auth successful for user: \(authResult.user.uid)")
            
            // 2. Create Firestore user profile
            try await getFirestoreService().createUserProfile(
                userId: authResult.user.uid,
                displayName: displayName,
                email: email
            )
            logger.info("Firestore profile created for user: \(authResult.user.uid)")
            
            // 3. Fetch the created user profile
            let user = try await getFirestoreService().getUserProfile(userId: authResult.user.uid)
            
            // 4. Set current user
            self.currentUser = user
            self.isAuthenticated = true
            
            logger.info("Sign up complete for user: \(user.displayName)")
            return user
            
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
            // 1. Authenticate with Firebase
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            logger.info("Firebase auth successful for user: \(authResult.user.uid)")
            
            // 2. Fetch custom User from Firestore
            let user = try await getFirestoreService().getUserProfile(userId: authResult.user.uid)
            
            // 3. Update presence to online
            try await getFirestoreService().updateUserPresence(userId: user.userId, presence: .online)
            
            // 4. Fetch updated user with online presence
            let updatedUser = try await getFirestoreService().getUserProfile(userId: authResult.user.uid)
            
            // 5. Set current user
            self.currentUser = updatedUser
            self.isAuthenticated = true
            
            logger.info("Sign in complete for user: \(updatedUser.displayName)")
            
        } catch let error as NSError {
            logger.error("Sign in failed: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Signs out the current user
    /// - Throws: AuthError if sign out fails
    func signOut() async throws {
        do {
            // Update presence to offline before signing out
            if let userId = currentUser?.userId {
                try? await getFirestoreService().updateUserPresence(userId: userId, presence: .offline)
            }
            
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
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
