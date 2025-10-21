//
//  AuthViewModel.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import Foundation
import Combine
import FirebaseAuth
import OSLog

/// ViewModel responsible for coordinating authentication flows
@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    
    let authService: AuthService
    let firestoreService: FirestoreService
    private let logger = Logger(subsystem: "com.jpw.message-ai", category: "AuthViewModel")
    
    // MARK: - Initialization
    
    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestoreService = firestoreService
        
        // Check if user is already authenticated
        self.isAuthenticated = authService.currentUser != nil
    }
    
    convenience init() {
        self.init(authService: AuthService(), firestoreService: FirestoreService())
    }
    
    // MARK: - Sign Up Methods
    
    /// Signs up a new user with email, password, and display name
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: User's display name
    func signUp(email: String, password: String, displayName: String) async {
        logger.info("Starting sign-up process for email: \(email)")
        
        // Clear any previous errors
        errorMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // Step 1: Create Firebase Auth user
            let firebaseUser = try await authService.signUp(email: email, password: password)
            logger.info("Firebase Auth user created: \(firebaseUser.uid)")
            
            // Step 2: Create Firestore user profile
            try await firestoreService.createUserProfile(
                userId: firebaseUser.uid,
                displayName: displayName,
                email: email
            )
            logger.info("Firestore user profile created for: \(firebaseUser.uid)")
            
            // Step 3: Update authentication state
            isAuthenticated = true
            logger.info("Sign-up completed successfully")
            
        } catch let error as AuthError {
            // Handle authentication errors
            logger.error("Sign-up failed with AuthError: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isAuthenticated = false
            
        } catch let error as FirestoreError {
            // Handle Firestore errors
            logger.error("Sign-up failed with FirestoreError: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isAuthenticated = false
            
            // Note: User was created in Firebase Auth but profile creation failed
            // In a production app, you might want to handle this with retry logic
            // or cleanup the Firebase Auth user
            
        } catch {
            // Handle unexpected errors
            logger.error("Sign-up failed with unexpected error: \(error.localizedDescription)")
            errorMessage = "An unexpected error occurred. Please try again."
            isAuthenticated = false
        }
    }
    
    // MARK: - Sign In Methods
    
    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async {
        logger.info("Starting sign-in process for email: \(email)")
        
        errorMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await authService.signIn(email: email, password: password)
            isAuthenticated = true
            logger.info("Sign-in completed successfully")
            
        } catch let error as AuthError {
            logger.error("Sign-in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isAuthenticated = false
            
        } catch {
            logger.error("Sign-in failed with unexpected error: \(error.localizedDescription)")
            errorMessage = "An unexpected error occurred. Please try again."
            isAuthenticated = false
        }
    }
    
    // MARK: - Sign Out Methods
    
    /// Signs out the current user
    func signOut() {
        logger.info("Signing out user")
        
        do {
            try authService.signOut()
            isAuthenticated = false
            logger.info("Sign-out completed successfully")
            
        } catch {
            logger.error("Sign-out failed: \(error.localizedDescription)")
            errorMessage = "Failed to sign out. Please try again."
        }
    }
    
    // MARK: - Helper Methods
    
    /// Clears the current error message
    func clearError() {
        errorMessage = nil
    }
}

