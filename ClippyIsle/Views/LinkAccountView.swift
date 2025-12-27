import SwiftUI

/// View for linking an email/password credential to an anonymous account
/// This upgrades the guest account to a permanent account while preserving existing data
struct LinkAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    let themeColor: Color
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLinking: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert: Bool = false
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        email.contains("@")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Header Section
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 50))
                            .foregroundColor(themeColor)
                        
                        Text("保護你的帳號")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Secure Your Account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Link an email and password to your account to keep your data safe across devices and app reinstalls.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)
                
                // Warning Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Guest Account (Unsafe)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Your data may be lost if you uninstall the app or switch devices.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Email/Password Input Section
                Section(header: Text("Account Credentials"), footer: Text("Password must be at least 6 characters.")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                    
                    // Password match indicator
                    if !password.isEmpty && !confirmPassword.isEmpty {
                        HStack {
                            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(password == confirmPassword ? .green : .red)
                            Text(password == confirmPassword ? "Passwords match" : "Passwords do not match")
                                .font(.caption)
                                .foregroundColor(password == confirmPassword ? .green : .red)
                        }
                    }
                }
                
                // Error Message
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Link Button Section
                Section {
                    Button(action: linkAccount) {
                        HStack {
                            Spacer()
                            if isLinking {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text(isLinking ? "Linking..." : "Link Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!isFormValid || isLinking)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFormValid && !isLinking ? themeColor : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(isFormValid && !isLinking ? .white : .gray)
                }
                
                // Benefits Section
                Section(header: Text("Benefits")) {
                    LinkBenefitRow(icon: "icloud.fill", title: "Data Sync", description: "Access your data on any device")
                    LinkBenefitRow(icon: "lock.shield.fill", title: "Account Recovery", description: "Reset password if forgotten")
                    LinkBenefitRow(icon: "arrow.triangle.2.circlepath", title: "App Reinstall Safe", description: "Keep your data after reinstalling")
                }
            }
            .navigationTitle("Link Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Account Linked!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been successfully secured with email: \(email)")
            }
        }
        .tint(themeColor)
    }
    
    private func linkAccount() {
        errorMessage = nil
        isLinking = true
        
        Task {
            do {
                try await authManager.linkEmailAccount(email: email, password: password)
                
                await MainActor.run {
                    isLinking = false
                    showSuccessAlert = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isLinking = false
                    errorMessage = error.localizedDescription
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

/// Row view for displaying a benefit of linking account
private struct LinkBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LinkAccountView(themeColor: .blue)
        .environmentObject(AuthenticationManager.shared)
}
