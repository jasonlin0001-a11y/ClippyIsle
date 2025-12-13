import Foundation
import FirebaseCore
import FirebaseFirestore

// MARK: - Firebase Manager
class FirebaseManager {
    static let shared = FirebaseManager()
    
    private let db: Firestore
    private let collectionName = "clipboardItems"
    
    private init() {
        self.db = Firestore.firestore()
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
}
