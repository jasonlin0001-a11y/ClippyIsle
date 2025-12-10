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

/// Manager class for fetching URL metadata asynchronously
@MainActor
class LinkMetadataManager: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let provider = LPMetadataProvider()
    
    /// Fetches metadata for a given URL
    /// - Parameter url: The URL to fetch metadata for
    func fetchMetadata(for url: URL) {
        isLoading = true
        error = nil
        metadata = nil
        
        Task {
            do {
                let fetchedMetadata = try await provider.startFetchingMetadata(for: url)
                self.metadata = fetchedMetadata
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// Cancels any ongoing metadata fetch operation
    func cancel() {
        provider.cancel()
        isLoading = false
    }
}
