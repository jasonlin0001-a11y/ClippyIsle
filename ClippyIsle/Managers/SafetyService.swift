//
//  SafetyService.swift
//  ClippyIsle
//
//  Service for managing user safety: Blocking and Reporting.
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Report Model
/// Represents a report submitted by a user
struct Report: Codable {
    var id: String
    var reporterId: String
    var reporterName: String
    var postId: String?
    var reportedUserId: String?
    var reason: ReportReason
    var description: String?
    var timestamp: Date
    var status: ReportStatus
    
    enum ReportReason: String, Codable, CaseIterable {
        case spam = "spam"
        case harassment = "harassment"
        case inappropriateContent = "inappropriate_content"
        case misinformation = "misinformation"
        case copyright = "copyright"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .spam: return "Spam / 垃圾訊息"
            case .harassment: return "Harassment / 騷擾"
            case .inappropriateContent: return "Inappropriate Content / 不當內容"
            case .misinformation: return "Misinformation / 不實資訊"
            case .copyright: return "Copyright Violation / 侵權"
            case .other: return "Other / 其他"
            }
        }
    }
    
    enum ReportStatus: String, Codable {
        case pending = "pending"
        case reviewed = "reviewed"
        case resolved = "resolved"
        case dismissed = "dismissed"
    }
}

// MARK: - Blocked User Model
/// Represents a blocked user
struct BlockedUser: Codable, Identifiable {
    var id: String  // The blocked user's UID
    var displayName: String
    var blockedAt: Date
}

// MARK: - Safety Service
/// Manages user safety features: blocking and reporting
@MainActor
class SafetyService: ObservableObject {
    static let shared = SafetyService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let reportsCollection = "reports"
    private let blockedUsersSubcollection = "blocked_users"
    
    /// Set of blocked user IDs for quick filtering
    @Published var blockedUserIds: Set<String> = []
    
    /// List of blocked users (for settings display)
    @Published var blockedUsers: [BlockedUser] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    private var blockedUsersListener: ListenerRegistration?
    
    private init() {}
    
    deinit {
        blockedUsersListener?.remove()
    }
    
