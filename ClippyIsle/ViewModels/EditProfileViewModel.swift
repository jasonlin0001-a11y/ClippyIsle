//
//  EditProfileViewModel.swift
//  ClippyIsle
//
//  ViewModel for editing the current user's profile.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Edit Profile ViewModel
/// ViewModel for managing the current user's profile editing
@MainActor
class EditProfileViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var avatarUrl: String = ""
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var error: String?
    @Published var saveSuccess: Bool = false
    
    private let authManager = AuthenticationManager.shared
    
    // MARK: - Fetch Current Profile
    /// Fetches the current user's profile from Firestore
    func fetchProfile() async {
        guard let uid = authManager.currentUID else {
            error = "Not signed in"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let doc = try await db.collection(usersCollection).document(uid).getDocument()
            
            if let data = doc.data() {
                await MainActor.run {
                    self.displayName = data["nickname"] as? String ?? data["displayName"] as? String ?? "User_\(String(uid.suffix(4)))"
                    self.bio = data["bio"] as? String ?? ""
                    self.avatarUrl = data["avatar_url"] as? String ?? data["profileImageUrl"] as? String ?? ""
                    self.isLoading = false
                }
                
                print("✅ [EditProfile] Loaded profile")
            } else {
                await MainActor.run {
                    self.displayName = authManager.userProfile?.nickname ?? "User_\(String(uid.suffix(4)))"
                    self.bio = ""
                    self.avatarUrl = ""
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ [EditProfile] Fetch error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Profile
    /// Saves the updated profile to Firestore
    func saveProfile() async {
        guard let uid = authManager.currentUID else {
            error = "Not signed in"
            return
        }
        
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = "Display name cannot be empty"
            return
        }
        
        isSaving = true
        error = nil
        saveSuccess = false
        
        do {
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAvatarUrl = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var updateData: [String: Any] = [
                "nickname": trimmedName,
                "bio": trimmedBio
            ]
            
            // Only add avatar_url if it's not empty
            if !trimmedAvatarUrl.isEmpty {
                updateData["avatar_url"] = trimmedAvatarUrl
            }
            
            let docRef = db.collection(usersCollection).document(uid)
            try await docRef.updateData(updateData)
            
            // Update local AuthManager profile
            await MainActor.run {
                authManager.userProfile?.nickname = trimmedName
            }
            
            await MainActor.run {
                self.displayName = trimmedName
                self.bio = trimmedBio
                self.avatarUrl = trimmedAvatarUrl
                self.isSaving = false
                self.saveSuccess = true
            }
            
            print("✅ [EditProfile] Profile saved successfully")
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isSaving = false
            }
            print("❌ [EditProfile] Save error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Has Changes
    /// Checks if there are unsaved changes
    var hasChanges: Bool {
        guard let profile = authManager.userProfile else { return false }
        return displayName != profile.nickname
    }
}
