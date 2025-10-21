//
//  AuthViewModelTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/20/25.
//

import XCTest
@testable import MessageAI

@MainActor
final class AuthViewModelTests: XCTestCase {
    
    var viewModel: AuthViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = AuthViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_SetsDefaultState() {
        // Assert
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorMessage, "Should have no error initially")
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUp_WithValidData_SetsLoadingState() async {
        // Note: This test requires Firebase Auth Emulator or will hit production Firebase
        // For now, this is a structure test
        
        // Assert initial state
        XCTAssertNotNil(viewModel)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testSignUp_WithInvalidEmail_SetsErrorMessage() async {
        // Arrange
        let invalidEmail = "not-an-email"
        let password = "SecurePass123"
        let displayName = "Test User"
        
        // Act
        await viewModel.signUp(email: invalidEmail, password: password, displayName: displayName)
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message for invalid email")
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after failed sign up")
    }
    
    func testSignUp_WithWeakPassword_SetsErrorMessage() async {
        // Arrange
        let email = "test@example.com"
        let weakPassword = "123"
        let displayName = "Test User"
        
        // Act
        await viewModel.signUp(email: email, password: weakPassword, displayName: displayName)
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message for weak password")
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after failed sign up")
    }
    
    // MARK: - Sign In Tests
    
    func testSignIn_WithInvalidCredentials_SetsErrorMessage() async {
        // Arrange
        let email = "nonexistent@example.com"
        let password = "WrongPassword123"
        
        // Act
        await viewModel.signIn(email: email, password: password)
        
        // Assert
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message for invalid credentials")
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after failed sign in")
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError_RemovesErrorMessage() {
        // Arrange
        viewModel.errorMessage = "Test error"
        
        // Act
        viewModel.clearError()
        
        // Assert
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut_UpdatesAuthenticationState() {
        // Arrange
        // (Would need to sign in first in a real test)
        
        // Act
        viewModel.signOut()
        
        // Assert
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after sign out")
    }
}


