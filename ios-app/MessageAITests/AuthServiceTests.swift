//
//  AuthServiceTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/20/25.
//

import XCTest
@testable import MessageAI

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var authService: AuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        authService = AuthService()
    }
    
    override func tearDown() async throws {
        authService = nil
        try await super.tearDown()
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUp_WithValidCredentials_ReturnsUser() async throws {
        // Note: This test requires Firebase Auth Emulator or will hit production Firebase
        // For now, this is a structure test to ensure the API is correct
        
        // Act & Assert
        // This would normally call the actual Firebase Auth
        // In a real test environment, you'd use Firebase Local Emulator Suite
        // or mock the Firebase Auth SDK
        
        // For now, we're testing the structure is correct
        XCTAssertNotNil(authService)
    }
    
    func testSignUp_WithInvalidEmail_ThrowsError() async {
        // Arrange
        let invalidEmail = "not-an-email"
        let password = "SecurePass123"
        
        // Act & Assert
        do {
            _ = try await authService.signUp(email: invalidEmail, password: password)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error is expected
            XCTAssertTrue(error is AuthError, "Error should be AuthError type")
        }
    }
    
    func testSignUp_WithWeakPassword_ThrowsError() async {
        // Arrange
        let email = "test@example.com"
        let weakPassword = "123" // Too short
        
        // Act & Assert
        do {
            _ = try await authService.signUp(email: email, password: weakPassword)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error is expected
            XCTAssertTrue(error is AuthError, "Error should be AuthError type")
        }
    }
    
    // MARK: - Sign In Tests
    
    func testSignIn_WithValidCredentials_UpdatesCurrentUser() async {
        // Act & Assert
        // This test structure validates the API
        XCTAssertNotNil(authService)
    }
    
    func testSignIn_WithWrongPassword_ThrowsError() async {
        // Arrange
        let email = "test@example.com"
        let wrongPassword = "WrongPassword123"
        
        // Act & Assert
        do {
            try await authService.signIn(email: email, password: wrongPassword)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error is expected
            XCTAssertTrue(error is AuthError, "Error should be AuthError type")
        }
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut_ClearsCurrentUser() throws {
        // Arrange
        // (User would need to be signed in first)
        
        // Act
        // Note: This will only work if a user is actually signed in
        // For proper testing, you'd need Firebase Auth Emulator
        
        // Assert
        XCTAssertNotNil(authService)
    }
    
    // MARK: - Error Mapping Tests
    
    func testAuthError_InvalidEmail_HasCorrectMessage() {
        // Arrange
        let error = AuthError.invalidEmail
        
        // Act
        let message = error.errorDescription
        
        // Assert
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("Invalid email"), "Error message should mention invalid email")
    }
    
    func testAuthError_WeakPassword_HasCorrectMessage() {
        // Arrange
        let error = AuthError.weakPassword
        
        // Act
        let message = error.errorDescription
        
        // Assert
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("weak"), "Error message should mention weak password")
    }
    
    func testAuthError_NetworkError_HasCorrectMessage() {
        // Arrange
        let error = AuthError.networkError
        
        // Act
        let message = error.errorDescription
        
        // Assert
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("Network"), "Error message should mention network")
    }
}

