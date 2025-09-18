//
//  RealBinLookupService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Network

// MARK: - Real BIN Lookup Service
class RealBinLookupService: ObservableObject {
    static let shared = RealBinLookupService()
    
    private let session = URLSession.shared
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    
    // Real API endpoints
    private let binlistAPI = "https://lookup.binlist.net/"
    private let binlistAPIKey = "your-binlist-api-key" // Replace with real API key
    
    // Cache for BIN data to reduce API calls
    private var binCache: [String: BinInfo] = [:]
    private let cacheQueue = DispatchQueue(label: "bin.cache.queue", attributes: .concurrent)
    
    // Rate limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func lookupBIN(_ bin: String) async throws -> BinInfo {
        // Validate BIN format
        guard isValidBIN(bin) else {
            throw BinLookupError.invalidBIN
        }
        
        // Check cache first
        if let cachedBinInfo = getCachedBIN(bin) {
            logger.info("BIN \(bin) found in cache")
            return cachedBinInfo
        }
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw BinLookupError.networkUnavailable
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Make API request
        let binInfo = try await performBINLookup(bin)
        
        // Cache the result
        cacheBIN(bin, binInfo: binInfo)
        
        return binInfo
    }
    
    // MARK: - Private Methods
    
    private func isValidBIN(_ bin: String) -> Bool {
        let cleanedBIN = bin.replacingOccurrences(of: " ", with: "")
        return cleanedBIN.count >= 6 && cleanedBIN.count <= 8 && cleanedBIN.allSatisfy { $0.isNumber }
    }
    
    private func getCachedBIN(_ bin: String) -> BinInfo? {
        return cacheQueue.sync {
            return binCache[bin]
        }
    }
    
    private func cacheBIN(_ bin: String, binInfo: BinInfo) {
        cacheQueue.async(flags: .barrier) {
            self.binCache[bin] = binInfo
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
    
    private func performBINLookup(_ bin: String) async throws -> BinInfo {
        let url = URL(string: "\(binlistAPI)\(bin)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FMLD-Panel/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add API key if available
        if !binlistAPIKey.isEmpty && binlistAPIKey != "your-binlist-api-key" {
            request.setValue(binlistAPIKey, forHTTPHeaderField: "X-API-Key")
        }
        
        logger.info("Making BIN lookup request for: \(bin)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BinLookupError.invalidResponse
            }
            
            logger.info("BIN lookup response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let binlistResponse = try JSONDecoder().decode(BinlistResponse.self, from: data)
                return try convertToBinInfo(binlistResponse, bin: bin)
                
            case 404:
                throw BinLookupError.binNotFound
                
            case 429:
                throw BinLookupError.rateLimitExceeded
                
            default:
                throw BinLookupError.serverError(httpResponse.statusCode)
            }
            
        } catch let error as BinLookupError {
            throw error
        } catch {
            logger.error("BIN lookup error: \(error.localizedDescription)")
            throw BinLookupError.networkError(error)
        }
    }
    
    private func convertToBinInfo(_ response: BinlistResponse, bin: String) throws -> BinInfo {
        return BinInfo(
            bin: bin,
            brand: response.brand ?? "Unknown",
            scheme: response.scheme ?? "Unknown",
            type: response.type ?? "Unknown",
            country: response.country?.name ?? "Unknown",
            countryCode: response.country?.alpha2 ?? "XX",
            bank: response.bank?.name ?? "Unknown",
            level: response.bank?.url?.isEmpty == false ? "Premium" : "Standard"
        )
    }
    
    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - Binlist API Response Models

struct BinlistResponse: Codable {
    let number: NumberInfo?
    let scheme: String?
    let type: String?
    let brand: String?
    let prepaid: Bool?
    let country: CountryInfo?
    let bank: BankInfo?
}

struct NumberInfo: Codable {
    let length: Int?
    let luhn: Bool?
}

struct CountryInfo: Codable {
    let numeric: String?
    let alpha2: String?
    let name: String?
    let emoji: String?
    let currency: String?
    let latitude: Double?
    let longitude: Double?
}

struct BankInfo: Codable {
    let name: String?
    let url: String?
    let phone: String?
    let city: String?
}

// MARK: - Error Types

enum BinLookupError: LocalizedError {
    case invalidBIN
    case networkUnavailable
    case networkError(Error)
    case invalidResponse
    case binNotFound
    case rateLimitExceeded
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidBIN:
            return "Invalid BIN format. BIN must be 6-8 digits."
        case .networkUnavailable:
            return "Network connection is not available."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from BIN lookup service."
        case .binNotFound:
            return "BIN not found in database."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
