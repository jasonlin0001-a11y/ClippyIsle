//
//  UserListView.swift
//  ClippyIsle
//
//  A view for displaying lists of followers or following users.
//

import SwiftUI

// MARK: - User List View
/// Displays a list of users (followers or following)
struct UserListView: View {
    let userId: String
    let listType: UserListType
    let themeColor: Color
    
    @StateObject private var viewModel: UserListViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    init(userId: String, listType: UserListType, themeColor: Color = .blue) {
        self.userId = userId
        self.listType = listType
        self.themeColor = themeColor
        self._viewModel = StateObject(wrappedValue: UserListViewModel(userId: userId, listType: listType))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.users.isEmpty {
                loadingView
            } else if viewModel.users.isEmpty {
                emptyView
            } else {
                userListView
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
        .navigationTitle(listType.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchUsers()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading \(listType.title.lowercased())...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: listType == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(listType.emptyMessage)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(listType.emptySubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - User List View
    private var userListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.users) { user in
                    VStack(spacing: 0) {
                        UserRowView(
                            userId: user.uid,
                            displayName: user.displayName,
                            avatarUrl: user.avatarUrl,
                            themeColor: themeColor,
                            showFollowButton: shouldShowFollowButton(for: user.uid)
                        )
                        
                        Divider()
                            .padding(.leading, 68) // Indent to align with name
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helpers
    
    /// Determines if follow button should be shown for a user
    /// - Don't show for current user
    private func shouldShowFollowButton(for uid: String) -> Bool {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            return true
        }
        return uid != currentUid
    }
}

// MARK: - Preview
#if DEBUG
struct UserListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserListView(
                userId: "sample_user_123",
                listType: .followers,
                themeColor: .blue
            )
        }
    }
}
#endif
