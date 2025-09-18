//
//  SecretsManager.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

/// Secure secrets management with environment variable support
class SecretsManager: ObservableObject {
    static let shared = SecretsManager()
    
    private let logger = Logger.shared
    
    private init() {}
    
    // MARK: - Environment Variables Support
    
    /// Get value from environment variable or return default
    private func getEnvironmentVariable(_ key: String, defaultValue: String? = nil) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            return defaultValue
        }
        return value
    }
    
    // MARK: - API Keys (from ENV)
    
    var openAIAPIKey: String? {
        getEnvironmentVariable("OPENAI_API_KEY")
    }
    
    var binlistAPIKey: String? {
        getEnvironmentVariable("BINLIST_API_KEY")
    }
    
    var googleMapsAPIKey: String? {
        getEnvironmentVariable("GOOGLE_MAPS_API_KEY")
    }
    
    var mapboxAPIKey: String? {
        getEnvironmentVariable("MAPBOX_API_KEY")
    }
    
    var stripeSecretKey: String? {
        getEnvironmentVariable("STRIPE_SECRET_KEY")
    }
    
    var stripePublishableKey: String? {
        getEnvironmentVariable("STRIPE_PUBLISHABLE_KEY")
    }
    
    // MARK: - Configuration Values (from ENV)
    
    var environment: String {
        getEnvironmentVariable("ENVIRONMENT", defaultValue: "development") ?? "development"
    }
    
    var enableDebugMode: Bool {
        getEnvironmentVariable("DEBUG_MODE", defaultValue: "true")?.lowercased() == "true"
    }
    
    var logLevel: String {
        getEnvironmentVariable("LOG_LEVEL", defaultValue: "info") ?? "info"
    }
    
    var databaseURL: String? {
        getEnvironmentVariable("DATABASE_URL")
    }
    
    var redisURL: String? {
        getEnvironmentVariable("REDIS_URL")
    }
    
    // MARK: - Feature Flags (from ENV)
    
    var enableOpenAI: Bool {
        getEnvironmentVariable("ENABLE_OPENAI", defaultValue: "false")?.lowercased() == "true"
    }
    
    var enableLocalML: Bool {
        getEnvironmentVariable("ENABLE_LOCAL_ML", defaultValue: "true")?.lowercased() == "true"
    }
    
    var enableBinLookup: Bool {
        getEnvironmentVariable("ENABLE_BIN_LOOKUP", defaultValue: "true")?.lowercased() == "true"
    }
    
    var enableRealTimeProcessing: Bool {
        getEnvironmentVariable("ENABLE_REAL_TIME", defaultValue: "true")?.lowercased() == "true"
    }
    
    // MARK: - Validation
    
    func validateConfiguration() -> [String] {
        var warnings: [String] = []
        
        if !enableOpenAI && !enableLocalML {
            warnings.append("No ML service enabled - set ENABLE_OPENAI=true or ENABLE_LOCAL_ML=true")
        }
        
        if enableOpenAI && openAIAPIKey == nil {
            warnings.append("OpenAI enabled but OPENAI_API_KEY not set")
        }
        
        if enableBinLookup && binlistAPIKey == nil {
            warnings.append("BIN lookup enabled but BINLIST_API_KEY not set - will use free tier")
        }
        
        return warnings
    }
    
    func getConfigurationSummary() -> String {
        let warnings = validateConfiguration()
        var summary = "Configuration Summary:\n"
        summary += "Environment: \(environment)\n"
        summary += "Debug Mode: \(enableDebugMode)\n"
        summary += "OpenAI: \(enableOpenAI ? "Enabled" : "Disabled")\n"
        summary += "Local ML: \(enableLocalML ? "Enabled" : "Disabled")\n"
        summary += "BIN Lookup: \(enableBinLookup ? "Enabled" : "Disabled")\n"
        
        if !warnings.isEmpty {
            summary += "\nWarnings:\n"
            for warning in warnings {
                summary += "⚠️ \(warning)\n"
            }
        }
        
        return summary
    }
}