    // MARK: - Report Post
    /// Reports a post to the admin review queue
    func reportPost(postId: String, reason: Report.ReportReason, description: String? = nil) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SafetyError.noAuthenticatedUser
        }
        
        let reporterName = AuthenticationManager.shared.userProfile?.nickname ?? "Anonymous"
        
        let report = Report(
            id: UUID().uuidString,
            reporterId: currentUid,
            reporterName: reporterName,
            postId: postId,
            reportedUserId: nil,
            reason: reason,
            description: description,
            timestamp: Date(),
            status: .pending
        )
        
        let data: [String: Any] = [
            "id": report.id,
            "reporterId": report.reporterId,
            "reporterName": report.reporterName,
            "postId": report.postId ?? NSNull(),
            "reportedUserId": report.reportedUserId ?? NSNull(),
            "reason": report.reason.rawValue,
            "description": report.description ?? NSNull(),
            "timestamp": Timestamp(date: report.timestamp),
            "status": report.status.rawValue
        ]
        
        // Path: reports/{reportId}
        let reportDocRef = db.collection(reportsCollection).document(report.id)
        
        try await reportDocRef.setData(data)
        
        print("🚨 [SafetyService] Report submitted for post: \(postId), reason: \(reason.rawValue)")
    }
    
    // MARK: - Report User
    /// Reports a user to the admin review queue
    func reportUser(userId: String, reason: Report.ReportReason, description: String? = nil) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SafetyError.noAuthenticatedUser
        }
        
        let reporterName = AuthenticationManager.shared.userProfile?.nickname ?? "Anonymous"
        
        let report = Report(
            id: UUID().uuidString,
            reporterId: currentUid,
            reporterName: reporterName,
            postId: nil,
            reportedUserId: userId,
            reason: reason,
            description: description,
            timestamp: Date(),
            status: .pending
        )
        
        let data: [String: Any] = [
            "id": report.id,
            "reporterId": report.reporterId,
            "reporterName": report.reporterName,
            "postId": report.postId ?? NSNull(),
            "reportedUserId": report.reportedUserId ?? NSNull(),
            "reason": report.reason.rawValue,
            "description": report.description ?? NSNull(),
            "timestamp": Timestamp(date: report.timestamp),
            "status": report.status.rawValue
        ]
        
        // Path: reports/{reportId}
        let reportDocRef = db.collection(reportsCollection).document(report.id)
        
        try await reportDocRef.setData(data)
        
        print("🚨 [SafetyService] Report submitted for user: \(userId), reason: \(reason.rawValue)")
    }
    
    // MARK: - Block User
    /// Blocks a user, hiding all their content from the current user
    func blockUser(targetUid: String, displayName: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SafetyError.noAuthenticatedUser
        }
        
        // Prevent blocking self
        guard targetUid != currentUid else {
            throw SafetyError.cannotBlockSelf
        }
        
        // Optimistic update
        blockedUserIds.insert(targetUid)
        
        let blockedUser = BlockedUser(
            id: targetUid,
            displayName: displayName,
            blockedAt: Date()
        )
        
        do {
            let data: [String: Any] = [
                "id": blockedUser.id,
                "displayName": blockedUser.displayName,
                "blockedAt": Timestamp(date: blockedUser.blockedAt)
            ]
            
            // Path: users/{currentUid}/blocked_users/{targetUid}
            let blockedDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(blockedUsersSubcollection)
                .document(targetUid)
            
            try await blockedDocRef.setData(data)
            
            // Add to local list
            blockedUsers.insert(blockedUser, at: 0)
            
            print("🚫 [SafetyService] Blocked user: \(targetUid) (\(displayName))")
        } catch {
            // Revert optimistic update
            blockedUserIds.remove(targetUid)
            print("❌ [SafetyService] Block failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Unblock User
    /// Unblocks a user, restoring their content visibility
    func unblockUser(targetUid: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SafetyError.noAuthenticatedUser
        }
        
        // Optimistic update
        let removedUser = blockedUsers.first { $0.id == targetUid }
        blockedUserIds.remove(targetUid)
        blockedUsers.removeAll { $0.id == targetUid }
        
        do {
            // Path: users/{currentUid}/blocked_users/{targetUid}
            let blockedDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(blockedUsersSubcollection)
                .document(targetUid)
            
            try await blockedDocRef.delete()
            
            print("✅ [SafetyService] Unblocked user: \(targetUid)")
        } catch {
            // Revert optimistic update
            blockedUserIds.insert(targetUid)
            if let user = removedUser {
                blockedUsers.insert(user, at: 0)
            }
            print("❌ [SafetyService] Unblock failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Check If Blocked
    /// Returns true if the user is blocked
    func isUserBlocked(userId: String) -> Bool {
        return blockedUserIds.contains(userId)
    }
    
    // MARK: - Load Blocked Users
    /// Loads the list of blocked users from Firestore
    func loadBlockedUsers() async {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection(usersCollection)
                .document(currentUid)
                .collection(blockedUsersSubcollection)
                .order(by: "blockedAt", descending: true)
                .getDocuments()
            
            var users: [BlockedUser] = []
            var ids: Set<String> = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let displayName = data["displayName"] as? String,
                      let blockedAt = data["blockedAt"] as? Timestamp else {
                    continue
                }
                
                let blockedUser = BlockedUser(
                    id: id,
                    displayName: displayName,
                    blockedAt: blockedAt.dateValue()
                )
                
                users.append(blockedUser)
                ids.insert(id)
            }
            
            blockedUsers = users
            blockedUserIds = ids
            isLoading = false
            
            print("✅ [SafetyService] Loaded \(users.count) blocked users")
        } catch {
            isLoading = false
            print("❌ [SafetyService] Load blocked users failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Listen to Blocked Users (Real-time)
    /// Sets up a real-time listener for blocked users
    func listenToBlockedUsers() {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        blockedUsersListener?.remove()
        
        blockedUsersListener = db.collection(usersCollection)
            .document(currentUid)
            .collection(blockedUsersSubcollection)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [SafetyService] Blocked users listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                var users: [BlockedUser] = []
                var ids: Set<String> = []
                
                for doc in documents {
                    let data = doc.data()
                    guard let id = data["id"] as? String,
                          let displayName = data["displayName"] as? String,
                          let blockedAt = data["blockedAt"] as? Timestamp else {
                        continue
                    }
                    
                    let blockedUser = BlockedUser(
                        id: id,
                        displayName: displayName,
                        blockedAt: blockedAt.dateValue()
                    )
                    
                    users.append(blockedUser)
                    ids.insert(id)
                }
                
                // Sort by blockedAt descending
                users.sort { $0.blockedAt > $1.blockedAt }
                
                Task { @MainActor in
                    self.blockedUsers = users
                    self.blockedUserIds = ids
                }
            }
    }
    
    // MARK: - Filter Posts
    /// Filters out posts from blocked users
    func filterBlockedContent<T: Collection>(_ posts: T, creatorIdKeyPath: KeyPath<T.Element, String>) -> [T.Element] {
        return posts.filter { !blockedUserIds.contains($0[keyPath: creatorIdKeyPath]) }
    }
    
    // MARK: - Cleanup
    func removeListeners() {
        blockedUsersListener?.remove()
        blockedUsersListener = nil
    }
}

// MARK: - Safety Error
enum SafetyError: Error, LocalizedError {
    case noAuthenticatedUser
    case cannotBlockSelf
    case networkError(String)
    case invalidReport
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "You must be signed in to use safety features"
        case .cannotBlockSelf:
            return "You cannot block yourself"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidReport:
            return "Invalid report data"
        }
    }
}
