//
//  CloudInboxView.swift
//  ClippyIsle
//
//  Cloud Inbox View for displaying email-forwarded notes (Pro Feature).
//

import SwiftUI
import UIKit

// MARK: - Cloud Inbox View
struct CloudInboxView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var cloudNotesManager = CloudNotesManager.shared
    @State private var showPaywall = false
    @Environment(\.dismiss) var dismiss
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !subscriptionManager.isPro {
                    // Non-Pro users see paywall
                    proFeatureLockedView
                } else {
                    // Pro users see inbox content
                    inboxContentView
                }
            }
            .navigationTitle("Cloud Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(themeColor)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear {
            if subscriptionManager.isPro, let uid = authManager.currentUID {
                cloudNotesManager.startListening(uid: uid)
            }
        }
        .onDisappear {
            cloudNotesManager.stopListening()
        }
    }
    
    // MARK: - Pro Feature Locked View
    private var proFeatureLockedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Premium Feature")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Cloud Notes allows you to forward emails to save them as notes. Upgrade to Pro to unlock this feature.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Inbox Content View (Pro Users)
    private var inboxContentView: some View {
        Group {
            if cloudNotesManager.isLoading {
                ProgressView("Loading...")
            } else if let error = cloudNotesManager.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Error loading inbox")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        if let uid = authManager.currentUID {
                            Task { await cloudNotesManager.fetchInbox(uid: uid) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if cloudNotesManager.inboxItems.isEmpty {
                emptyInboxView
            } else {
                inboxListView
            }
        }
    }
    
    // MARK: - Empty Inbox View
    private var emptyInboxView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Notes Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Forward emails to\n\(cloudNotesManager.forwardingEmail)\nto save them as notes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: copyForwardingEmail) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Email Address")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeColor.opacity(0.1))
                .foregroundColor(themeColor)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - Inbox List View
    private var inboxListView: some View {
        List {
            ForEach(cloudNotesManager.inboxItems) { item in
                CloudInboxItemRow(item: item, themeColor: themeColor)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            markItemAsProcessed(item)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            copyToClipboard(item.content)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .tint(themeColor)
                    }
                    .onTapGesture {
                        copyToClipboard(item.content)
                    }
                    .accessibilityLabel(item.subject.isEmpty ? "Note, no subject" : "Note: \(item.subject)")
                    .accessibilityValue("From \(item.from)")
                    .accessibilityHint("Double tap to copy content")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if let uid = authManager.currentUID {
                await cloudNotesManager.fetchInbox(uid: uid)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func copyForwardingEmail() {
        UIPasteboard.general.string = cloudNotesManager.forwardingEmail
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func copyToClipboard(_ content: String) {
        UIPasteboard.general.string = content
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func markItemAsProcessed(_ item: CloudInboxItem) {
        guard let uid = authManager.currentUID else { return }
        
        Task {
            do {
                try await cloudNotesManager.markAsProcessed(item, uid: uid)
            } catch {
                print("❌ Failed to mark item as processed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Cloud Inbox Item Row
struct CloudInboxItemRow: View {
    let item: CloudInboxItem
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subject line
            Text(item.subject.isEmpty ? "(No Subject)" : item.subject)
                .font(.headline)
                .lineLimit(1)
            
            // Content preview
            Text(item.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Metadata
            HStack {
                // From
                Text(item.from)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Time
                Text(item.receivedAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
