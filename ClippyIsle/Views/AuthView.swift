import SwiftUI
import FirebaseAuth

/// Authentication View - Login/Signup screen for CC ISLE
struct AuthView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    headerSection
                    
                    // Form Fields
                    formSection
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        errorBanner(message: errorMessage)
                    }
                    
                    // Action Buttons
                    actionButtons
                    
                    // Divider
                    dividerSection
                    
                    // Guest Button
                    guestButton
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .navigationBarHidden(true)
            .disabled(isLoading)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Logo
            Image(systemName: "island.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan, .teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // App Title
            Text("CC ISLE")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Subtitle
            Text(isSignUpMode ? "Create your account" : "Welcome back")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Enter your email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    SecureField("Enter your password", text: $password)
                        .textContentType(isSignUpMode ? .newPassword : .password)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Confirm Password (Sign Up only)
            if isSignUpMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                        
                        // Password match indicator
                        if !confirmPassword.isEmpty {
                            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(password == confirmPassword ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSignUpMode)
    }
    
    // MARK: - Error Banner
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary Action Button (Sign In / Sign Up)
            Button(action: primaryAction) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUpMode ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoading)
            .opacity(isFormValid ? 1.0 : 0.6)
            
            // Toggle Sign In / Sign Up
            Button(action: {
                withAnimation {
                    isSignUpMode.toggle()
                    errorMessage = nil
                }
            }) {
                Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            
            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }
    
    // MARK: - Guest Button
    private var guestButton: some View {
        Button(action: continueAsGuest) {
            HStack {
                Image(systemName: "person.fill.questionmark")
                Text("Continue as Guest")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Form Validation
    private var isFormValid: Bool {
        let emailValid = !email.isEmpty && email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        if isSignUpMode {
            return emailValid && passwordValid && password == confirmPassword
        } else {
            return emailValid && passwordValid
        }
    }
    
    // MARK: - Actions
    private func primaryAction() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                if isSignUpMode {
                    try await authManager.signUp(email: email, password: password)
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func continueAsGuest() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signInAnonymously()
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthenticationManager.shared)
}
