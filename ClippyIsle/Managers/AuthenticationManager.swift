import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - User Profile Model
struct UserProfile: Codable {
    var uid: String
    var nickname: String
    var referral_count: Int
    var discovery_impact: Int
    var created_at: Date
    var fcm_token: String?
    
    init(uid: String, nickname: String? = nil, referral_count: Int = 0, discovery_impact: Int = 0, created_at: Date = Date(), fcm_token: String? = nil) {
        self.uid = uid
        // Default nickname: 'User_[Last4CharsOfUID]'
        self.nickname = nickname ?? "User_\(String(uid.suffix(4)))"
        self.referral_count = referral_count
        self.discovery_impact = discovery_impact
        self.created_at = created_at
        self.fcm_token = fcm_token
    }
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: String?
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authStateListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    // Fetch user profile when auth state changes
                    self?.fetchUserProfile(uid: user.uid)
                } else {
                    self?.userProfile = nil
                }
            }
        }
    }
    
    // MARK: - Anonymous Sign In
    /// Signs in anonymously and creates/fetches user profile in Firestore
    func signInAnonymously() async throws {
        await MainActor.run { isLoading = true; authError = nil }
        
        do {
            // Check if user is already signed in
            if let existingUser = auth.currentUser {
                print("🔐 User already signed in: \(existingUser.uid)")
                await MainActor.run {
                    currentUser = existingUser
                    isAuthenticated = true
                }
                // Fetch or create user profile
                try await ensureUserProfileExists(uid: existingUser.uid)
            } else {
                // Perform anonymous sign in
                let authResult = try await auth.signInAnonymously()
                let user = authResult.user
                print("🔐 Anonymous sign in successful: \(user.uid)")
                
                await MainActor.run {
                    currentUser = user
                    isAuthenticated = true
                }
                
                // Create user profile in Firestore
                try await createUserProfile(uid: user.uid)
            }
            
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                authError = error.localizedDescription
                isLoading = false
            }
            print("🔐 Anonymous sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - User Profile Management
    
    /// Creates a new user profile in Firestore
    private func createUserProfile(uid: String) async throws {
        let profile = UserProfile(uid: uid)
        
        let docRef = db.collection(usersCollection).document(uid)
        let docSnapshot = try await docRef.getDocument()
        
        if docSnapshot.exists {
            // Profile already exists, fetch it
            await fetchUserProfile(uid: uid)
        } else {
            // Create new profile
            let profileData: [String: Any] = [
                "uid": profile.uid,
                "nickname": profile.nickname,
                "referral_count": profile.referral_count,
                "discovery_impact": profile.discovery_impact,
                "created_at": Timestamp(date: profile.created_at),
                "fcm_token": profile.fcm_token as Any
            ]
            
            try await docRef.setData(profileData)
            print("🔐 Created user profile for: \(uid)")
            
            await MainActor.run {
                userProfile = profile
            }
        }
    }
    
    /// Ensures a user profile exists, creates one if not
    private func ensureUserProfileExists(uid: String) async throws {
        let docRef = db.collection(usersCollection).document(uid)
        let docSnapshot = try await docRef.getDocument()
        
        if docSnapshot.exists {
            await fetchUserProfile(uid: uid)
        } else {
            try await createUserProfile(uid: uid)
        }
    }
    
    /// Fetches user profile from Firestore
    func fetchUserProfile(uid: String) {
        let docRef = db.collection(usersCollection).document(uid)
        
        docRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("🔐 Failed to fetch user profile: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("🔐 User profile document not found")
                return
            }
            
            DispatchQueue.main.async {
                let createdAt: Date
                if let timestamp = data["created_at"] as? Timestamp {
                    createdAt = timestamp.dateValue()
                } else {
                    createdAt = Date()
                }
                
                self?.userProfile = UserProfile(
                    uid: data["uid"] as? String ?? uid,
                    nickname: data["nickname"] as? String,
                    referral_count: data["referral_count"] as? Int ?? 0,
                    discovery_impact: data["discovery_impact"] as? Int ?? 0,
                    created_at: createdAt,
                    fcm_token: data["fcm_token"] as? String
                )
                print("🔐 Fetched user profile: \(self?.userProfile?.nickname ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Update Nickname
    /// Updates the user's nickname in Firestore
    /// - Parameter nickname: The new nickname to set
    func updateNickname(_ nickname: String) async throws {
        guard let uid = currentUser?.uid else {
            throw NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            throw NSError(domain: "AuthenticationManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Nickname cannot be empty"])
        }
        
        let docRef = db.collection(usersCollection).document(uid)
        try await docRef.updateData(["nickname": trimmedNickname])
        
        await MainActor.run {
            userProfile?.nickname = trimmedNickname
        }
        
        print("🔐 Updated nickname to: \(trimmedNickname)")
    }
    
    // MARK: - Update FCM Token
    /// Updates the user's FCM token in Firestore
    /// - Parameter token: The FCM token to store
    func updateFCMToken(_ token: String) async throws {
        guard let uid = currentUser?.uid else { return }
        
        let docRef = db.collection(usersCollection).document(uid)
        try await docRef.updateData(["fcm_token": token])
        
        await MainActor.run {
            userProfile?.fcm_token = token
        }
        
        print("🔐 Updated FCM token")
    }
    
    // MARK: - Increment Stats
    /// Increments the referral count for the user
    func incrementReferralCount() async throws {
        guard let uid = currentUser?.uid else { return }
        
        let docRef = db.collection(usersCollection).document(uid)
        try await docRef.updateData(["referral_count": FieldValue.increment(Int64(1))])
        
        await MainActor.run {
            userProfile?.referral_count += 1
        }
        
        print("🔐 Incremented referral count")
    }
    
    /// Increments the discovery impact for the user
    func incrementDiscoveryImpact() async throws {
        guard let uid = currentUser?.uid else { return }
        
        let docRef = db.collection(usersCollection).document(uid)
        try await docRef.updateData(["discovery_impact": FieldValue.increment(Int64(1))])
        
        await MainActor.run {
            userProfile?.discovery_impact += 1
        }
        
        print("🔐 Incremented discovery impact")
    }
    
    // MARK: - Get User Nickname (for sharing)
    /// Gets the display nickname for a user (for 'Shared by' feature)
    /// - Parameter uid: The user's UID
    /// - Returns: The user's nickname or a default value
    func getNickname(for uid: String) async -> String {
        let docRef = db.collection(usersCollection).document(uid)
        
        do {
            let snapshot = try await docRef.getDocument()
            if let nickname = snapshot.data()?["nickname"] as? String {
                return nickname
            }
        } catch {
            print("🔐 Failed to get nickname for \(uid): \(error.localizedDescription)")
        }
        
        return "User_\(String(uid.suffix(4)))"
    }
    
    // MARK: - Current User UID
    /// Returns the current user's UID if authenticated
    var currentUID: String? {
        return currentUser?.uid
    }
}
