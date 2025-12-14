import SwiftUI
import CloudKit
import Combine

// MARK: - CloudKit Manager
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    private let container = CKContainer.default()
    private lazy var database = container.privateCloudDatabase
    
    @Published var iCloudStatus: String = "Checking..."
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil

    private init() {
        checkAccountStatus()
    }
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available: self?.iCloudStatus = "Available"
                case .noAccount: self?.iCloudStatus = "No Account"
                case .restricted: self?.iCloudStatus = "Restricted"
                case .couldNotDetermine: self?.iCloudStatus = "Unknown"
                case .temporarilyUnavailable: self?.iCloudStatus = "Temporarily Unavailable"
                @unknown default: self?.iCloudStatus = "Unknown"
                }
            }
        }
    }
    
    // MARK: - Conversion Methods
    private func recordID(for item: ClipboardItem) -> CKRecord.ID {
        return CKRecord.ID(recordName: item.id.uuidString)
    }
    
    private func createRecord(from item: ClipboardItem) -> CKRecord {
        let recordID = recordID(for: item)
        let record = CKRecord(recordType: "ClipboardItem", recordID: recordID)
        
        record["content"] = item.content
        record["type"] = item.type
        record["timestamp"] = item.timestamp
        record["isPinned"] = item.isPinned ? 1 : 0
        record["isTrashed"] = item.isTrashed ? 1 : 0
        if let name = item.displayName { record["displayName"] = name }
        if let tags = item.tags { record["tags"] = tags }
        
        if let filename = item.filename,
           let containerURL = ClipboardManager.shared.getSharedContainerURL() {
            let fileURL = containerURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                record["asset"] = CKAsset(fileURL: fileURL)
                record["filename"] = filename
            } else {
                print("⚠️ Warning: Asset file \(filename) missing for item \(item.id)")
            }
        }
        return record
    }
    
    private func item(from record: CKRecord) -> ClipboardItem? {
        guard let content = record["content"] as? String,
              let type = record["type"] as? String,
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }
        
        let idString = record.recordID.recordName
        guard let id = UUID(uuidString: idString) else { return nil }
        
        let isPinned = (record["isPinned"] as? Int == 1)
        let isTrashed = (record["isTrashed"] as? Int == 1)
        let displayName = record["displayName"] as? String
        let tags = record["tags"] as? [String]
        var filename = record["filename"] as? String
        
        if let asset = record["asset"] as? CKAsset, let fileURL = asset.fileURL {
            if let savedFilename = ClipboardManager.shared.saveAssetToAppGroup(from: fileURL, originalFilename: filename) {
                filename = savedFilename
            }
        }
        
        return ClipboardItem(id: id, content: content, type: type, filename: filename, timestamp: timestamp, isPinned: isPinned, displayName: displayName, isTrashed: isTrashed, tags: tags)
    }
    
    /// Safe item conversion wrapper.
    /// This is a simple wrapper around item(from:) that ensures no exceptions propagate.
    /// The item(from:) method already handles validation by returning nil for invalid records.
    private func safeItem(from record: CKRecord) -> ClipboardItem? {
        // The item(from:) method already handles validation and returns nil for invalid records
        // This wrapper exists for semantic clarity when processing potentially corrupt data
        return item(from: record)
    }
    
    // MARK: - CRUD Operations
    func save(item: ClipboardItem) {
        guard iCloudStatus == "Available" else { return }
        let record = createRecord(from: item)
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .changedKeys
        modifyOp.modifyRecordsResultBlock = { result in
            switch result {
            case .success: print("☁️ Saved item \(item.id) to CloudKit.")
            case .failure(let error): print("☁️ CloudKit Save Error: \(error.localizedDescription)")
            }
        }
        database.add(modifyOp)
    }
    
    func delete(itemID: UUID) {
        guard iCloudStatus == "Available" else { return }
        let id = CKRecord.ID(recordName: itemID.uuidString)
        database.delete(withRecordID: id) { _, error in
            if let error = error { print("☁️ CloudKit Delete Error: \(error.localizedDescription)") }
            else { print("☁️ Deleted item \(itemID) from CloudKit.") }
        }
    }
    
    // MARK: - Helpers for Pagination
