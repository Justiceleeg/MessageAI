//
//  SignUpView.swift
//  MessageAI
//
//  Created by Justice Perez White on 10/20/25.
//

import SwiftUI

struct SignUpView: View {

    // MARK: - View Model

    @EnvironmentObject var viewModel: AuthViewModel

    // MARK: - State Properties

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !displayName.isEmpty && isEmailValid && isPasswordValid
    }

    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private var isPasswordValid: Bool {
        password.count >= 6
    }

    private var passwordStrength: PasswordStrength {
        if password.isEmpty {
            return .none
        } else if password.count < 6 {
            return .weak
        } else if password.count < 10 {
            return .medium
        } else {
            return .strong
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(minHeight: 40)

                        // Header
                        headerSection

                        // Form Fields
                        VStack(spacing: 16) {
                            displayNameField
                            emailField
                            passwordField
                            passwordStrengthIndicator
                        }
                        .padding(.horizontal, 32)

                        // Sign Up Button
                        signUpButton
                            .padding(.horizontal, 32)
                            .padding(.top, 8)

                        Spacer()
                            .frame(minHeight: 40)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .alert("Sign Up Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Join MessageAI")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your account to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 16)
    }

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Display Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField("Enter your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocapitalization(.words)
                .accessibilityLabel("Display Name")
                .accessibilityHint("Enter your display name")
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField("Enter your email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .accessibilityLabel("Email Address")
                .accessibilityHint("Enter your email address")

            if !email.isEmpty && !isEmailValid {
                Text("Invalid email format")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: Invalid email format")
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Group {
                    if isPasswordVisible {
                        TextField("Enter your password", text: $password)
                    } else {
                        SecureField("Enter your password", text: $password)
                    }
                }
                .textContentType(.newPassword)
                .autocapitalization(.none)
                .accessibilityLabel("Password")
                .accessibilityHint("Enter a password with at least 6 characters")

                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.gray)
                        .padding(.trailing, 8)
                }
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color(.systemBackground))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            if !password.isEmpty && !isPasswordValid {
                Text("Password must be at least 6 characters")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: Password must be at least 6 characters")
            }
        }
    }

    private var passwordStrengthIndicator: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !password.isEmpty {
                HStack {
                    Text("Password Strength:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(passwordStrength.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(passwordStrength.color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 4)

                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(passwordStrength.color)
                            .frame(
                                width: geometry.size.width * passwordStrength.progress, height: 4)
                    }
                }
                .frame(height: 4)
                .accessibilityLabel("Password strength: \(passwordStrength.title)")
            }
        }
    }

    private var signUpButton: some View {
        Button(action: handleSignUp) {
            Text("Sign Up")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
        .disabled(!isFormValid)
        .accessibilityLabel("Sign Up")
        .accessibilityHint(isFormValid ? "Creates your account" : "Fill out all fields to enable")
    }

    // MARK: - Actions

    private func handleSignUp() {
        Task {
            await viewModel.signUp(email: email, password: password, displayName: displayName)
        }
    }
}

// MARK: - Password Strength

private enum PasswordStrength {
    case none
    case weak
    case medium
    case strong

    var title: String {
        switch self {
        case .none: return ""
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var progress: CGFloat {
        switch self {
        case .none: return 0
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
