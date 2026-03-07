//
//  AppConfiguration.swift
//  TechQTA
//
//  Secure API key management using Info.plist injected values.
//  Keys are loaded from Bundle.main, making them unavailable in source code.

import Foundation

/// Securely manages Cloudflare API credentials through Info.plist injection.
/// 
/// This configuration enum reads secrets from the app bundle's Info.plist file,
/// which is populated at build time via .xcconfig files and Xcode Cloud environment variables.
/// The actual secret values are never stored in Swift source code.
enum AppConfiguration {
    
    /// Retrieves the Cloudflare Account ID from Info.plist.
    /// - Returns: The account ID string, or nil if not configured.
    static var cloudflareAccountID: String? {
        guard let url = Bundle.main.url(forResource: "CloudflareSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let id = dict["CFAccountID"] as? String,
              !id.isEmpty,
              id != "YOUR_ACCOUNT_ID" else { return nil }
        return id
    }
    
    /// Retrieves the Cloudflare API Auth Token from Info.plist.
    /// - Returns: The auth token string, or nil if not configured.
    static var cloudflareAuthToken: String? {
        guard let url = Bundle.main.url(forResource: "CloudflareSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let token = dict["CFAuthToken"] as? String,
              !token.isEmpty,
              token != "YOUR_AUTH_TOKEN" else { return nil }
    }
    
    /// Retrieves the Cloudflare API Key from Info.plist.
    /// - Returns: The API key string, or nil if not configured.
    static var cloudflareAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "CloudflareSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let key = dict["CLOUDFLARE_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_API_KEY" else { return nil }
        return key
    }
    
    /// Checks if Cloudflare credentials are properly configured.
    /// - Returns: True if both account ID and auth token are available.
    static var isAvailable: Bool {
        cloudflareAccountID != nil && cloudflareAuthToken != nil
    }
    
    /// Constructs the full Cloudflare AI API base URL.
    /// - Returns: The API endpoint URL, or nil if credentials are missing.
    static func baseURL() -> URL? {
        guard let accountID = cloudflareAccountID else { return nil }
        return URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountID)/ai/run")
    }
    
    /// Constructs the Authorization header value for API requests.
    /// - Returns: The Bearer token string, or nil if credentials are missing.
    static func authHeader() -> String? {
        guard let authToken = cloudflareAuthToken else { return nil }
        return "Bearer \(authToken)"
    }
    
    /// Constructs the Authorization header value using API key instead of token.
    /// - Returns: The API key string, or nil if credentials are missing.
    static func apiKeyHeader() -> String? {
        guard let apikey = cloudflareAPIKey else { return nil }
        return "Bearer \(apikey)"
    }
}