<<<<<<< HEAD
    /// Maximum number of items to fetch during initial sync to prevent sync storms
    private let initialSyncLimit = 20
    
    /// Fetches records with pagination, optionally limiting to a specific count for initial sync
    /// - Parameter limitToInitialSync: If true, only fetches up to `initialSyncLimit` items (sorted by most recent first)
    private func fetchRecords(limitToInitialSync: Bool = false) async throws -> [CKRecord] {
=======
    // Fetch records with optional limit for pagination (default: fetch all)
    private func fetchRecords(limit: Int? = nil) async throws -> [CKRecord] {
>>>>>>> copilot/replace-export-with-firebase-share
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: "ClipboardItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            let (matchResults, nextCursor) = try await cursor == nil ?
                database.records(matching: query) :
                database.records(continuingMatchFrom: cursor!)
            
            cursor = nextCursor
            
            for result in matchResults {
                if case .success(let record) = result.1 {
                    allRecords.append(record)
<<<<<<< HEAD
                    
                    // If limiting to initial sync, stop once we have enough records
                    if limitToInitialSync && allRecords.count >= initialSyncLimit {
                        print("☁️ Reached initial sync limit of \(initialSyncLimit) items, stopping fetch.")
=======
                    // Stop early if we've reached the limit
                    if let limit = limit, allRecords.count >= limit {
>>>>>>> copilot/replace-export-with-firebase-share
                        return allRecords
                    }
                }
            }
        } while cursor != nil
        
        return allRecords
    }
    
<<<<<<< HEAD
    // Legacy method maintained for backwards compatibility - fetches all records
    private func fetchAllRecords() async throws -> [CKRecord] {
        return try await fetchRecords(limitToInitialSync: false)
    }
    
    // MARK: - Synchronization
    /// Syncs local items with CloudKit, with optional limit for initial sync
    /// - Parameters:
    ///   - localItems: The local clipboard items to sync
    ///   - isInitialSync: If true, limits fetched cloud items to prevent sync storms on app launch
    func sync(localItems: [ClipboardItem], isInitialSync: Bool = false) async -> [ClipboardItem] {
=======
    // Legacy method for backward compatibility - fetches all records
    private func fetchAllRecords() async throws -> [CKRecord] {
        return try await fetchRecords(limit: nil)
    }
    
    // MARK: - Synchronization
    /// Sync with cloud with optional limit for initial sync (to prevent app freeze)
    /// - Parameters:
    ///   - localItems: Local clipboard items to sync
    ///   - initialSyncLimit: Maximum number of cloud items to fetch on initial sync (nil = fetch all)
    /// - Returns: Merged items after sync
    func sync(localItems: [ClipboardItem], initialSyncLimit: Int? = nil) async -> [ClipboardItem] {
>>>>>>> copilot/replace-export-with-firebase-share
        guard iCloudStatus == "Available" else { return localItems }
        
        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false; lastSyncDate = Date() } }
        
        do {
<<<<<<< HEAD
            // 1. Fetch cloud records (limited if initial sync to prevent sync storms)
            let cloudRecords = try await fetchRecords(limitToInitialSync: isInitialSync)
=======
            // 1. 獲取雲端資料 (with optional limit for initial sync)
            let cloudRecords = try await fetchRecords(limit: initialSyncLimit)
>>>>>>> copilot/replace-export-with-firebase-share
            
            var cloudItems: [ClipboardItem] = []
            var skippedCount = 0
            for record in cloudRecords {
<<<<<<< HEAD
                // Safe decoding: Use optional conversion to skip corrupt/zombie items silently
                if let item = safeItem(from: record) {
                    cloudItems.append(item)
                } else {
                    skippedCount += 1
                    print("☁️ ⚠️ Skipped corrupt/undecodable cloud record: \(record.recordID.recordName)")
                }
            }
            if skippedCount > 0 {
                print("☁️ Skipped \(skippedCount) corrupt/zombie items during sync.")
            }
            print("☁️ Fetched \(cloudItems.count) valid items from Cloud\(isInitialSync ? " (limited to \(initialSyncLimit) for initial sync)" : " (Total)").")
=======
                // Safe decoding: Skip corrupt/zombie items silently
                if let item = item(from: record) {
                    cloudItems.append(item)
                } else {
                    print("⚠️ CloudKit: Skipped corrupt/incompatible record: \(record.recordID.recordName)")
                }
            }
            print("☁️ Fetched \(cloudItems.count) items from Cloud (limit: \(initialSyncLimit?.description ?? "none")).")
>>>>>>> copilot/replace-export-with-firebase-share
            
            var mergedItems = localItems
            let cloudIDMap = Dictionary(uniqueKeysWithValues: cloudItems.map { ($0.id, $0) })
            let localIDMap = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
            
            // 收集需要批次更新到雲端的紀錄
            var recordsToSave: [CKRecord] = []
            
            // 2. 比對雲端資料 -> 更新本地
            for cloudItem in cloudItems {
                if let localItem = localIDMap[cloudItem.id] {
                    // 衝突解決：誰的時間戳記新，就聽誰的
                    if cloudItem.timestamp > localItem.timestamp {
                        if let index = mergedItems.firstIndex(where: { $0.id == cloudItem.id }) {
                            mergedItems[index] = cloudItem
                        }
                    } else if localItem.timestamp > cloudItem.timestamp {
                        // 本地比較新，準備上傳
                        recordsToSave.append(createRecord(from: localItem))
                    }
                } else {
                    // 本地沒有，直接加入
                    mergedItems.append(cloudItem)
                }
            }
            
            // 3. 比對本地資料 -> 上傳新資料
            for localItem in localItems {
                if cloudIDMap[localItem.id] == nil {
                    recordsToSave.append(createRecord(from: localItem))
                }
            }
            
            // 4. 執行批次上傳 (如果有的話)
            if !recordsToSave.isEmpty {
                print("☁️ Batch uploading \(recordsToSave.count) records...")
                let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                modifyOp.savePolicy = .changedKeys
                
                // 確保上傳完成
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️ Batch upload successful.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️ Batch upload failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(modifyOp)
                }
            }
            
            // 5. 回傳排序後的結果
            return mergedItems.sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.timestamp > $1.timestamp
            }
            
        } catch {
            print("☁️ CloudKit Sync Failed: \(error)")
            return localItems
        }
    }
    
    // MARK: - Tag Color Synchronization
    private func createTagColorRecord(from tagColor: TagColor) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "tagColor_\(tagColor.tag)")
        let record = CKRecord(recordType: "TagColor", recordID: recordID)
        record["tag"] = tagColor.tag
        record["red"] = tagColor.red
        record["green"] = tagColor.green
        record["blue"] = tagColor.blue
        return record
    }
    
    private func tagColor(from record: CKRecord) -> TagColor? {
        guard let tag = record["tag"] as? String,
              let red = record["red"] as? Double,
              let green = record["green"] as? Double,
              let blue = record["blue"] as? Double else {
            return nil
        }
        return TagColor(tag: tag, red: red, green: green, blue: blue)
    }
    
    private func fetchAllTagColorRecords() async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: "TagColor", predicate: NSPredicate(value: true))
        
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            let (matchResults, nextCursor) = try await cursor == nil ?
                database.records(matching: query) :
                database.records(continuingMatchFrom: cursor!)
            
            cursor = nextCursor
            
            for result in matchResults {
                if case .success(let record) = result.1 {
                    allRecords.append(record)
                }
            }
        } while cursor != nil
        
        return allRecords
    }
    
    func syncTagColors(localTagColors: [TagColor]) async -> [TagColor] {
        guard iCloudStatus == "Available" else { return localTagColors }
        
        do {
            // 1. Fetch all tag color records from cloud
            let cloudRecords = try await fetchAllTagColorRecords()
            var cloudTagColors: [TagColor] = []
            for record in cloudRecords {
                if let tagColor = tagColor(from: record) {
                    cloudTagColors.append(tagColor)
                }
            }
            print("☁️ Fetched \(cloudTagColors.count) tag colors from Cloud.")
            
            // 2. Build map for comparison
            let cloudTagMap = Dictionary(uniqueKeysWithValues: cloudTagColors.map { ($0.tag, $0) })
            
            // 3. Start with cloud colors as the source of truth
            var recordsToSave: [CKRecord] = []
            var mergedTagColors = cloudTagColors
            
            // 4. Process local tag colors and merge with cloud
            for localTagColor in localTagColors {
                if let cloudTagColor = cloudTagMap[localTagColor.tag] {
                    // Both have this tag - check if they're different
                    if cloudTagColor != localTagColor {
                        // Different colors - upload local version to cloud (local takes precedence for active edits)
                        recordsToSave.append(createTagColorRecord(from: localTagColor))
                        // Update merged colors with local version
                        if let index = mergedTagColors.firstIndex(where: { $0.tag == localTagColor.tag }) {
                            mergedTagColors[index] = localTagColor
                        }
                    }
                } else {
                    // Local has a tag that cloud doesn't have - upload it and add to merged
                    recordsToSave.append(createTagColorRecord(from: localTagColor))
                    mergedTagColors.append(localTagColor)
                }
            }
            
            // 5. Batch upload if needed
            if !recordsToSave.isEmpty {
                print("☁️ Uploading \(recordsToSave.count) tag color records...")
                let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                modifyOp.savePolicy = .changedKeys
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    modifyOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️ Tag color batch upload successful.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️ Tag color batch upload failed: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(modifyOp)
                }
            }
            
            return mergedTagColors
            
        } catch {
            print("☁️ CloudKit Tag Color Sync Failed: \(error)")
            return localTagColors
        }
    }
    
    func saveTagColor(_ tagColor: TagColor) {
        guard iCloudStatus == "Available" else { return }
        let record = createTagColorRecord(from: tagColor)
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .changedKeys
        modifyOp.modifyRecordsResultBlock = { result in
            switch result {
            case .success: print("☁️ Saved tag color for '\(tagColor.tag)' to CloudKit.")
            case .failure(let error): print("☁️ CloudKit Tag Color Save Error: \(error.localizedDescription)")
            }
        }
        database.add(modifyOp)
    }
    
    func deleteTagColor(tag: String) {
        guard iCloudStatus == "Available" else { return }
        let id = CKRecord.ID(recordName: "tagColor_\(tag)")
        database.delete(withRecordID: id) { _, error in
            if let error = error { print("☁️ CloudKit Tag Color Delete Error: \(error.localizedDescription)") }
            else { print("☁️ Deleted tag color for '\(tag)' from CloudKit.") }
        }
    }
    
