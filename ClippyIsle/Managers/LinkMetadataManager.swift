//
//  LinkMetadataManager.swift
//  ClippyIsle
//
//  Manager for fetching URL metadata using LinkPresentation framework
//  Enhanced with custom waterfall extraction strategy for better description support
//

import Foundation
import LinkPresentation
import SwiftUI
import Combine

/// Combined metadata result containing both LP metadata and custom extracted description
struct EnhancedLinkMetadata {
    let lpMetadata: LPLinkMetadata
    let customDescription: String?
    
    /// Returns the best available description
    var description: String? {
        // LPLinkMetadata doesn't expose description publicly, so use custom extraction
        return customDescription
    }
}

/// Manager class for fetching URL metadata asynchronously with caching
/// Enhanced with waterfall extraction strategy for better description support
@MainActor
class LinkMetadataManager: ObservableObject {
    static let shared = LinkMetadataManager()
    
    // Published properties for UI binding (only used by non-shared instances)
    @Published var metadata: LPLinkMetadata?
    @Published var enhancedMetadata: EnhancedLinkMetadata?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // Cache to store fetched metadata by URL string (shared across all instances)
    private static var metadataCache: [String: LPLinkMetadata] = [:]
    private static var enhancedMetadataCache: [String: EnhancedLinkMetadata] = [:]
    private static var activeRequests: [String: Task<LPLinkMetadata?, Never>] = [:]
    private static var activeEnhancedRequests: [String: Task<EnhancedLinkMetadata?, Never>] = [:]
    
    private let provider = LPMetadataProvider()
    
    // Allow public initialization for components that need their own state tracking
    init() {}
    
    /// Fetches metadata for a given URL with caching (for singleton use)
    /// - Parameter url: The URL to fetch metadata for
    /// - Returns: Task that resolves to cached or freshly fetched metadata
    func fetchMetadata(for url: URL) async -> LPLinkMetadata? {
        let urlString = url.absoluteString
        
        // Return cached metadata if available
        if let cached = Self.metadataCache[urlString] {
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - CACHE HIT for URL: \(url)")
            return cached
        }
        
        // Check if request is already in progress and await it
        if let existingTask = Self.activeRequests[urlString] {
            LaunchLogger.log("LinkMetadataManager.fetchMetadata() - AWAITING IN-PROGRESS for URL: \(url)")
            return await existingTask.value
        }
        
        // Start new request with a NEW provider instance to support independent cancellation
        LaunchLogger.log("LinkMetadataManager.fetchMetadata() - START for URL: \(url)")
        let localProvider = LPMetadataProvider()
        let task = Task { () -> LPLinkMetadata? in
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                
                let fetchedMetadata = try await localProvider.startFetchingMetadata(for: url)
                
                // Check for cancellation after fetch
                try Task.checkCancellation()
                
                Self.metadataCache[urlString] = fetchedMetadata
                Self.activeRequests[urlString] = nil  // Cleanup after cache assignment
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - SUCCESS for URL: \(url)")
                return fetchedMetadata
            } catch is CancellationError {
                localProvider.cancel()
                Self.activeRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - CANCELLED for URL: \(url)")
                return nil
            } catch {
                Self.activeRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - FAILED for URL: \(url)")
                return nil
            }
        }
        Self.activeRequests[urlString] = task
        
