//
//  CloudflareConfig.swift
//  TechQTA
//

import Foundation

/// Loads Cloudflare API credentials from CloudflareSecrets.plist.
///
/// Local dev:
/// - Option A: Copy CloudflareSecrets.example.plist → CloudflareSecrets.plist, fill in values.
/// - Option B: Copy .env.example → .env, fill in, then run `./scripts/generate_secrets_from_env.sh`
///
/// Xcode Cloud: Set CF_ACCOUNT_ID and CF_AUTH_TOKEN as workflow secrets (Environment section).
/// ci_pre_xcodebuild.sh generates the plist from those env vars.
enum CloudflareConfig {
    private static let accountID: String? = {
        guard let url = Bundle.main.url(forResource: "CloudflareSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let id = dict["CFAccountID"] as? String,
              !id.isEmpty,
              id != "YOUR_ACCOUNT_ID" else { return nil }
        return id
    }()

    private static let authToken: String? = {
        guard let url = Bundle.main.url(forResource: "CloudflareSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let token = dict["CFAuthToken"] as? String,
              !token.isEmpty,
              token != "YOUR_AUTH_TOKEN" else { return nil }
        return token
    }()

    static var isAvailable: Bool {
        accountID != nil && authToken != nil
    }

    static func baseURL() -> URL? {
        guard let id = accountID else { return nil }
        return URL(string: "https://api.cloudflare.com/client/v4/accounts/\(id)/ai/run")
    }

    static func authHeader() -> String? {
        guard let token = authToken else { return nil }
        return "Bearer \(token)"
    }
}
