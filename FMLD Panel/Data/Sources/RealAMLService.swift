//
//  RealAMLService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Network

// MARK: - Real AML Service
class RealAMLService: ObservableObject {
    static let shared = RealAMLService()
    
    private let session = URLSession.shared
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    
    // Real API endpoints
    private let chainalysisAPI = "https://api.chainalysis.com/api/v1"
    private let ellipticAPI = "https://api.elliptic.co/v2"
    private let crystalAPI = "https://api.crystalblockchain.com"
    
    // API Keys - Replace with real keys
    private let chainalysisAPIKey = "your-chainalysis-api-key"
    private let ellipticAPIKey = "your-elliptic-api-key"
    private let crystalAPIKey = "your-crystal-api-key"
    
    // Cache for AML results
    private var amlCache: [String: AMLCheckResult] = [:]
    private let cacheQueue = DispatchQueue(label: "aml.cache.queue", attributes: .concurrent)
    
    // Rate limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 2.0 // 2 seconds between requests
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func checkCryptoAddress(_ address: String) async throws -> AMLCheckResult {
        // Validate address format
        guard isValidCryptoAddress(address) else {
            throw AMLError.invalidAddress
        }
        
        let normalizedAddress = address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cachedResult = getCachedAML(normalizedAddress) {
            logger.info("AML result found in cache for: \(normalizedAddress)")
            return cachedResult
        }
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw AMLError.networkUnavailable
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Try Chainalysis first, fallback to Elliptic, then Crystal
        do {
            let result = try await performChainalysisCheck(normalizedAddress)
            cacheAML(normalizedAddress, result: result)
            return result
        } catch {
            logger.warning("Chainalysis check failed, trying Elliptic: \(error.localizedDescription)")
            
            do {
                let result = try await performEllipticCheck(normalizedAddress)
                cacheAML(normalizedAddress, result: result)
                return result
            } catch {
                logger.warning("Elliptic check failed, trying Crystal: \(error.localizedDescription)")
                
                do {
                    let result = try await performCrystalCheck(normalizedAddress)
                    cacheAML(normalizedAddress, result: result)
                    return result
                } catch {
                    logger.error("All AML services failed: \(error.localizedDescription)")
                    throw error
                }
            }
        }
    }
    
