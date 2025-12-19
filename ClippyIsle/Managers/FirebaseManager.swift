import Foundation
import FirebaseCore
import FirebaseFirestore
import CryptoKit

// MARK: - Share Metadata
/// Metadata about a shared clipboard, including password protection status
struct ShareMetadata {
    let hasPassword: Bool
    let sharerNickname: String?
    let itemCount: Int
}

// MARK: - Firebase Manager
class FirebaseManager {
    static let shared = FirebaseManager()
    
    private let db: Firestore
    private let collectionName = "clipboardItems"
    
    private init() {
        self.db = Firestore.firestore()
    }
    
    // MARK: - Password Hashing
    /// Hashes a password using SHA256
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Upload Items
    /// Uploads clipboard items to Firestore
    /// - Parameters:
    ///   - items: Array of ClipboardItem to upload
    ///   - completion: Result callback with success message or error
    func uploadItems(_ items: [ClipboardItem], completion: @escaping (Result<String, Error>) -> Void) {
        let batch = db.batch()
        
        for item in items {
            let docRef = db.collection(collectionName).document(item.id.uuidString)
            
            // Convert ClipboardItem to dictionary for Firestore
            let itemData: [String: Any] = [
                "id": item.id.uuidString,
                "content": item.content,
                "type": item.type,
                "timestamp": Timestamp(date: item.timestamp),
                "isPinned": item.isPinned,
                "isTrashed": item.isTrashed,
                "filename": item.filename as Any,
                "displayName": item.displayName as Any,
                "tags": item.tags as Any
            ]
            
            batch.setData(itemData, forDocument: docRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Successfully uploaded \(items.count) item(s)"))
            }
        }
    }
    
    // MARK: - Download Items
    /// Downloads clipboard items from Firestore
    /// - Parameter completion: Result callback with array of ClipboardItem or error
    func downloadItems(completion: @escaping (Result<[ClipboardItem], Error>) -> Void) {
        db.collection(collectionName).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            var items: [ClipboardItem] = []
            
            for document in documents {
                let data = document.data()
                
                guard let idString = data["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let content = data["content"] as? String,
                      let type = data["type"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp,
                      let isPinned = data["isPinned"] as? Bool,
                      let isTrashed = data["isTrashed"] as? Bool else {
                    continue
                }
                
                let item = ClipboardItem(
                    id: id,
                    content: content,
                    type: type,
                    filename: data["filename"] as? String,
                    timestamp: timestamp.dateValue(),
                    isPinned: isPinned,
                    displayName: data["displayName"] as? String,
                    isTrashed: isTrashed,
                    tags: data["tags"] as? [String],
                    fileData: nil
                )
                
                items.append(item)
            }
            
            completion(.success(items))
        }
    }
    
    // MARK: - Delete Items
    /// Deletes clipboard items from Firestore
    /// - Parameters:
    ///   - itemIds: Array of item UUIDs to delete
    ///   - completion: Result callback with success message or error
    func deleteItems(_ itemIds: [UUID], completion: @escaping (Result<String, Error>) -> Void) {
        let batch = db.batch()
        
        for itemId in itemIds {
            let docRef = db.collection(collectionName).document(itemId.uuidString)
            batch.deleteDocument(docRef)
        }
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Successfully deleted \(itemIds.count) item(s)"))
            }
        }
    }
    
    // MARK: - Share Items
    /// Creates a shareable link for clipboard items by uploading to Firestore
    /// - Parameters:
    ///   - items: Array of ClipboardItem to share
    ///   - password: Optional password for protecting the share
    ///   - completion: Result callback with shareable URL string or error
    func shareItems(_ items: [ClipboardItem], password: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert items to array of dictionaries
        var itemsData: [[String: Any]] = []
        
        for item in items {
            let itemData: [String: Any] = [
                "id": item.id.uuidString,
                "content": item.content,
                "type": item.type,
                "timestamp": Timestamp(date: item.timestamp),
                "isPinned": item.isPinned,
                "isTrashed": item.isTrashed,
                "filename": item.filename as Any,
                "displayName": item.displayName as Any,
                "tags": item.tags as Any
            ]
            itemsData.append(itemData)
        }
        
        // Get current user info for "Shared by" feature
        let authManager = AuthenticationManager.shared
        let sharerUID = authManager.currentUID
        let sharerNickname = authManager.userProfile?.nickname
        
        // Create a new document in sharedClipboards collection
        var shareData: [String: Any] = [
            "items": itemsData,
            "createdAt": Timestamp(date: Date()),
            "itemCount": items.count
        ]
        
        // Add sharer info if available
        if let uid = sharerUID {
            shareData["sharerUID"] = uid
        }
        if let nickname = sharerNickname {
            shareData["sharerNickname"] = nickname
        }
        
        // Add password hash if password is provided
        if let password = password, !password.isEmpty {
            shareData["passwordHash"] = hashPassword(password)
        }
        
        // Add document and get auto-generated ID
        let docRef = db.collection("sharedClipboards").document()
        docRef.setData(shareData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Generate shareable link with Firebase Hosting URL for Open Graph preview support
                let shareId = docRef.documentID
                let shareURL = "https://cc-isle.web.app/share?id=\(shareId)"
                completion(.success(shareURL))
            }
        }
    }
    
    // MARK: - Get Share Metadata
    /// Fetches metadata about a shared clipboard to check if it requires a password
    /// - Parameters:
    ///   - shareId: The share document ID to fetch metadata for
    ///   - completion: Result callback with ShareMetadata or error
    func getShareMetadata(shareId: String, completion: @escaping (Result<ShareMetadata, Error>) -> Void) {
        db.collection("sharedClipboards").document(shareId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "FirebaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Share not found"])))
                return
            }
            
            let hasPassword = data["passwordHash"] != nil
            let sharerNickname = data["sharerNickname"] as? String
            let itemCount = data["itemCount"] as? Int ?? 0
            
            let metadata = ShareMetadata(hasPassword: hasPassword, sharerNickname: sharerNickname, itemCount: itemCount)
            completion(.success(metadata))
        }
    }
    
    // MARK: - Download Items with Password
    /// Downloads shared clipboard items data from Firestore by share ID with password verification
    /// - Parameters:
    ///   - shareId: The share document ID to fetch
    ///   - password: The password to verify (nil if no password protection)
    ///   - completion: Result callback with array of raw item dictionaries or error
    func downloadItems(byShareId shareId: String, password: String?, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        db.collection("sharedClipboards").document(shareId).getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "FirebaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Share not found"])))
                return
            }
            
            // Check password if required
            if let storedHash = data["passwordHash"] as? String {
                guard let password = password, !password.isEmpty else {
                    completion(.failure(NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Password required"])))
                    return
                }
                
                guard let strongSelf = self else {
                    completion(.failure(NSError(domain: "FirebaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal error"])))
                    return
                }
                
                let providedHash = strongSelf.hashPassword(password)
                if providedHash != storedHash {
                    completion(.failure(NSError(domain: "FirebaseManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Incorrect password"])))
                    return
                }
            }
            
            // Extract items array from the shared document
            guard let itemsData = data["items"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "FirebaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid share data"])))
                return
            }
            
            // Return raw data for caller to process
            completion(.success(itemsData))
        }
    }
}
