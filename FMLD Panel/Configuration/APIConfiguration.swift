//
//  APIConfiguration.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - API Configuration
struct APIConfiguration {
    
    // MARK: - BIN Lookup APIs
    struct BinLookup {
        static var binlistAPIKey: String? {
            SecretsManager.shared.binlistAPIKey
        }
        static let binlistAPI = "https://lookup.binlist.net/"
        
        // Free alternatives (no API key required)
        static let binlistNetAPI = "https://api.binlist.net/v1/"
        static let freeBinAPI = "https://api.binlist.net/json/"
    }
    
    // MARK: - Geocoding APIs
    struct Geocoding {
        static var googleMapsAPIKey: String? {
            SecretsManager.shared.googleMapsAPIKey
        }
        static let googleMapsAPI = "https://maps.googleapis.com/maps/api/geocode/json"
        
        static var mapboxAPIKey: String? {
            SecretsManager.shared.mapboxAPIKey
        }
        static let mapboxAPI = "https://api.mapbox.com/geocoding/v5/mapbox.places/"
        
        // Free alternatives
        static let openStreetMapAPI = "https://nominatim.openstreetmap.org/"
    }
    
    // MARK: - AML/Blacklist APIs
    struct AML {
        static let chainalysisAPIKey = "your-chainalysis-api-key"
        static let chainalysisAPI = "https://api.chainalysis.com/api/v1"
        
        static let ellipticAPIKey = "your-elliptic-api-key"
        static let ellipticAPI = "https://api.elliptic.co/v2"
        
        static let crystalAPIKey = "your-crystal-api-key"
        static let crystalAPI = "https://api.crystalblockchain.com"
    }
    
    // MARK: - Payment Processing
    struct Payment {
        static var stripePublishableKey: String? {
            SecretsManager.shared.stripePublishableKey
        }
        static var stripeSecretKey: String? {
            SecretsManager.shared.stripeSecretKey
        }
        static let stripeAPI = "https://api.stripe.com/v1"
        
        // Alternative payment processors
        static let paypalClientId = "your-paypal-client-id"
        static let paypalSecret = "your-paypal-secret"
        static let paypalAPI = "https://api.paypal.com/v1"
        
        static let squareApplicationId = "your-square-application-id"
        static let squareAccessToken = "your-square-access-token"
        static let squareAPI = "https://connect.squareup.com/v2"
    }
    
    // MARK: - Fraud Detection APIs
    struct FraudDetection {
        static let siftAPIKey = "your-sift-api-key"
        static let siftAPI = "https://api.siftscience.com/v205/events"
        
        static let kountAPIKey = "your-kount-api-key"
        static let kountAPI = "https://api.kount.net/rpc/v1"
        
        static let signifydAPIKey = "your-signifyd-api-key"
        static let signifydAPI = "https://api.signifyd.com/v2"
    }
    
    // MARK: - Machine Learning APIs
    struct MachineLearning {
        static let openAIAPIKey = "your-openai-api-key"
        static let openAIAPI = "https://api.openai.com/v1"
        
        static let huggingFaceAPIKey = "your-huggingface-api-key"
        static let huggingFaceAPI = "https://api-inference.huggingface.co"
        
        static let azureMLAPIKey = "your-azure-ml-api-key"
        static let azureMLAPI = "https://your-workspace.api.azureml.net"
    }
    
    // MARK: - Database Configuration
    struct Database {
        static let postgresURL = "postgresql://username:password@localhost:5432/fmld_panel"
        static let redisURL = "redis://localhost:6379"
        static let mongodbURL = "mongodb://localhost:27017/fmld_panel"
    }
    
    // MARK: - Monitoring and Analytics
    struct Monitoring {
        static let sentryDSN = "your-sentry-dsn"
        static let mixpanelToken = "your-mixpanel-token"
        static let amplitudeAPIKey = "your-amplitude-api-key"
        static let datadogAPIKey = "your-datadog-api-key"
    }
    
    // MARK: - Security
    struct Security {
        static let encryptionKey = "your-encryption-key-32-chars"
        static let jwtSecret = "your-jwt-secret"
        static let hmacSecret = "your-hmac-secret"
    }
    
    // MARK: - Environment Configuration
    struct Environment {
        static let isProduction = false
        static let debugMode = true
        static let logLevel = "debug"
        static let apiTimeout = 30.0
        static let maxRetries = 3
    }
}

// MARK: - API Key Validation
extension APIConfiguration {
    
    static func validateAPIKeys() -> [String] {
        var missingKeys: [String] = []
        
        // Check BIN Lookup APIs
        if APIConfiguration.BinLookup.binlistAPIKey == "your-binlist-api-key" {
            missingKeys.append("Binlist API Key")
        }
        
        // Check Geocoding APIs
        if APIConfiguration.Geocoding.googleMapsAPIKey == "your-google-maps-api-key" {
            missingKeys.append("Google Maps API Key")
        }
        
        // OpenCage API removed - using free alternatives
        
        // Check AML APIs
        if APIConfiguration.AML.chainalysisAPIKey == "your-chainalysis-api-key" {
            missingKeys.append("Chainalysis API Key")
        }
        
        if APIConfiguration.AML.ellipticAPIKey == "your-elliptic-api-key" {
            missingKeys.append("Elliptic API Key")
        }
        
        // Check Payment APIs
        if APIConfiguration.Payment.stripeSecretKey == "sk_test_your_secret_key" {
            missingKeys.append("Stripe Secret Key")
        }
        
        if APIConfiguration.Payment.stripePublishableKey == "pk_test_your_publishable_key" {
            missingKeys.append("Stripe Publishable Key")
        }
        
        return missingKeys
    }
    
    static func getMissingAPIKeysMessage() -> String {
        let missingKeys = validateAPIKeys()
        
        if missingKeys.isEmpty {
            return "All API keys are configured correctly."
        } else {
            return "Missing API keys: \(missingKeys.joined(separator: ", "))"
        }
    }
}

// MARK: - API Rate Limits
struct APIRateLimits {
    static let binLookup = 1000 // requests per hour
    static let geocoding = 2500 // requests per day
    static let aml = 100 // requests per hour
    static let payment = 100 // requests per second
    static let fraudDetection = 500 // requests per hour
}

// MARK: - API Endpoints
struct APIEndpoints {
    static let binLookup = "https://lookup.binlist.net/"
    static let geocoding = "https://maps.googleapis.com/maps/api/geocode/json"
    static let aml = "https://api.chainalysis.com/api/v1"
    static let payment = "https://api.stripe.com/v1"
    static let fraudDetection = "https://api.siftscience.com/v205/events"
}
