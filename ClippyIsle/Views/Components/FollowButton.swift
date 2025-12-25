//
//  FollowButton.swift
//  ClippyIsle
//
//  A reusable SwiftUI component for following/unfollowing users.
//  Displays "Follow" (追蹤) or "Following" (已追蹤) state.
//

import SwiftUI

// MARK: - Follow Button
/// A reusable button component that toggles between Follow and Following states.
/// Uses SocialService to manage user relationships.
struct FollowButton: View {
    let targetUid: String
    let targetDisplayName: String?
    
    @ObservedObject private var socialService = SocialService.shared
    @State private var isFollowing: Bool = false
    @State private var isProcessing: Bool = false
    
    init(targetUid: String, targetDisplayName: String? = nil) {
        self.targetUid = targetUid
        self.targetDisplayName = targetDisplayName
    }
    
    var body: some View {
        Button(action: toggleFollow) {
            HStack(spacing: 4) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: isFollowing ? "checkmark" : "plus")
                        .font(.caption2.bold())
                }
                
                Text(isFollowing ? "已追蹤" : "追蹤")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
            .foregroundColor(isFollowing ? .primary : .white)
            .clipShape(Capsule())
        }
        .disabled(isProcessing)
        .animation(.easeInOut(duration: 0.2), value: isFollowing)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
        .onAppear {
            isFollowing = socialService.checkIfFollowing(targetUid: targetUid)
        }
        .onChange(of: socialService.followingSet) { newSet in
            isFollowing = newSet.contains(targetUid)
        }
    }
    
    private func toggleFollow() {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Optimistic UI update
        let wasFollowing = isFollowing
        isFollowing.toggle()
        
        Task {
            do {
                if wasFollowing {
                    try await socialService.unfollowUser(targetUid: targetUid)
                } else {
                    try await socialService.followUser(targetUid: targetUid, displayName: targetDisplayName)
                }
            } catch {
                // Revert on error
                await MainActor.run {
                    isFollowing = wasFollowing
                }
                print("❌ [FollowButton] Toggle follow error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Compact Follow Button
/// A more compact version for use in list item footers
struct CompactFollowButton: View {
    let targetUid: String
    let targetDisplayName: String?
    
    @ObservedObject private var socialService = SocialService.shared
    @State private var isFollowing: Bool = false
    @State private var isProcessing: Bool = false
    
    init(targetUid: String, targetDisplayName: String? = nil) {
        self.targetUid = targetUid
        self.targetDisplayName = targetDisplayName
    }
    
    var body: some View {
        Button(action: toggleFollow) {
            HStack(spacing: 3) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                }
                
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption2.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isFollowing ? Color.gray.opacity(0.15) : Color.blue)
            .foregroundColor(isFollowing ? .secondary : .white)
            .clipShape(Capsule())
        }
        .disabled(isProcessing)
        .animation(.easeInOut(duration: 0.2), value: isFollowing)
        .onAppear {
            isFollowing = socialService.checkIfFollowing(targetUid: targetUid)
        }
        .onChange(of: socialService.followingSet) { newSet in
            isFollowing = newSet.contains(targetUid)
        }
    }
    
    private func toggleFollow() {
        guard !isProcessing else { return }
        isProcessing = true
        
        let wasFollowing = isFollowing
        isFollowing.toggle()
        
        Task {
            do {
                if wasFollowing {
                    try await socialService.unfollowUser(targetUid: targetUid)
                } else {
                    try await socialService.followUser(targetUid: targetUid, displayName: targetDisplayName)
                }
            } catch {
                await MainActor.run {
                    isFollowing = wasFollowing
                }
                print("❌ [CompactFollowButton] Toggle follow error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct FollowButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Standard follow button
            FollowButton(targetUid: "sample_user_123", targetDisplayName: "Sample Creator")
            
            // Compact follow button
            CompactFollowButton(targetUid: "another_user_456", targetDisplayName: "Another Creator")
            
            // Example usage in a card footer
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("J")
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                    )
                
                Text("John Doe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                CompactFollowButton(targetUid: "john_doe", targetDisplayName: "John Doe")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding()
        }
        .padding()
    }
}
#endif
