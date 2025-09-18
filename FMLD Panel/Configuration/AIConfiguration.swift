//
//  AIConfiguration.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

/// Configuration for AI services and models
struct AIConfiguration {
    
    // MARK: - OpenAI Configuration
    static var openAIAPIKey: String? {
        SecretsManager.shared.openAIAPIKey
    }
    static let openAIBaseURL = "https://api.openai.com/v1"
    static let openAIModel = "gpt-4"
    static let openAIMaxTokens = 500
    static let openAITemperature = 0.3
    
    // MARK: - Local ML Configuration
    static let localModelPath = "LocalModels"
    static let coreMLModelName = "FraudDetectionModel"
    static let enableLocalInference = true
    static let localModelTimeout = 5.0
    
    // MARK: - Ollama Configuration (Alternative to OpenAI)
    static let ollamaBaseURL = "http://localhost:11434"
    static let ollamaModel = "llama3.1:8b"
    static let ollamaMaxTokens = 500
    static let ollamaTemperature = 0.3
    
    // MARK: - Model Configuration
    static let embeddingDimension = 384
    static let maxSequenceLength = 512
    static let batchSize = 32
    static let learningRate = 0.001
    static let epochs = 100
    
    // MARK: - Neural Network Configuration
    static let hiddenLayerSizes = [128, 64, 32]
    static let dropoutRate = 0.2
    static let activationFunction = "relu"
    static let optimizer = "adam"
    
    // MARK: - Training Configuration
    static let trainingDataSplit = 0.8 // 80% training, 20% validation
    static let minTrainingSamples = 1000
    static let maxTrainingSamples = 100000
    static let retrainingInterval = 24 * 60 * 60 // 24 hours in seconds
    
    // MARK: - Feature Configuration
    static let numericalFeatures = [
        "amount", "timestamp", "bin_length", "country_length", "city_length",
        "hour", "day_of_week", "day_of_month", "high_amount_flag",
        "us_transaction_flag", "visa_flag"
    ]
    
    static let categoricalFeatures = [
        "country", "city", "bin", "currency", "card_brand"
    ]
    
    static let textFeatures = [
        "user_agent", "billing_address", "merchant_description"
    ]
    
    // MARK: - Risk Thresholds
    static let lowRiskThreshold = 0.3
    static let mediumRiskThreshold = 0.6
    static let highRiskThreshold = 0.8
    
    // MARK: - API Rate Limits
    static let openAIRateLimit = 60 // requests per minute
    static let awsRateLimit = 100 // requests per minute
    static let googleCloudRateLimit = 1000 // requests per minute
    
    // MARK: - Cache Configuration
    static let embeddingCacheSize = 10000
    static let modelCacheSize = 100
    static let cacheExpirationTime = 24 * 60 * 60 // 24 hours
    
    // MARK: - Monitoring Configuration
    static let enablePerformanceMonitoring = true
    static let enableErrorTracking = true
    static let enableUsageAnalytics = true
    static let logLevel = "info"
    
    // MARK: - Security Configuration
    static let enableEncryption = true
    static let encryptionKey = "your-encryption-key"
    static let enableDataAnonymization = true
    static let enableAuditLogging = true
    
    // MARK: - Fallback Configuration
    static let enableFallbackModels = true
    static let fallbackModelAccuracy = 0.7
    static let fallbackTimeout = 5.0 // seconds
    
    // MARK: - Real-time Configuration
    static let enableRealTimeAnalysis = true
    static let realTimeBatchSize = 10
    static let realTimeProcessingInterval = 1.0 // seconds
    
    // MARK: - Model Versions
    static let currentModelVersions = [
        "fraud_detection": "2.1.0",
        "risk_classifier": "1.5.0",
        "anomaly_detector": "1.2.0",
        "embedding_model": "1.0.0",
        "llm_model": "gpt-4-turbo"
    ]
    
    // MARK: - Feature Flags
    static let enableLLMAnalysis = true
    static let enableNeuralNetworks = true
    static let enableEnsembleMethods = true
    static let enableOnlineLearning = false
    static let enableFederatedLearning = false
    
    // MARK: - Data Sources
    static let enableExternalDataSources = true
    static let externalDataSources = [
        "binlist.net",
        "openexchangerates.org",
        "ipapi.co",
        "fraud.net"
    ]
    
    // MARK: - Alert Configuration
    static let enableAlerts = true
    static let alertThresholds = [
        "high_risk": 0.8,
        "medium_risk": 0.6,
        "low_risk": 0.3,
        "anomaly": 0.9
    ]
    
    // MARK: - Reporting Configuration
    static let enableReports = true
    static let reportGenerationInterval = 24 * 60 * 60 // 24 hours
    static let reportRetentionDays = 365
    
    // MARK: - Compliance Configuration
    static let enableComplianceChecks = true
    static let complianceStandards = ["PCI-DSS", "SOX", "GDPR", "CCPA"]
    static let enableDataRetention = true
    static let dataRetentionDays = 2555 // 7 years
    
    // MARK: - Performance Configuration
    static let enablePerformanceOptimization = true
    static let maxConcurrentRequests = 10
    static let requestTimeout = 30.0 // seconds
    static let enableCaching = true
    static let enableCompression = true
    
    // MARK: - Testing Configuration
    static let enableABTesting = true
    static let abTestTrafficSplit = 0.5
    static let enableCanaryDeployments = false
    static let canaryTrafficPercentage = 0.1
    
    // MARK: - Backup Configuration
    static let enableModelBackup = true
    static let backupInterval = 24 * 60 * 60 // 24 hours
    static let backupRetentionDays = 30
    static let enableModelVersioning = true
    
    // MARK: - Environment Configuration
    static let environment = "development" // development, staging, production
    static let enableDebugMode = true
    static let enableVerboseLogging = false
    static let enableProfiling = false
}
