//
//  LinkMetadataManager.swift
//  ClippyIsle
//
//  Manager for fetching URL metadata using LinkPresentation framework
//

import Foundation
import LinkPresentation
import SwiftUI
import Combine

/// Manager class for fetching URL metadata asynchronously with caching
@MainActor
class LinkMetadataManager: ObservableObject {
    static let shared = LinkMetadataManager()
    
    @Published var metadata: LPLinkMetadata?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // Cache to store fetched metadata by URL string
    private var metadataCache: [String: LPLinkMetadata] = [:]
    private var activeRequests: [String: Task<Void, Never>] = [:]
    
    private let provider = LPMetadataProvider()
    
    private init() {}
    
    /// Fetches metadata for a given URL with caching
    /// - Parameter url: The URL to fetch metadata for
    /// - Returns: Cached or freshly fetched metadata
    func fetchMetadata(for url: URL) -> LPLinkMetadata? {
        let urlString = url.absoluteString
        
        // Return cached metadata if available
        if let cached = metadataCache[urlString] {
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - CACHE HIT for URL: \(url)")
            return cached
        }
        
        // Check if request is already in progress
        if activeRequests[urlString] != nil {
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - REQUEST IN PROGRESS for URL: \(url)")
            return nil
        }
        
        // Start new request
        LaunchLogger.log("LinkMetadataManager.fetchMetadata() - START for URL: \(url)")
        let task = Task {
            do {
                let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
                metadataCache[urlString] = fetchedMetadata
                activeRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - SUCCESS for URL: \(url)")
            } catch {
                activeRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - FAILED for URL: \(url)")
            }
        }
        activeRequests[urlString] = task
        
        return nil
    }
    
    /// Gets cached metadata for a URL without triggering a fetch
    /// - Parameter url: The URL to get cached metadata for
    /// - Returns: Cached metadata if available, nil otherwise
    func getCachedMetadata(for url: URL) -> LPLinkMetadata? {
        return metadataCache[url.absoluteString]
    }
    
    /// Cancels any ongoing metadata fetch operation
    func cancel() {
        provider.cancel()
        isLoading = false
    }
}
