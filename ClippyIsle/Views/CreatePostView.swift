//
//  CreatePostView.swift
//  ClippyIsle
//
//  Create Post screen with URL input, link preview fetching, and publish functionality.
//

import SwiftUI
import FirebaseFunctions
import Combine

// MARK: - Link Preview Data Model
/// Represents fetched Open Graph metadata for a URL
struct LinkPreviewData {
    var title: String
    var image: String?
    var description: String?
    var url: String
    var siteName: String?
}

// MARK: - Create Post ViewModel
/// ViewModel for handling link preview fetching and post creation
@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var urlInput: String = ""
    @Published var curatorNote: String = ""
    @Published var linkPreview: LinkPreviewData?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isPublishing: Bool = false
    @Published var publishSuccess: Bool = false
    
    private var debounceTask: Task<Void, Never>?
    private let debounceDelay: TimeInterval = 1.0 // 1 second debounce
    
    // MARK: - Fetch Link Preview with Debounce
    /// Called when URL input changes - debounces before fetching
    func urlInputChanged() {
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        // Clear preview if URL is empty
        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            linkPreview = nil
            error = nil
            return
        }
        
        // Start new debounce task
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
                // If not cancelled, fetch preview
                if !Task.isCancelled {
                    await fetchLinkPreview()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    // MARK: - Fetch Link Preview (Manual)
    /// Manually triggered fetch (from Preview button)
    func fetchPreviewManually() {
        debounceTask?.cancel()
        Task {
            await fetchLinkPreview()
        }
    }
    
    // MARK: - Fetch Link Preview
    /// Calls the Firebase Cloud Function to fetch Open Graph metadata
    private func fetchLinkPreview() async {
        let trimmedUrl = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic URL validation
        guard !trimmedUrl.isEmpty else {
            await MainActor.run {
                linkPreview = nil
                error = nil
            }
            return
        }
        
        // Ensure URL has a scheme
        var urlToFetch = trimmedUrl
        if !urlToFetch.hasPrefix("http://") && !urlToFetch.hasPrefix("https://") {
            urlToFetch = "https://" + urlToFetch
        }
        
        // Validate URL format
        guard URL(string: urlToFetch) != nil else {
            await MainActor.run {
                error = "Invalid URL format"
                linkPreview = nil
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        // Call Firebase Cloud Function
        let functions = Functions.functions()
        let callable = functions.httpsCallable("fetchLinkPreview")
        
        do {
            let result = try await callable.call(["url": urlToFetch])
            
            guard let data = result.data as? [String: Any] else {
                await MainActor.run {
                    error = "Invalid response format"
                    linkPreview = nil
                    isLoading = false
                }
                return
            }
            
            // Check success flag
            if let success = data["success"] as? Bool, success,
               let responseData = data["data"] as? [String: Any] {
                let title = responseData["title"] as? String ?? "Untitled"
                let image = responseData["image"] as? String
                let description = responseData["description"] as? String
                let siteName = responseData["siteName"] as? String
                
                await MainActor.run {
                    linkPreview = LinkPreviewData(
                        title: title,
                        image: image,
                        description: description,
                        url: urlToFetch,
                        siteName: siteName
                    )
                    error = nil
                    isLoading = false
                }
                
                print("✅ Link Preview fetched: \(title)")
            } else {
                let errorMsg = data["error"] as? String ?? "Failed to fetch preview"
                await MainActor.run {
                    error = errorMsg
                    linkPreview = nil
                    isLoading = false
                }
                print("❌ Link Preview error: \(errorMsg)")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                linkPreview = nil
                isLoading = false
            }
            print("❌ Link Preview fetch failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Publish Post
    /// Creates a new creator post with the link preview data
    func publishPost() async -> Bool {
        guard let preview = linkPreview else {
            error = "Please fetch a link preview first"
            return false
        }
        
        await MainActor.run {
            isPublishing = true
            error = nil
        }
        
        // Extract domain from URL
        let linkDomain = URL(string: preview.url)?.host
        
        do {
            // Use CreatorSubscriptionManager to create the post with link preview data
            try await CreatorSubscriptionManager.shared.createPost(
                title: preview.title,
                contentUrl: preview.url,
                curatorNote: curatorNote.isEmpty ? nil : curatorNote,
                linkTitle: preview.title,
                linkImage: preview.image,
                linkDescription: preview.description,
                linkDomain: linkDomain
            )
            
            await MainActor.run {
                isPublishing = false
                publishSuccess = true
            }
            
            print("✅ Post published successfully with link preview data")
            return true
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isPublishing = false
            }
            print("❌ Publish post failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Reset
    /// Resets the view model for a new post
    func reset() {
        urlInput = ""
        curatorNote = ""
        linkPreview = nil
        error = nil
        publishSuccess = false
    }
}

// MARK: - Create Post View
/// Main view for creating a new creator post with link preview
struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let themeColor: Color
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // URL Input Section
                    urlInputSection
                    
                    // Link Preview Card
                    if viewModel.isLoading {
                        loadingView
                    } else if let preview = viewModel.linkPreview {
                        linkPreviewCard(preview)
                    } else if let error = viewModel.error {
                        errorView(error)
                    }
                    
                    // Curator Note Section
                    if viewModel.linkPreview != nil {
                        curatorNoteSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(20)
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if await viewModel.publishPost() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isPublishing {
                            ProgressView()
                        } else {
                            Text("Publish")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.linkPreview == nil || viewModel.isPublishing)
                }
            }
            .alert("Post Published!", isPresented: $viewModel.publishSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your post has been shared with your followers.")
            }
        }
    }
    
    // MARK: - URL Input Section
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share a Link")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                TextField("Enter or paste URL...", text: $viewModel.urlInput)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .onChange(of: viewModel.urlInput) { _, _ in
                        viewModel.urlInputChanged()
                    }
                
                Button {
                    viewModel.fetchPreviewManually()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeColor)
                }
                .disabled(viewModel.urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            
            Text("Paste a URL to automatically fetch its preview")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Fetching link preview...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Link Preview Card
    private func linkPreviewCard(_ preview: LinkPreviewData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image (if available)
            if let imageUrl = preview.image,
               let url = URL(string: imageUrl),
               imageUrl.hasPrefix("https://") || imageUrl.hasPrefix("http://") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                            .overlay(
                                ProgressView()
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Site name
                if let siteName = preview.siteName, !siteName.isEmpty {
                    Text(siteName.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(themeColor)
                }
                
                // Title
                Text(preview.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                // Description
                if let description = preview.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // URL
                Text(formattedUrl(preview.url))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Curator Note Section
    private var curatorNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Your Thoughts")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextEditor(text: $viewModel.curatorNote)
                .frame(minHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            
            Text("Share why you're recommending this link (optional)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                viewModel.fetchPreviewManually()
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Helpers
    private func formattedUrl(_ urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.host ?? urlString
        }
        return urlString
    }
}

// MARK: - Preview
#Preview {
    CreatePostView(themeColor: .blue)
}
