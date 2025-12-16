//
//  CloudInboxView.swift
//  ClippyIsle
//
//  Cloud Inbox View for displaying email-forwarded notes (Pro Feature).
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Cloud Inbox View
struct CloudInboxView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var cloudNotesManager = CloudNotesManager.shared
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var speechManager: SpeechManager
    @State private var showPaywall = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Preview state for opening items
    @State private var selectedItem: ClipboardItem?
    @State private var isShowingPreview = false
    @AppStorage("previewFontSize") private var previewFontSize: Double = 17.0
    
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
        .sheet(isPresented: $isShowingPreview) {
            if let item = selectedItem {
                NavigationView {
                    PreviewView(
                        item: Binding(
                            get: { item },
                            set: { newItem in selectedItem = newItem }
                        ),
                        clipboardManager: clipboardManager,
                        speechManager: speechManager,
                        fontSize: $previewFontSize,
                        isIPad: horizontalSizeClass == .regular
                    )
                }
                .tint(themeColor)
            }
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
                CloudInboxItemRow(
                    item: item,
                    themeColor: themeColor,
                    isSpeaking: speechManager.isSpeaking && speechManager.currentItemID?.uuidString == item.id,
                    onPreview: {
                        // Convert CloudInboxItem to ClipboardItem for preview
                        let clipboardItem = convertToClipboardItem(item)
                        selectedItem = clipboardItem
                        isShowingPreview = true
                    },
                    onSpeak: {
                        // Start or stop speech for this item
                        toggleSpeech(for: item)
                    }
                )
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
                    .accessibilityLabel(item.subject.isEmpty ? "Note, no subject" : "Note: \(item.subject)")
                    .accessibilityValue("From \(item.from)")
                    .accessibilityHint("Tap to preview, double tap to speak")
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
    
    /// Converts a CloudInboxItem to a ClipboardItem for preview
    private func convertToClipboardItem(_ item: CloudInboxItem) -> ClipboardItem {
        // Use the inbox item's id as UUID (or generate a new one if conversion fails)
        let uuid = UUID(uuidString: item.id) ?? UUID()
        return ClipboardItem(
            id: uuid,
            content: item.content,
            type: UTType.text.identifier,
            filename: nil,
            timestamp: item.receivedAt,
            isPinned: false,
            displayName: item.subject.isEmpty ? nil : item.subject,
            isTrashed: false,
            tags: nil,
            fileData: nil
        )
    }
    
    /// Toggles speech for the given item
    private func toggleSpeech(for item: CloudInboxItem) {
        let itemUUID = UUID(uuidString: item.id) ?? UUID()
        
        // If this item is currently speaking, stop it
        if speechManager.currentItemID?.uuidString == item.id {
            if speechManager.isSpeaking {
                speechManager.pause()
            } else if speechManager.isPaused {
                speechManager.resume()
            } else {
                // Start fresh
                speechManager.play(
                    text: item.content,
                    title: item.subject.isEmpty ? "Cloud Note" : item.subject,
                    itemID: itemUUID,
                    url: nil,
                    fromLocation: nil
                )
            }
        } else {
            // Stop any current speech and start this item
            speechManager.stop()
            speechManager.play(
                text: item.content,
                title: item.subject.isEmpty ? "Cloud Note" : item.subject,
                itemID: itemUUID,
                url: nil,
                fromLocation: nil
            )
        }
    }
}

// MARK: - Cloud Inbox Item Row
struct CloudInboxItemRow: View {
    let item: CloudInboxItem
    let themeColor: Color
    var isSpeaking: Bool = false
    var onPreview: () -> Void = {}
    var onSpeak: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview button (left side)
            Button(action: onPreview) {
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundColor(themeColor)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            
            // Content area
            VStack(alignment: .leading, spacing: 6) {
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
            .contentShape(Rectangle())
            .onTapGesture(perform: onPreview)
            
            // Speak button (right side)
            Button(action: onSpeak) {
                Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: 18))
                    .foregroundColor(isSpeaking ? themeColor : .secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