<<<<<<< HEAD
    // MARK: - Purge All Cloud Data ("Nuke" Button)
    
    /// Purges ALL data from iCloud (CloudKit private database).
    /// This is a "nuclear" option to wipe the cloud store completely.
    /// Use this to clear stuck/zombie data causing sync issues.
    func purgeAllCloudData() async {
        guard iCloudStatus == "Available" else {
            print("☁️🧹 purgeAllCloudData: iCloud not available, skipping.")
            return
=======
    // MARK: - Purge All Cloud Data (Nuclear Option)
    /// Deletes ALL data from iCloud (ClipboardItems and TagColors)
    /// Use this function once to wipe corrupt/zombie data from the cloud
    /// - Returns: Number of records deleted, or error message
    func purgeAllCloudData() async -> Result<Int, Error> {
        guard iCloudStatus == "Available" else {
            return .failure(NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"]))
>>>>>>> copilot/replace-export-with-firebase-share
        }
        
        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false } }
        
<<<<<<< HEAD
        print("☁️🧹 Starting purgeAllCloudData - wiping all CloudKit data...")
        
        do {
            // 1. Delete all ClipboardItem records
            let clipboardRecords = try await fetchAllRecords()
            if !clipboardRecords.isEmpty {
                let recordIDsToDelete = clipboardRecords.map { $0.recordID }
                print("☁️🧹 Deleting \(recordIDsToDelete.count) ClipboardItem records...")
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
                    deleteOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️🧹 Successfully deleted \(recordIDsToDelete.count) ClipboardItem records.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️🧹 Error deleting ClipboardItem records: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(deleteOp)
                }
            } else {
                print("☁️🧹 No ClipboardItem records to delete.")
=======
        do {
            var totalDeleted = 0
            
            // 1. Delete all ClipboardItem records
            let itemRecords = try await fetchAllRecords()
            if !itemRecords.isEmpty {
                let itemIDs = itemRecords.map { $0.recordID }
                print("☁️ PURGE: Deleting \(itemIDs.count) ClipboardItem records...")
                
                let deleteItemsOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: itemIDs)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    deleteItemsOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️ PURGE: ClipboardItem records deleted successfully.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️ PURGE: Failed to delete ClipboardItem records: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(deleteItemsOp)
                }
                totalDeleted += itemIDs.count
>>>>>>> copilot/replace-export-with-firebase-share
            }
            
            // 2. Delete all TagColor records
            let tagColorRecords = try await fetchAllTagColorRecords()
            if !tagColorRecords.isEmpty {
<<<<<<< HEAD
                let tagColorIDsToDelete = tagColorRecords.map { $0.recordID }
                print("☁️🧹 Deleting \(tagColorIDsToDelete.count) TagColor records...")
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: tagColorIDsToDelete)
                    deleteOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️🧹 Successfully deleted \(tagColorIDsToDelete.count) TagColor records.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️🧹 Error deleting TagColor records: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(deleteOp)
                }
            } else {
                print("☁️🧹 No TagColor records to delete.")
            }
            
            print("☁️🧹 purgeAllCloudData completed successfully!")
            
        } catch {
            print("☁️🧹 purgeAllCloudData failed: \(error.localizedDescription)")
=======
                let tagColorIDs = tagColorRecords.map { $0.recordID }
                print("☁️ PURGE: Deleting \(tagColorIDs.count) TagColor records...")
                
                let deleteColorsOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: tagColorIDs)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    deleteColorsOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("☁️ PURGE: TagColor records deleted successfully.")
                            continuation.resume()
                        case .failure(let error):
                            print("☁️ PURGE: Failed to delete TagColor records: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                    database.add(deleteColorsOp)
                }
                totalDeleted += tagColorIDs.count
            }
            
            print("☁️ PURGE COMPLETE: Deleted \(totalDeleted) total records from iCloud.")
            return .success(totalDeleted)
            
        } catch {
            print("☁️ PURGE FAILED: \(error)")
            return .failure(error)
>>>>>>> copilot/replace-export-with-firebase-share
        }
    }
}