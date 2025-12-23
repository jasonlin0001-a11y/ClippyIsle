//
//  URLMetadataFetcher.swift
//  ClippyIsle
//
//  Custom URL metadata fetcher with waterfall extraction strategy
//  for better description extraction from websites
//

import Foundation

/// Represents extracted metadata from a URL
struct URLMetadata {
    var title: String?
    var description: String?
    var imageURL: URL?
    var url: URL
    
    /// Returns true if meaningful metadata was extracted
    var hasContent: Bool {
        return title != nil || description != nil || imageURL != nil
    }
}

/// Custom URL metadata fetcher with waterfall extraction strategy
/// Implements browser impersonation and multi-source extraction
actor URLMetadataFetcher {
    
    // MARK: - Browser User-Agent
    
    /// Standard browser User-Agent to prevent bot detection
    private static let userAgents = [
        // Chrome on macOS
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        // Safari on iOS
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ]
    
    // MARK: - Configuration
    
    /// Maximum description length before truncation
    private static let maxDescriptionLength = 300
    
    /// Minimum paragraph length for fallback extraction
    private static let minParagraphLength = 20
    
    /// Request timeout in seconds
    private static let requestTimeout: TimeInterval = 15.0
    
    // MARK: - Public API
    
    /// Fetches metadata for a given URL using waterfall extraction strategy
    /// - Parameter url: The URL to fetch metadata for
    /// - Returns: Extracted metadata or nil if fetch failed
    static func fetchMetadata(for url: URL) async throws -> URLMetadata {
        let html = try await fetchHTML(from: url)
        return parseMetadata(from: html, sourceURL: url)
    }
    
    // MARK: - HTML Fetching
    
    /// Fetches HTML content from URL with browser headers
    private static func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout
        
        // Set browser-like headers to prevent bot detection
        request.setValue(userAgents[0], forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid HTTP response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLMetadataError.invalidResponse
        }
        
        // Try to decode with response encoding, fallback to UTF-8
        // First, attempt to use the encoding specified in the HTTP response header
        var encoding: String.Encoding = .utf8
        if let textEncodingName = httpResponse.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
            }
            // If encoding detection failed, we'll use UTF-8 as default (already set)
        }
        
        // Try the detected encoding first, then UTF-8 as fallback
        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
            throw URLMetadataError.invalidData
        }
        
        return html
    }
    
    // MARK: - Metadata Parsing
    
    /// Parses metadata from HTML using waterfall extraction strategy
    private static func parseMetadata(from html: String, sourceURL: URL) -> URLMetadata {
        var metadata = URLMetadata(url: sourceURL)
        
        // Extract title
        metadata.title = extractTitle(from: html)
        
        // Extract description using waterfall strategy
        metadata.description = extractDescription(from: html)
        
        // Extract image URL
        metadata.imageURL = extractImageURL(from: html, baseURL: sourceURL)
        
        return metadata
    }
    
    // MARK: - Title Extraction
    
    /// Extracts title from HTML using priority order
    private static func extractTitle(from html: String) -> String? {
        // Priority 1: og:title
        if let ogTitle = extractMetaContent(from: html, property: "og:title") {
            return cleanText(ogTitle)
        }
        
        // Priority 2: twitter:title
        if let twitterTitle = extractMetaContent(from: html, name: "twitter:title") {
            return cleanText(twitterTitle)
        }
        
        // Priority 3: <title> tag
        if let titleMatch = html.range(of: "<title[^>]*>([^<]*)</title>", options: .regularExpression) {
            let titleHTML = String(html[titleMatch])
            if let contentStart = titleHTML.range(of: ">"),
               let contentEnd = titleHTML.range(of: "</title>") {
                let content = String(titleHTML[contentStart.upperBound..<contentEnd.lowerBound])
                return cleanText(content)
            }
        }
        
        return nil
    }
    
    // MARK: - Description Extraction (Waterfall Strategy)
    
    /// Extracts description using waterfall priority strategy
    private static func extractDescription(from html: String) -> String? {
        // Priority 1: og:description (Open Graph)
        if let ogDescription = extractMetaContent(from: html, property: "og:description") {
            let cleaned = cleanText(ogDescription)
            if !cleaned.isEmpty {
                return truncateDescription(cleaned)
            }
        }
        
        // Priority 2: twitter:description (Twitter Card)
        if let twitterDescription = extractMetaContent(from: html, name: "twitter:description") {
            let cleaned = cleanText(twitterDescription)
            if !cleaned.isEmpty {
                return truncateDescription(cleaned)
            }
        }
        
        // Priority 3: meta name="description" (Standard HTML)
        if let metaDescription = extractMetaContent(from: html, name: "description") {
            let cleaned = cleanText(metaDescription)
            if !cleaned.isEmpty {
                return truncateDescription(cleaned)
            }
        }
        
        // Priority 4: JSON-LD description
        if let jsonLDDescription = extractJSONLDDescription(from: html) {
            let cleaned = cleanText(jsonLDDescription)
            if !cleaned.isEmpty {
                return truncateDescription(cleaned)
            }
        }
        
        // Priority 5: First significant paragraph
        if let paragraphText = extractFirstSignificantParagraph(from: html) {
            let cleaned = cleanText(paragraphText)
            if !cleaned.isEmpty {
                return truncateDescription(cleaned)
            }
        }
        
        return nil
    }
    
    // MARK: - Image Extraction
    
    /// Extracts image URL from HTML
    private static func extractImageURL(from html: String, baseURL: URL) -> URL? {
        // Priority 1: og:image
        if let ogImage = extractMetaContent(from: html, property: "og:image") {
            return resolveURL(ogImage, baseURL: baseURL)
        }
        
        // Priority 2: twitter:image
        if let twitterImage = extractMetaContent(from: html, name: "twitter:image") {
            return resolveURL(twitterImage, baseURL: baseURL)
        }
        
        // Priority 3: twitter:image:src
        if let twitterImageSrc = extractMetaContent(from: html, name: "twitter:image:src") {
            return resolveURL(twitterImageSrc, baseURL: baseURL)
        }
        
        return nil
    }
    
    // MARK: - Meta Tag Extraction
    
    /// Extracts content from meta tag with property attribute
    private static func extractMetaContent(from html: String, property: String) -> String? {
        // Match <meta property="og:description" content="...">
        // Handle both single and double quotes, and attribute order variations
        let patterns = [
            "<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+property=[\"']\(property)[\"']"
        ]
        
        for pattern in patterns {
            if let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(html[match])
                if let content = extractContentValue(from: matchedString) {
                    return content
                }
            }
        }
        
        return nil
    }
    
    /// Extracts content from meta tag with name attribute
    private static func extractMetaContent(from html: String, name: String) -> String? {
        // Match <meta name="description" content="...">
        let patterns = [
            "<meta[^>]+name=[\"']\(name)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+name=[\"']\(name)[\"']"
        ]
        
        for pattern in patterns {
            if let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(html[match])
                if let content = extractContentValue(from: matchedString) {
                    return content
                }
            }
        }
        
        return nil
    }
    
    /// Extracts the content attribute value from a meta tag string
    private static func extractContentValue(from metaTag: String) -> String? {
        // Extract content="..." or content='...'
        let pattern = "content=[\"']([^\"']*)[\"']"
        guard let match = metaTag.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        
        let matchedString = String(metaTag[match])
        // Remove content=" and trailing "
        let value = matchedString
            .replacingOccurrences(of: "content=\"", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "content='", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        return value.isEmpty ? nil : value
    }
    
    // MARK: - JSON-LD Extraction
    
    /// Extracts description from JSON-LD structured data
    private static func extractJSONLDDescription(from html: String) -> String? {
        // Find all JSON-LD script blocks
        let pattern = "<script[^>]+type=[\"']application/ld\\+json[\"'][^>]*>([\\s\\S]*?)</script>"
        
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsHTML = html as NSString
        let matches = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)) ?? []
        
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let jsonRange = match.range(at: 1)
            let jsonString = nsHTML.substring(with: jsonRange)
            
            // Try to parse JSON and extract description
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                if let description = extractDescriptionFromJSON(json) {
                    return description
                }
            }
        }
        
        return nil
    }
    
    /// Recursively searches for description in JSON object
    private static func extractDescriptionFromJSON(_ json: Any) -> String? {
        if let dict = json as? [String: Any] {
            // Direct description field
            if let description = dict["description"] as? String, !description.isEmpty {
                return description
            }
            
            // Check @graph array (common in JSON-LD)
            if let graph = dict["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let description = item["description"] as? String, !description.isEmpty {
                        return description
                    }
                }
            }
            
            // Recursively search nested objects
            for (_, value) in dict {
                if let description = extractDescriptionFromJSON(value) {
                    return description
                }
            }
        } else if let array = json as? [Any] {
            for item in array {
                if let description = extractDescriptionFromJSON(item) {
                    return description
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Paragraph Extraction (Fallback)
    
    /// Extracts first significant paragraph from body content
    private static func extractFirstSignificantParagraph(from html: String) -> String? {
        // Remove common non-content elements
        var cleanedHTML = html
        
        // Remove script, style, nav, header, footer, aside tags to avoid extracting non-content text
        let tagsToRemove = ["script", "style", "nav", "header", "footer", "aside", "noscript", "iframe"]
        for tag in tagsToRemove {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            cleanedHTML = cleanedHTML.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Find paragraph tags with their content
        // Pattern breakdown:
        // - <p[^>]*> : Match opening <p> tag with optional attributes
        // - ([^<]* : Capture text that doesn't contain < (start of any tag)
        // - (?:<[^/p][^>]*>[^<]*</[^p][^>]*>)* : Allow nested tags that are NOT </p> (e.g., <strong>, <a>)
        // - [^<]*) : More text after nested tags
        // - </p> : Match closing </p> tag
        // This pattern extracts paragraph content including inline elements like <a>, <strong>, <em>
        let paragraphPattern = "<p[^>]*>([^<]*(?:<[^/p][^>]*>[^<]*</[^p][^>]*>)*[^<]*)</p>"
        let regex = try? NSRegularExpression(pattern: paragraphPattern, options: [.caseInsensitive])
        let nsHTML = cleanedHTML as NSString
        let matches = regex?.matches(in: cleanedHTML, options: [], range: NSRange(location: 0, length: nsHTML.length)) ?? []
        
        for match in matches {
            guard match.numberOfRanges > 0 else { continue }
            let pRange = match.range(at: 0)
            let pContent = nsHTML.substring(with: pRange)
            
            // Strip all HTML tags from paragraph content
            let textContent = stripHTMLTags(from: pContent)
            let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if paragraph is significant (longer than minimum length)
            if trimmed.count >= minParagraphLength {
                return trimmed
            }
        }
        
        return nil
    }
    
    // MARK: - Text Cleaning
    
    /// Cleans and decodes text content
    static func cleanText(_ text: String) -> String {
        var result = text
        
        // Decode HTML entities
        result = decodeHTMLEntities(result)
        
        // Replace multiple whitespace/newlines with single space
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    /// Decodes common HTML entities
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        
        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&ndash;": "\u{2013}",  // en dash
            "&mdash;": "\u{2014}",  // em dash
            "&lsquo;": "\u{2018}",  // left single quote
            "&rsquo;": "\u{2019}",  // right single quote
            "&ldquo;": "\u{201C}",  // left double quote
            "&rdquo;": "\u{201D}",  // right double quote
            "&hellip;": "\u{2026}", // ellipsis
            "&copy;": "\u{00A9}",   // copyright
            "&reg;": "\u{00AE}",    // registered
            "&trade;": "\u{2122}"   // trademark
        ]
        
        for (entity, char) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        // Numeric entities (decimal)
        let decimalPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let nsResult = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    let fullRange = match.range(at: 0)
                    let numberRange = match.range(at: 1)
                    let numberString = nsResult.substring(with: numberRange)
                    
                    if let codePoint = UInt32(numberString),
                       let scalar = Unicode.Scalar(codePoint) {
                        let char = String(Character(scalar))
                        result = (result as NSString).replacingCharacters(in: fullRange, with: char)
                    }
                }
            }
        }
        
        // Numeric entities (hexadecimal)
        let hexPattern = "&#x([0-9A-Fa-f]+);"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let nsResult = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    let fullRange = match.range(at: 0)
                    let hexRange = match.range(at: 1)
                    let hexString = nsResult.substring(with: hexRange)
                    
                    if let codePoint = UInt32(hexString, radix: 16),
                       let scalar = Unicode.Scalar(codePoint) {
                        let char = String(Character(scalar))
                        result = (result as NSString).replacingCharacters(in: fullRange, with: char)
                    }
                }
            }
        }
        
        return result
    }
    
    /// Strips HTML tags from text
    private static func stripHTMLTags(from text: String) -> String {
        return text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    /// Truncates description to maximum length
    private static func truncateDescription(_ text: String) -> String {
        if text.count <= maxDescriptionLength {
            return text
        }
        
        // Find a good breaking point (space or punctuation)
        let truncateAt = maxDescriptionLength - 3  // Leave room for ellipsis
        let endIndex = text.index(text.startIndex, offsetBy: truncateAt)
        let substring = String(text[..<endIndex])
        
        // Try to break at last space
        if let lastSpace = substring.lastIndex(of: " ") {
            return String(text[..<lastSpace]) + "..."
        }
        
        return substring + "..."
    }
    
    // MARK: - URL Resolution
    
    /// Resolves relative URLs to absolute URLs
    private static func resolveURL(_ urlString: String, baseURL: URL) -> URL? {
        // Already absolute URL
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        
        // Protocol-relative URL
        if urlString.hasPrefix("//") {
            return URL(string: "https:" + urlString)
        }
        
        // Relative URL - resolve against base
        return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
    }
}

// MARK: - Error Types

enum URLMetadataError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidData:
            return "Could not decode response data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
