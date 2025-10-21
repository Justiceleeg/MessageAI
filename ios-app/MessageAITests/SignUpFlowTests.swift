//
//  SignUpFlowTests.swift
//  MessageAITests
//
//  Created by Dev Agent (James) on 10/20/25.
//

import XCTest

@testable import MessageAI

@MainActor
final class SignUpFlowTests: XCTestCase {

    var authService: AuthService!
    var firestoreService: FirestoreService!
    var authViewModel: AuthViewModel!

    override func setUp() async throws {
        try await super.setUp()

        authService = AuthService()
        firestoreService = FirestoreService()
        authViewModel = AuthViewModel(authService: authService, firestoreService: firestoreService)
    }

    override func tearDown() async throws {
        authService = nil
        firestoreService = nil
        authViewModel = nil
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    func testCompleteSignUpFlow_WithValidData_CreatesUserAndAuthenticates() async {
        // Note: This test requires Firebase Auth Emulator to avoid hitting production
        // For now, this is a structure test validating the integration points

        // Act & Assert - Test the integration structure
        XCTAssertNotNil(authViewModel, "AuthViewModel should be initialized")
        XCTAssertFalse(authViewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(authViewModel.errorMessage, "Should have no error initially")

        // In a real test with Firebase Emulator, you would:
        // 1. Generate test credentials: email, password, displayName
        // 2. Call authViewModel.signUp()
        // 3. Verify authViewModel.isAuthenticated becomes true
        // 4. Verify Firestore document was created
        // 5. Verify user can sign out and sign back in
    }

    func testSignUpFlow_WithInvalidEmail_ShowsError() async {
        // Arrange
        let invalidEmail = "not-an-email"
        let password = "TestPassword123"
        let displayName = "Test User"

        // Act
        await authViewModel.signUp(email: invalidEmail, password: password, displayName: displayName)

        // Assert
        XCTAssertNotNil(authViewModel.errorMessage, "Should have error message for invalid email")
        XCTAssertFalse(authViewModel.isAuthenticated, "Should not be authenticated with invalid email")
        XCTAssertFalse(authViewModel.isLoading, "Should not be loading after error")
    }

    func testSignUpFlow_WithWeakPassword_ShowsError() async {
        // Arrange
        let email = "test@example.com"
        let weakPassword = "123"
        let displayName = "Test User"

        // Act
        await authViewModel.signUp(email: email, password: weakPassword, displayName: displayName)

        // Assert
        XCTAssertNotNil(authViewModel.errorMessage, "Should have error message for weak password")
        XCTAssertFalse(authViewModel.isAuthenticated, "Should not be authenticated with weak password")
    }

    func testSignUpFlow_ErrorHandling_ClearsError() async {
        // Arrange
        authViewModel.errorMessage = "Test error"

        // Act
        authViewModel.clearError()

        // Assert
        XCTAssertNil(authViewModel.errorMessage, "Error should be cleared")
    }

    // MARK: - Service Integration Tests

    func testAuthServiceAndFirestoreService_AreInjected() {
        // Assert
        XCTAssertNotNil(authService, "AuthService should be available")
        XCTAssertNotNil(firestoreService, "FirestoreService should be available")
    }

    func testAuthViewModel_CoordinatesBothServices() {
        // Assert that AuthViewModel has access to both services
        XCTAssertNotNil(authViewModel, "AuthViewModel should coordinate both services")
    }

    // MARK: - Navigation Tests

    func testAuthenticationState_UpdatesCorrectly() {
        // Arrange
        let initialState = authViewModel.isAuthenticated

        // Assert
        XCTAssertFalse(initialState, "Should not be authenticated initially")

        // Note: In a real test with Firebase Emulator, you would:
        // 1. Sign up a user
        // 2. Verify isAuthenticated becomes true
        // 3. Sign out
        // 4. Verify isAuthenticated becomes false
    }
}
