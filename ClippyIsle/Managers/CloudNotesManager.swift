//
//  CloudNotesManager.swift
//  ClippyIsle
//
//  Manages Cloud Notes inbox and email binding operations.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Cloud Inbox Item Model
struct CloudInboxItem: Identifiable, Codable {
    let id: String
    let content: String
    let subject: String
    let from: String
    let receivedAt: Date
    var isProcessed: Bool
    
    init(id: String, content: String, subject: String, from: String, receivedAt: Date, isProcessed: Bool = false) {
        self.id = id
        self.content = content
        self.subject = subject
        self.from = from
        self.receivedAt = receivedAt
        self.isProcessed = isProcessed
    }
    
    init?(documentID: String, data: [String: Any]) {
        guard let content = data["content"] as? String,
              let subject = data["subject"] as? String,
              let from = data["from"] as? String,
              let isProcessed = data["isProcessed"] as? Bool else {
            return nil
        }
        
        let receivedAt: Date
        if let timestamp = data["receivedAt"] as? Timestamp {
            receivedAt = timestamp.dateValue()
        } else {
            receivedAt = Date()
        }
        
        self.id = documentID
        self.content = content
        self.subject = subject
        self.from = from
        self.receivedAt = receivedAt
        self.isProcessed = isProcessed
    }
}

// MARK: - Cloud Notes Manager
@MainActor
class CloudNotesManager: ObservableObject {
    static let shared = CloudNotesManager()
    
    private let db = Firestore.firestore()
    private let emailMappingCollection = "email_mapping"
    
    // Email validation regex pattern
    private static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    private static let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    
    // Published state
    @Published var inboxItems: [CloudInboxItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var boundEmail: String?
    @Published var isBindingEmail: Bool = false
    @Published var bindingError: String?
    @Published var bindingSuccess: Bool = false
    
    // Listener for real-time updates
    private var inboxListener: ListenerRegistration?
    
    // Forwarding email address (constant)
    let forwardingEmail = "save@note.ccisle.app"
    
    private init() {}
    
    deinit {
        // Directly remove listener instead of calling stopListening()
        // since deinit is a nonisolated context and cannot call @MainActor methods
        inboxListener?.remove()
    }
    
    // MARK: - Email Binding
    
    /// Binds a user email to their UID in the email_mapping collection
    /// - Parameters:
    ///   - email: The user's email address to bind
    ///   - uid: The user's Firebase UID
    func bindEmail(_ email: String, uid: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "CloudNotesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Email cannot be empty"])
        }
        
        // Email format validation using regex
        guard Self.emailPredicate.evaluate(with: trimmedEmail) else {
            throw NSError(domain: "CloudNotesManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid email format"])
        }
        
        isBindingEmail = true
        bindingError = nil
        bindingSuccess = false
        
        do {
            let docRef = db.collection(emailMappingCollection).document(trimmedEmail)
            try await docRef.setData(["uid": uid])
            
            boundEmail = trimmedEmail
            bindingSuccess = true
            isBindingEmail = false
            
            print("✅ Successfully bound email: \(trimmedEmail) to UID: \(uid)")
        } catch {
            isBindingEmail = false
            bindingError = error.localizedDescription
            throw error
        }
    }
    
    /// Resets the binding state to allow binding a new email
    func resetBindingState() {
        boundEmail = nil
        bindingSuccess = false
        bindingError = nil
    }
    
    /// Checks if an email is already bound to the current user
    /// - Parameters:
    ///   - email: The email to check
    ///   - uid: The user's UID
    /// - Returns: True if the email is bound to this user
    func checkEmailBinding(email: String, uid: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedEmail.isEmpty else { return false }
        
        do {
            let docRef = db.collection(emailMappingCollection).document(trimmedEmail)
            let snapshot = try await docRef.getDocument()
            
            if let data = snapshot.data(), let boundUID = data["uid"] as? String {
                return boundUID == uid
            }
        } catch {
            print("❌ Failed to check email binding: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // MARK: - Inbox Operations
    
    /// Starts listening to the user's inbox for real-time updates
    /// - Parameter uid: The user's Firebase UID
    func startListening(uid: String) {
        // Stop any existing listener
        stopListening()
        
        isLoading = true
        error = nil
        
        let inboxRef = db.collection("users").document(uid).collection("inbox")
        
        // Use a simple query without ordering to avoid requiring a composite index
        // We'll sort the results client-side
        inboxListener = inboxRef
            .whereField("isProcessed", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task {
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
                        print("❌ Inbox listener error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.inboxItems = []
                        return
                    }
                    
                    // Parse items and sort client-side by receivedAt descending
                    var items = documents.compactMap { doc in
                        CloudInboxItem(documentID: doc.documentID, data: doc.data())
                    }
                    items.sort { $0.receivedAt > $1.receivedAt }
                    self.inboxItems = items
                    
                    print("📬 Inbox updated: \(self.inboxItems.count) items")
                }
            }
    }
    
    /// Stops listening to inbox updates
    func stopListening() {
        inboxListener?.remove()
        inboxListener = nil
    }
    
    /// Marks an inbox item as processed (logical delete)
    /// - Parameters:
    ///   - item: The inbox item to mark as processed
    ///   - uid: The user's Firebase UID
    func markAsProcessed(_ item: CloudInboxItem, uid: String) async throws {
        let docRef = db.collection("users").document(uid).collection("inbox").document(item.id)
        try await docRef.updateData(["isProcessed": true])
        
        print("✅ Marked item as processed: \(item.id)")
    }
    
    /// Fetches inbox items once (non-realtime)
    /// - Parameter uid: The user's Firebase UID
    func fetchInbox(uid: String) async {
        isLoading = true
        error = nil
        
        do {
            let inboxRef = db.collection("users").document(uid).collection("inbox")
            // Use a simple query without ordering to avoid requiring a composite index
            let snapshot = try await inboxRef
                .whereField("isProcessed", isEqualTo: false)
                .getDocuments()
            
            // Parse items and sort client-side by receivedAt descending
            var items = snapshot.documents.compactMap { doc in
                CloudInboxItem(documentID: doc.documentID, data: doc.data())
            }
            items.sort { $0.receivedAt > $1.receivedAt }
            inboxItems = items
            
            isLoading = false
            print("📬 Fetched \(inboxItems.count) inbox items")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ Failed to fetch inbox: \(error.localizedDescription)")
        }
    }
}