        return await task.value
    }
    
    /// Fetches metadata with state updates (for UI components with @Published properties)
    /// - Parameter url: The URL to fetch metadata for
    func fetchMetadata(for url: URL) {
        LaunchLogger.log("LinkMetadataManager.fetchMetadata() - START (with state) for URL: \(url)")
        isLoading = true
        error = nil
        metadata = nil
        
        Task {
            // Check cache first
            if let cached = Self.metadataCache[url.absoluteString] {
                self.metadata = cached
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - CACHE HIT (with state) for URL: \(url)")
                return
            }
            
            // Fetch from network
            do {
                let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
                Self.metadataCache[url.absoluteString] = fetchedMetadata
                self.metadata = fetchedMetadata
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - SUCCESS (with state) for URL: \(url)")
            } catch {
                self.error = error
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchMetadata() - FAILED (with state) for URL: \(url)")
            }
        }
    }
    
    /// Gets cached metadata for a URL without triggering a fetch
    /// - Parameter url: The URL to get cached metadata for
    /// - Returns: Cached metadata if available, nil otherwise
    func getCachedMetadata(for url: URL) -> LPLinkMetadata? {
        return Self.metadataCache[url.absoluteString]
    }
    
    /// Cancels any ongoing metadata fetch operation
    func cancel() {
        provider.cancel()
        isLoading = false
    }
    
    // MARK: - Enhanced Metadata Fetching (with custom description extraction)
    
    /// Fetches enhanced metadata including custom description extraction
    /// Uses waterfall strategy for better description support
    /// - Parameter url: The URL to fetch metadata for
    /// - Returns: Enhanced metadata with LP metadata and custom description
    func fetchEnhancedMetadata(for url: URL) async -> EnhancedLinkMetadata? {
        let urlString = url.absoluteString
        
        // Return cached enhanced metadata if available
        if let cached = Self.enhancedMetadataCache[urlString] {
            LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - CACHE HIT for URL: \(url)")
            return cached
        }
        
        // Check if enhanced request is already in progress
        if let existingTask = Self.activeEnhancedRequests[urlString] {
            LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - AWAITING IN-PROGRESS for URL: \(url)")
            return await existingTask.value
        }
        
        LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - START for URL: \(url)")
        let localProvider = LPMetadataProvider()
        
        let task = Task { () -> EnhancedLinkMetadata? in
            do {
                try Task.checkCancellation()
                
                // Fetch LP metadata and custom metadata concurrently
                async let lpMetadataTask = localProvider.startFetchingMetadata(for: url)
                async let customMetadataTask = URLMetadataFetcher.fetchMetadata(for: url)
                
                // Wait for LP metadata (required)
                let lpMetadata = try await lpMetadataTask
                
                try Task.checkCancellation()
                
                // Get custom description (optional, don't fail if it errors)
                var customDescription: String?
                do {
                    let customMetadata = try await customMetadataTask
                    customDescription = customMetadata.description
                    LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - Custom description extracted: \(customDescription ?? "nil")")
                } catch {
                    LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - Custom fetch failed, continuing with LP only: \(error)")
                }
                
                let enhanced = EnhancedLinkMetadata(
                    lpMetadata: lpMetadata,
                    customDescription: customDescription
                )
                
                Self.enhancedMetadataCache[urlString] = enhanced
                Self.metadataCache[urlString] = lpMetadata  // Also cache LP metadata separately
                Self.activeEnhancedRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - SUCCESS for URL: \(url)")
                return enhanced
                
            } catch is CancellationError {
                localProvider.cancel()
                Self.activeEnhancedRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - CANCELLED for URL: \(url)")
                return nil
            } catch {
                Self.activeEnhancedRequests[urlString] = nil
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - FAILED for URL: \(url) - \(error)")
                return nil
            }
        }
        
        Self.activeEnhancedRequests[urlString] = task
        return await task.value
    }
    
    /// Fetches enhanced metadata with state updates (for UI components)
    /// - Parameter url: The URL to fetch metadata for
    func fetchEnhancedMetadata(for url: URL) {
        LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - START (with state) for URL: \(url)")
        isLoading = true
        error = nil
        metadata = nil
        enhancedMetadata = nil
        
        Task {
            // Check cache first
            if let cached = Self.enhancedMetadataCache[url.absoluteString] {
                self.enhancedMetadata = cached
                self.metadata = cached.lpMetadata
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - CACHE HIT (with state) for URL: \(url)")
                return
            }
            
            // Fetch enhanced metadata
            if let enhanced = await fetchEnhancedMetadata(for: url) {
                self.enhancedMetadata = enhanced
                self.metadata = enhanced.lpMetadata
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - SUCCESS (with state) for URL: \(url)")
            } else {
                self.error = URLMetadataError.invalidResponse
                self.isLoading = false
                LaunchLogger.log("LinkMetadataManager.fetchEnhancedMetadata() - FAILED (with state) for URL: \(url)")
            }
        }
    }
    
    /// Gets cached enhanced metadata for a URL without triggering a fetch
    /// - Parameter url: The URL to get cached metadata for
    /// - Returns: Cached enhanced metadata if available, nil otherwise
    func getCachedEnhancedMetadata(for url: URL) -> EnhancedLinkMetadata? {
        return Self.enhancedMetadataCache[url.absoluteString]
    }
}
