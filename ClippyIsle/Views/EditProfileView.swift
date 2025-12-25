//
//  EditProfileView.swift
//  ClippyIsle
//
//  View for editing the current user's profile (name, bio, avatar).
//

import SwiftUI

// MARK: - Edit Profile View
/// A view for editing the current user's profile
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = EditProfileViewModel()
    
    // State for avatar URL sheet
    @State private var showAvatarUrlSheet = false
    @State private var tempAvatarUrl = ""
    
    // UI feedback
    @State private var showSaveAlert = false
    
    let themeColor: Color
    
    var body: some View {
        Form {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    avatarEditor
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            // Profile Info Section
            Section(header: Text("Profile Information")) {
                // Display Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter your name", text: $viewModel.displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 4)
                
                // Bio
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $viewModel.bio)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.vertical, 4)
            }
            
            // Avatar URL Section (Manual Entry)
            Section(header: Text("Avatar URL"), footer: Text("Enter a direct image URL for your profile picture.")) {
                HStack {
                    TextField("https://example.com/avatar.jpg", text: $viewModel.avatarUrl)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    if !viewModel.avatarUrl.isEmpty {
                        Button {
                            viewModel.avatarUrl = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Save Button Section
            Section {
                Button {
                    Task {
                        await viewModel.saveProfile()
                        if viewModel.saveSuccess {
                            showSaveAlert = true
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving || viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .listRowBackground(themeColor.opacity(viewModel.isSaving ? 0.5 : 1.0))
                .foregroundColor(.white)
            }
            
            // Error Display
            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchProfile()
        }
        .alert("Profile Saved", isPresented: $showSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been updated successfully.")
        }
    }
    
    // MARK: - Avatar Editor
    @ViewBuilder
    private var avatarEditor: some View {
        VStack(spacing: 12) {
            ZStack {
                // Avatar Image
                if !viewModel.avatarUrl.isEmpty, let url = URL(string: viewModel.avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            avatarPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(width: 100, height: 100)
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
                
                // Edit overlay
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
                    .opacity(0.8)
            }
            
            Text("Tap to change")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            tempAvatarUrl = viewModel.avatarUrl
            showAvatarUrlSheet = true
        }
        .sheet(isPresented: $showAvatarUrlSheet) {
            avatarUrlSheet
        }
    }
    
    @ViewBuilder
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [themeColor.opacity(0.6), themeColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(viewModel.displayName.prefix(1)).uppercased())
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Avatar URL Sheet
    @ViewBuilder
    private var avatarUrlSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview
                if !tempAvatarUrl.isEmpty, let url = URL(string: tempAvatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        case .failure:
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Invalid URL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 120, height: 120)
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Avatar Image URL")
                        .font(.headline)
                    
                    TextField("https://example.com/avatar.jpg", text: $tempAvatarUrl)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Text("Enter a direct link to an image file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 30)
            .navigationTitle("Set Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showAvatarUrlSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.avatarUrl = tempAvatarUrl
                        showAvatarUrlSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        EditProfileView(themeColor: .blue)
    }
}
