//
//  ProductionAPIService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Network
import CoreLocation

// MARK: - Production API Service
class ProductionAPIService: ObservableObject {
    static let shared = ProductionAPIService()
    
    private let session = URLSession.shared
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    
    // Real API endpoints - these would be your actual service URLs
    private let binLookupAPI = "https://api.binlist.net/v1/"
    private let geocodingAPI = "https://api.opencagedata.com/geocode/v1/"
    private let amlAPI = "https://api.chainalysis.com/v1/"
    private let fraudDetectionAPI = "https://api.fraudlabspro.com/v1/"
    
    // API Keys - these should be stored securely in production
    private let binLookupKey = "your-binlookup-api-key"
    private let geocodingKey = "your-opencage-api-key"
    private let amlKey = "your-chainalysis-api-key"
    private let fraudDetectionKey = "your-fraudlabs-api-key"
    
    @Published var isConnected = false
    @Published var lastError: Error?
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - BIN Lookup
    func lookupBIN(_ bin: String) async throws -> BinInfo {
        guard isConnected else {
            throw APIError.noConnection
        }
        
        let url = URL(string: "\(binLookupAPI)\(bin)")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(binLookupKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let binResponse = try JSONDecoder().decode(BinLookupResponse.self, from: data)
        return binResponse.toBinInfo()
    }
    
    // MARK: - Geocoding
    func geocodeAddress(_ address: String) async throws -> GeocodingResult {
        guard isConnected else {
            throw APIError.noConnection
        }
        
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(geocodingAPI)json?q=\(encodedAddress)&key=\(geocodingKey)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let geocodingResponse = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return geocodingResponse.toGeocodingResult()
    }
    
    // MARK: - AML Check
    func checkAML(_ address: String) async throws -> AMLCheckResult {
        guard isConnected else {
            throw APIError.noConnection
        }
        
        let url = URL(string: "\(amlAPI)addresses/\(address)")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(amlKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let amlResponse = try JSONDecoder().decode(AMLResponse.self, from: data)
        return amlResponse.toAMLCheckResult()
    }
    
    // MARK: - Fraud Detection
    func analyzeTransaction(_ transaction: Transaction) async throws -> FraudAnalysisResult {
        guard isConnected else {
            throw APIError.noConnection
        }
        
        let url = URL(string: "\(fraudDetectionAPI)transaction")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(fraudDetectionKey, forHTTPHeaderField: "X-API-Key")
        
        let fraudRequest = FraudAnalysisRequest(from: transaction)
        request.httpBody = try JSONEncoder().encode(fraudRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let fraudResponse = try JSONDecoder().decode(FraudAnalysisResponse.self, from: data)
        return fraudResponse.toFraudAnalysisResult()
    }
}

// MARK: - API Models
struct BinLookupResponse: Codable {
    let number: BinNumber
    let scheme: String?
    let type: String?
    let brand: String?
    let country: Country
    let bank: Bank?
    
    struct BinNumber: Codable {
        let length: Int
        let luhn: Bool
    }
    
    struct Country: Codable {
        let numeric: String
        let alpha2: String
        let name: String
        let emoji: String
        let currency: String
        let latitude: Double
        let longitude: Double
    }
    
    struct Bank: Codable {
        let name: String
        let url: String?
        let phone: String?
        let city: String?
    }
    
    func toBinInfo() -> BinInfo {
        return BinInfo(
            bin: number.length > 0 ? String(number.length) : "",
            brand: brand ?? "Unknown",
            scheme: scheme ?? "Unknown",
            type: type ?? "Unknown",
            country: country.name,
            countryCode: country.alpha2,
            bank: bank?.name ?? "Unknown",
            level: "Standard"
        )
    }
}

struct GeocodingResponse: Codable {
    let results: [GeocodingResultData]
    
    struct GeocodingResultData: Codable {
        let components: Components
        let geometry: Geometry
        
        struct Components: Codable {
            let country: String?
            let countryCode: String?
            let state: String?
            let city: String?
            let postcode: String?
        }
        
        struct Geometry: Codable {
            let lat: Double
            let lng: Double
        }
    }
    
    func toGeocodingResult() -> GeocodingResult {
        guard let firstResult = results.first else {
            return GeocodingResult(
                address: "Unknown",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                country: "Unknown",
                countryCode: "XX",
                administrativeArea: "Unknown",
                locality: "Unknown",
                postalCode: "00000",
                confidence: 0.0
            )
        }
        
        return GeocodingResult(
            address: "\(firstResult.components.city ?? ""), \(firstResult.components.state ?? ""), \(firstResult.components.country ?? "")",
            coordinate: CLLocationCoordinate2D(latitude: firstResult.geometry.lat, longitude: firstResult.geometry.lng),
            country: firstResult.components.country ?? "Unknown",
            countryCode: firstResult.components.countryCode ?? "XX",
            administrativeArea: firstResult.components.state ?? "Unknown",
            locality: firstResult.components.city ?? "Unknown",
            postalCode: firstResult.components.postcode ?? "00000",
            confidence: 0.9
        )
    }
}

struct AMLResponse: Codable {
    let address: String
    let riskScore: Double
    let riskLevel: String
    let category: String?
    let source: String?
    
    func toAMLCheckResult() -> AMLCheckResult {
        let riskLevel: RiskLevel
        switch self.riskLevel.lowercased() {
        case "high":
            riskLevel = .high
        case "medium":
            riskLevel = .medium
        default:
            riskLevel = .low
        }
        
        return AMLCheckResult(
            value: address,
            isBlacklisted: riskLevel == .high,
            riskLevel: riskLevel,
            source: source,
            confidence: riskScore
        )
    }
}

struct FraudAnalysisRequest: Codable {
    let transactionId: String
    let amount: Double
    let currency: String
    let cardNumber: String
    let ipAddress: String
    let userAgent: String
    let country: String
    let city: String
    let timestamp: String
    
    init(from transaction: Transaction) {
        self.transactionId = transaction.id.uuidString
        self.amount = transaction.amount
        self.currency = transaction.currency
        self.cardNumber = transaction.cardNumber
        self.ipAddress = transaction.ipAddress
        self.userAgent = transaction.userAgent
        self.country = transaction.country
        self.city = transaction.city
        self.timestamp = ISO8601DateFormatter().string(from: transaction.timestamp)
    }
}

struct FraudAnalysisResponse: Codable {
    let transactionId: String
    let riskScore: Double
    let riskLevel: String
    let recommendation: String
    let reasons: [String]
    let confidence: Double
    
    func toFraudAnalysisResult() -> FraudAnalysisResult {
        let riskLevel: RiskLevel
        switch self.riskLevel.lowercased() {
        case "high":
            riskLevel = .high
        case "medium":
            riskLevel = .medium
        default:
            riskLevel = .low
        }
        
        return FraudAnalysisResult(
            transactionId: transactionId,
            riskScore: riskScore,
            riskLevel: riskLevel,
            recommendation: recommendation,
            reasons: reasons,
            confidence: confidence
        )
    }
}

struct FraudAnalysisResult {
    let transactionId: String
    let riskScore: Double
    let riskLevel: RiskLevel
    let recommendation: String
    let reasons: [String]
    let confidence: Double
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case noConnection
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