    func checkTransaction(_ transactionHash: String) async throws -> AMLCheckResult {
        // Validate transaction hash format
        guard isValidTransactionHash(transactionHash) else {
            throw AMLError.invalidTransactionHash
        }
        
        let normalizedHash = transactionHash.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cachedResult = getCachedAML(normalizedHash) {
            logger.info("AML result found in cache for transaction: \(normalizedHash)")
            return cachedResult
        }
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw AMLError.networkUnavailable
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Try Chainalysis first
        do {
            let result = try await performChainalysisTransactionCheck(normalizedHash)
            cacheAML(normalizedHash, result: result)
            return result
        } catch {
            logger.error("Chainalysis transaction check failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidCryptoAddress(_ address: String) -> Bool {
        let cleanedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedAddress.count >= 26 && cleanedAddress.count <= 62
    }
    
    private func isValidTransactionHash(_ hash: String) -> Bool {
        let cleanedHash = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedHash.count == 64 && cleanedHash.allSatisfy { $0.isHexDigit }
    }
    
    private func getCachedAML(_ key: String) -> AMLCheckResult? {
        return cacheQueue.sync {
            return amlCache[key]
        }
    }
    
    private func cacheAML(_ key: String, result: AMLCheckResult) {
        cacheQueue.async(flags: .barrier) {
            self.amlCache[key] = result
        }
    }
    
    private func isNetworkAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            networkMonitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
            }
        }
    }
    
    private func enforceRateLimit() async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minRequestInterval {
            let delay = minRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    // MARK: - Chainalysis API
    
    private func performChainalysisCheck(_ address: String) async throws -> AMLCheckResult {
        guard !chainalysisAPIKey.isEmpty && chainalysisAPIKey != "your-chainalysis-api-key" else {
            throw AMLError.apiKeyMissing
        }
        
        let url = URL(string: "\(chainalysisAPI)/addresses/\(address)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Token \(chainalysisAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AMLError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
        let chainalysisResponse = try JSONDecoder().decode(RealChainalysisResponse.self, from: data)
        return convertChainalysisToAMLResult(chainalysisResponse, address: address)
            
        case 404:
            return AMLCheckResult(
                value: address,
                isBlacklisted: false,
                riskLevel: .low,
                source: "Address not found in Chainalysis database",
                confidence: 0.5
            )
            
        case 429:
            throw AMLError.rateLimitExceeded
            
        default:
            throw AMLError.serverError(httpResponse.statusCode)
        }
    }
    
    private func performChainalysisTransactionCheck(_ transactionHash: String) async throws -> AMLCheckResult {
        guard !chainalysisAPIKey.isEmpty && chainalysisAPIKey != "your-chainalysis-api-key" else {
            throw AMLError.apiKeyMissing
        }
        
        let url = URL(string: "\(chainalysisAPI)/transactions/\(transactionHash)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Token \(chainalysisAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AMLError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
        let chainalysisResponse = try JSONDecoder().decode(RealChainalysisTransactionResponse.self, from: data)
        return convertChainalysisTransactionToAMLResult(chainalysisResponse, transactionHash: transactionHash)
            
        case 404:
            return AMLCheckResult(
                value: transactionHash,
                isBlacklisted: false,
                riskLevel: .low,
                source: "Transaction not found in Chainalysis database",
                confidence: 0.5
            )
            
        case 429:
            throw AMLError.rateLimitExceeded
            
        default:
            throw AMLError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Elliptic API
    
    private func performEllipticCheck(_ address: String) async throws -> AMLCheckResult {
        guard !ellipticAPIKey.isEmpty && ellipticAPIKey != "your-elliptic-api-key" else {
            throw AMLError.apiKeyMissing
        }
        
        let url = URL(string: "\(ellipticAPI)/addresses/\(address)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(ellipticAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AMLError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
        let ellipticResponse = try JSONDecoder().decode(RealEllipticResponse.self, from: data)
        return convertEllipticToAMLResult(ellipticResponse, address: address)
            
        case 404:
            return AMLCheckResult(
                value: address,
                isBlacklisted: false,
                riskLevel: .low,
                source: "Address not found in Elliptic database",
                confidence: 0.5
            )
            
        case 429:
            throw AMLError.rateLimitExceeded
            
        default:
            throw AMLError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Crystal API
    
    private func performCrystalCheck(_ address: String) async throws -> AMLCheckResult {
        guard !crystalAPIKey.isEmpty && crystalAPIKey != "your-crystal-api-key" else {
            throw AMLError.apiKeyMissing
        }
        
        let url = URL(string: "\(crystalAPI)/addresses/\(address)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(crystalAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AMLError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
        let crystalResponse = try JSONDecoder().decode(RealCrystalResponse.self, from: data)
        return convertCrystalToAMLResult(crystalResponse, address: address)
            
        case 404:
            return AMLCheckResult(
                value: address,
                isBlacklisted: false,
                riskLevel: .low,
                source: "Address not found in Crystal database",
                confidence: 0.5
            )
            
        case 429:
            throw AMLError.rateLimitExceeded
            
        default:
            throw AMLError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Response Conversion
    
    private func convertChainalysisToAMLResult(_ response: RealChainalysisResponse, address: String) -> AMLCheckResult {
        let riskLevel: RiskLevel
        let isBlacklisted: Bool
        let source: String
        
        if response.riskScore >= 0.8 {
            riskLevel = .high
            isBlacklisted = true
            source = "High risk address identified by Chainalysis"
        } else if response.riskScore >= 0.5 {
            riskLevel = .medium
            isBlacklisted = false
            source = "Medium risk address identified by Chainalysis"
        } else {
            riskLevel = .low
            isBlacklisted = false
            source = "Low risk address identified by Chainalysis"
        }
        
        return AMLCheckResult(
            value: address,
            isBlacklisted: isBlacklisted,
            riskLevel: riskLevel,
            source: source,
            confidence: response.confidence ?? 0.8
        )
    }
    
    private func convertChainalysisTransactionToAMLResult(_ response: RealChainalysisTransactionResponse, transactionHash: String) -> AMLCheckResult {
        let riskLevel: RiskLevel
        let isBlacklisted: Bool
        let source: String
        
        if response.riskScore >= 0.8 {
            riskLevel = .high
            isBlacklisted = true
            source = "High risk transaction identified by Chainalysis"
        } else if response.riskScore >= 0.5 {
            riskLevel = .medium
            isBlacklisted = false
            source = "Medium risk transaction identified by Chainalysis"
        } else {
            riskLevel = .low
            isBlacklisted = false
            source = "Low risk transaction identified by Chainalysis"
        }
        
        return AMLCheckResult(
            value: transactionHash,
            isBlacklisted: isBlacklisted,
            riskLevel: riskLevel,
            source: source,
            confidence: response.confidence ?? 0.8
        )
    }
    
    private func convertEllipticToAMLResult(_ response: RealEllipticResponse, address: String) -> AMLCheckResult {
        let riskLevel: RiskLevel
        let isBlacklisted: Bool
        let source: String
        
        if response.riskScore >= 0.8 {
            riskLevel = .high
            isBlacklisted = true
            source = "High risk address identified by Elliptic"
        } else if response.riskScore >= 0.5 {
            riskLevel = .medium
            isBlacklisted = false
            source = "Medium risk address identified by Elliptic"
        } else {
            riskLevel = .low
            isBlacklisted = false
            source = "Low risk address identified by Elliptic"
        }
        
        return AMLCheckResult(
            value: address,
            isBlacklisted: isBlacklisted,
            riskLevel: riskLevel,
            source: source,
            confidence: response.confidence ?? 0.8
        )
    }
    
    private func convertCrystalToAMLResult(_ response: RealCrystalResponse, address: String) -> AMLCheckResult {
        let riskLevel: RiskLevel
        let isBlacklisted: Bool
        let source: String
        
        if response.riskScore >= 0.8 {
            riskLevel = .high
            isBlacklisted = true
            source = "High risk address identified by Crystal"
        } else if response.riskScore >= 0.5 {
            riskLevel = .medium
            isBlacklisted = false
            source = "Medium risk address identified by Crystal"
        } else {
            riskLevel = .low
            isBlacklisted = false
            source = "Low risk address identified by Crystal"
        }
        
        return AMLCheckResult(
            value: address,
            isBlacklisted: isBlacklisted,
            riskLevel: riskLevel,
            source: source,
            confidence: response.confidence ?? 0.8
        )
    }
    
    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - API Response Models

struct RealChainalysisResponse: Codable {
    let address: String
    let riskScore: Double
    let confidence: Double?
    let category: String?
    let subcategory: String?
    
    enum CodingKeys: String, CodingKey {
        case address
        case riskScore = "risk_score"
        case confidence
        case category
        case subcategory
    }
}

struct RealChainalysisTransactionResponse: Codable {
    let transactionHash: String
    let riskScore: Double
    let confidence: Double?
    let category: String?
    let subcategory: String?
    
    enum CodingKeys: String, CodingKey {
        case transactionHash = "transaction_hash"
        case riskScore = "risk_score"
        case confidence
        case category
        case subcategory
    }
}

struct RealEllipticResponse: Codable {
    let address: String
    let riskScore: Double
    let confidence: Double?
    let category: String?
    let subcategory: String?
    
    enum CodingKeys: String, CodingKey {
        case address
        case riskScore = "risk_score"
        case confidence
        case category
        case subcategory
    }
}

struct RealCrystalResponse: Codable {
    let address: String
    let riskScore: Double
    let confidence: Double?
    let category: String?
    let subcategory: String?
    
    enum CodingKeys: String, CodingKey {
        case address
        case riskScore = "risk_score"
        case confidence
        case category
        case subcategory
    }
}

// MARK: - Error Types

enum AMLError: LocalizedError {
    case invalidAddress
    case invalidTransactionHash
    case networkUnavailable
    case apiKeyMissing
    case invalidResponse
    case serverError(Int)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid crypto address format."
        case .invalidTransactionHash:
            return "Invalid transaction hash format."
        case .networkUnavailable:
            return "Network connection is not available."
        case .apiKeyMissing:
            return "API key is missing or invalid."
        case .invalidResponse:
            return "Invalid response from AML service."
        case .serverError(let code):
            return "Server error: \(code)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}
