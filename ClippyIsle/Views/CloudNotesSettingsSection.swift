//
//  CloudNotesSettingsSection.swift
//  ClippyIsle
//
//  Cloud Notes settings section for email binding (Pro Feature).
//

import SwiftUI
import UIKit

// MARK: - Cloud Notes Settings Section
struct CloudNotesSettingsSection: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var cloudNotesManager = CloudNotesManager.shared
    @State private var emailInput: String = ""
    @State private var showPaywall = false
    
    // Computed property for trimmed email
    private var trimmedEmail: String {
        emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        Section(header: Text("Cloud Notes"), footer: cloudNotesFooter) {
            if !subscriptionManager.isPro {
                // Non-Pro users: Show feature intro and upgrade button
                nonProContent
            } else {
                // Pro users: Show full binding interface
                proContent
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Non-Pro Content
    private var nonProContent: some View {
        Group {
            // Feature description
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(.blue)
                    Text("Email-to-Notes")
                        .fontWeight(.medium)
                }
                
                Text("Forward emails to save them as notes. Your personal inbox in CC Isle.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            // Upgrade button
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Pro Content
    private var proContent: some View {
        Group {
            // Forwarding address (copyable)
            HStack {
                Text("Forward to")
                Spacer()
                Text(cloudNotesManager.forwardingEmail)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        UIPasteboard.general.string = cloudNotesManager.forwardingEmail
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    .accessibilityLabel("Forwarding email address: \(cloudNotesManager.forwardingEmail)")
                    .accessibilityHint("Double tap to copy email address")
            }
            
            Text("Tap the email address to copy")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Email binding input
            HStack {
                Text("Your Email")
                TextField("Enter your email", text: $emailInput)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(cloudNotesManager.isBindingEmail)
            }
            
            // Bind button
            Button(action: bindEmail) {
                HStack {
                    if cloudNotesManager.isBindingEmail {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if cloudNotesManager.bindingSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text(cloudNotesManager.bindingSuccess ? "Email Bound" : "Bind Email")
                        .fontWeight(.medium)
                }
            }
            .disabled(trimmedEmail.isEmpty || cloudNotesManager.isBindingEmail)
            
            // Error message
            if let error = cloudNotesManager.bindingError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Footer
    private var cloudNotesFooter: some View {
        Group {
            if subscriptionManager.isPro {
                Text("Bind your email to receive forwarded messages. Forward any email to the address above, and it will appear in your Cloud Inbox.")
            } else {
                Text("Unlock Cloud Notes to save emails as notes by forwarding them to your personal inbox.")
            }
        }
    }
    
    // MARK: - Actions
    private func bindEmail() {
        guard let uid = authManager.currentUID else {
            cloudNotesManager.bindingError = "Not signed in. Please try again."
            return
        }
        
        Task {
            do {
                try await cloudNotesManager.bindEmail(emailInput, uid: uid)
            } catch {
                // Error is already set by the manager
                print("❌ Failed to bind email: \(error.localizedDescription)")
            }
        }
    }
}
