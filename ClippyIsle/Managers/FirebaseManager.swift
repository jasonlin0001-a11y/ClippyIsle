import Foundation
import CryptoKit

// MARK: - Share Error Types
enum ShareError: Error, LocalizedError {
    case passwordRequired(encryptedData: String)
    case decryptionFailed
    case encryptionFailed
    case uploadFailed
    case downloadFailed
    case invalidPassword
    case noDataFound
    
    var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return "Password required to decrypt this share"
        case .decryptionFailed:
            return "Failed to decrypt the data. Please check your password."
        case .encryptionFailed:
            return "Failed to encrypt the data"
        case .uploadFailed:
            return "Failed to upload data to Firebase"
        case .downloadFailed:
            return "Failed to download data from Firebase"
        case .invalidPassword:
            return "Invalid password provided"
        case .noDataFound:
            return "No data found for the given share ID"
        }
    }
}

// MARK: - Firebase Manager
class FirebaseManager {
    static let shared = FirebaseManager()
    
    // Test mode storage - simulates Firebase database
    private var testDatabase: [String: [String: Any]] = [:]
    
    private init() {}
    
    // MARK: - Private Encryption Helper Functions
    
    /// Derives a SymmetricKey from a user-provided password using SHA256
    private func deriveKey(from password: String) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let hash = SHA256.hash(data: passwordData)
        return SymmetricKey(data: hash)
    }
    
    /// Encrypts data and returns a Base64-encoded string
    private func encrypt(data: Data, key: SymmetricKey) -> Result<String, Error> {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                return .failure(ShareError.encryptionFailed)
            }
            return .success(combined.base64EncodedString())
        } catch {
            return .failure(error)
        }
    }
    
    /// Decrypts a Base64-encoded string and returns Data
    private func decrypt(base64String: String, key: SymmetricKey) -> Result<Data, Error> {
        guard let combinedData = Data(base64Encoded: base64String) else {
            return .failure(ShareError.decryptionFailed)
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return .success(decryptedData)
        } catch {
            return .failure(ShareError.decryptionFailed)
        }
    }
    
    // MARK: - Public API Functions
    
    /// Shares clipboard items with optional password protection
    /// - Parameters:
    ///   - items: Array of ClipboardItem to share
    ///   - password: Optional password for encryption
    ///   - completion: Completion handler with share URL or error
    func shareItems(_ items: [ClipboardItem], password: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert items to dictionary array for JSON serialization
        let itemDicts = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "id": item.id.uuidString,
                "content": item.content,
                "type": item.type,
                "timestamp": item.timestamp.timeIntervalSince1970,
                "isPinned": item.isPinned,
                "isTrashed": item.isTrashed
            ]
            if let displayName = item.displayName {
                dict["displayName"] = displayName
            }
            if let filename = item.filename {
                dict["filename"] = filename
            }
            if let tags = item.tags {
                dict["tags"] = tags
            }
            return dict
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: itemDicts, options: [])
            
            // Prepare payload based on whether password is provided
            let payload: [String: Any]
            if let password = password, !password.isEmpty {
                // Encrypt the data
                let key = deriveKey(from: password)
                switch encrypt(data: jsonData, key: key) {
                case .success(let encryptedString):
                    payload = [
                        "isEncrypted": true,
                        "encryptedData": encryptedString,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            } else {
                // Plain JSON without encryption
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    completion(.failure(ShareError.encryptionFailed))
                    return
                }
                payload = [
                    "isEncrypted": false,
                    "data": jsonString,
                    "timestamp": Date().timeIntervalSince1970
                ]
            }
            
            // TODO: Upload payload to Firebase Firestore
            // For now, using test mode with in-memory storage
            // Once Firebase is integrated, this should:
            // 1. Create a new document in Firestore
            // 2. Get the document ID
            // 3. Return a deep link URL with the document ID
            
            // Test mode implementation - store in memory
            let shareID = UUID().uuidString
            testDatabase[shareID] = payload
            let shareURL = "\(deepLinkScheme)://\(deepLinkImportHost)?id=\(shareID)"
            
            print("📤 Share payload stored in test mode:")
            print("  Share ID: \(shareID)")
            print("  Encrypted: \(payload["isEncrypted"] as? Bool ?? false)")
            print("  Share URL: \(shareURL)")
            
            // Simulate async upload
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success(shareURL))
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Downloads items from Firebase using share ID
    /// - Parameters:
    ///   - shareID: The share identifier from the deep link
    ///   - completion: Completion handler with result
    func downloadItems(shareID: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        // TODO: Download document from Firebase Firestore using shareID
        // For now, using test mode with in-memory storage
        // Once Firebase is integrated, this should:
        // 1. Fetch the document from Firestore using shareID
        // 2. Check the isEncrypted flag
        // 3. If encrypted, return passwordRequired error with encryptedData
        // 4. If not encrypted, parse and return the items
        
        print("📥 Download requested for share ID: \(shareID)")
        
        // Test mode: retrieve from in-memory storage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let payload = self.testDatabase[shareID] else {
                print("❌ Share ID not found in test database")
                completion(.failure(ShareError.noDataFound))
                return
            }
            
            let isEncrypted = payload["isEncrypted"] as? Bool ?? false
            
            if isEncrypted {
                // Return password required error with encrypted data
                guard let encryptedData = payload["encryptedData"] as? String else {
                    completion(.failure(ShareError.downloadFailed))
                    return
                }
                print("🔒 Encrypted share - password required")
                completion(.failure(ShareError.passwordRequired(encryptedData: encryptedData)))
            } else {
                // Parse and return unencrypted data
                guard let dataString = payload["data"] as? String,
                      let jsonData = dataString.data(using: .utf8),
                      let itemDicts = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                    completion(.failure(ShareError.downloadFailed))
                    return
                }
                print("✅ Unencrypted share - returning \(itemDicts.count) items")
                completion(.success(itemDicts))
            }
        }
    }
    
    /// Decrypts shared data after user provides password
    /// - Parameters:
    ///   - encryptedData: Base64-encoded encrypted data string
    ///   - password: User-provided password
    /// - Returns: Result with decrypted items array or error
    func decryptSharedData(_ encryptedData: String, password: String) -> Result<[[String: Any]], Error> {
        let key = deriveKey(from: password)
        
        switch decrypt(base64String: encryptedData, key: key) {
        case .success(let decryptedData):
            do {
                guard let itemDicts = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [[String: Any]] else {
                    return .failure(ShareError.decryptionFailed)
                }
                return .success(itemDicts)
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}
