//
//  RealGeocodingService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import CoreLocation
import Network

// MARK: - Real Geocoding Service
class RealGeocodingService: ObservableObject {
    static let shared = RealGeocodingService()
    
    private let session = URLSession.shared
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    
    // Real API endpoints
    private let googleMapsAPI = "https://maps.googleapis.com/maps/api/geocode/json"
    private let openCageAPI = "https://api.opencagedata.com/geocode/v1/json"
    
    // API Keys - Replace with real keys
    private let googleMapsAPIKey = "your-google-maps-api-key"
    private let openCageAPIKey = "your-opencage-api-key"
    
    // Cache for geocoding results
    private var geocodingCache: [String: GeocodingResult] = [:]
    private let cacheQueue = DispatchQueue(label: "geocoding.cache.queue", attributes: .concurrent)
    
    // Rate limiting
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 0.1 // 100ms between requests
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func geocodeAddress(_ address: String) async throws -> GeocodingResult {
        // Validate address
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeocodingError.invalidAddress
        }
        
        let normalizedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cachedResult = getCachedGeocoding(normalizedAddress) {
            logger.info("Geocoding result found in cache for: \(normalizedAddress)")
            return cachedResult
        }
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw GeocodingError.networkUnavailable
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Try Google Maps first, fallback to OpenCage
        do {
            let result = try await performGoogleMapsGeocoding(normalizedAddress)
            cacheGeocoding(normalizedAddress, result: result)
            return result
        } catch {
            logger.warning("Google Maps geocoding failed, trying OpenCage: \(error.localizedDescription)")
            
            do {
                let result = try await performOpenCageGeocoding(normalizedAddress)
                cacheGeocoding(normalizedAddress, result: result)
                return result
            } catch {
                logger.error("Both geocoding services failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResult {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return try await reverseGeocode(coordinate: coordinate)
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult {
        let address = "\(coordinate.latitude),\(coordinate.longitude)"
        
        // Check cache first
        if let cachedResult = getCachedGeocoding(address) {
            logger.info("Reverse geocoding result found in cache for: \(address)")
            return cachedResult
        }
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw GeocodingError.networkUnavailable
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Try Google Maps first, fallback to OpenCage
        do {
            let result = try await performGoogleMapsReverseGeocoding(coordinate)
            cacheGeocoding(address, result: result)
            return result
        } catch {
            logger.warning("Google Maps reverse geocoding failed, trying OpenCage: \(error.localizedDescription)")
            
            do {
                let result = try await performOpenCageReverseGeocoding(coordinate)
                cacheGeocoding(address, result: result)
                return result
            } catch {
                logger.error("Both reverse geocoding services failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getCachedGeocoding(_ address: String) -> GeocodingResult? {
        return cacheQueue.sync {
            return geocodingCache[address]
        }
    }
    
    private func cacheGeocoding(_ address: String, result: GeocodingResult) {
        cacheQueue.async(flags: .barrier) {
            self.geocodingCache[address] = result
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
    
    // MARK: - Google Maps Geocoding
    
    private func performGoogleMapsGeocoding(_ address: String) async throws -> GeocodingResult {
        guard !googleMapsAPIKey.isEmpty && googleMapsAPIKey != "your-google-maps-api-key" else {
            throw GeocodingError.apiKeyMissing
        }
        
        var components = URLComponents(string: googleMapsAPI)!
        components.queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "key", value: googleMapsAPIKey)
        ]
        
        guard let url = components.url else {
            throw GeocodingError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeocodingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GeocodingError.serverError(httpResponse.statusCode)
        }
        
        let googleResponse = try JSONDecoder().decode(GoogleMapsResponse.self, from: data)
        return try convertGoogleMapsToGeocodingResult(googleResponse, originalAddress: address)
    }
    
    private func performGoogleMapsReverseGeocoding(_ coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult {
        guard !googleMapsAPIKey.isEmpty && googleMapsAPIKey != "your-google-maps-api-key" else {
            throw GeocodingError.apiKeyMissing
        }
        
        var components = URLComponents(string: googleMapsAPI)!
        components.queryItems = [
            URLQueryItem(name: "latlng", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: googleMapsAPIKey)
        ]
        
        guard let url = components.url else {
            throw GeocodingError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeocodingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GeocodingError.serverError(httpResponse.statusCode)
        }
        
        let googleResponse = try JSONDecoder().decode(GoogleMapsResponse.self, from: data)
        return try convertGoogleMapsToGeocodingResult(googleResponse, originalAddress: "\(coordinate.latitude),\(coordinate.longitude)")
    }
    
    // MARK: - OpenCage Geocoding
    
    private func performOpenCageGeocoding(_ address: String) async throws -> GeocodingResult {
        guard !openCageAPIKey.isEmpty && openCageAPIKey != "your-opencage-api-key" else {
            throw GeocodingError.apiKeyMissing
        }
        
        var components = URLComponents(string: openCageAPI)!
        components.queryItems = [
            URLQueryItem(name: "q", value: address),
            URLQueryItem(name: "key", value: openCageAPIKey),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else {
            throw GeocodingError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeocodingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GeocodingError.serverError(httpResponse.statusCode)
        }
        
        let openCageResponse = try JSONDecoder().decode(OpenCageResponse.self, from: data)
        return try convertOpenCageToGeocodingResult(openCageResponse, originalAddress: address)
    }
    
    private func performOpenCageReverseGeocoding(_ coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult {
        guard !openCageAPIKey.isEmpty && openCageAPIKey != "your-opencage-api-key" else {
            throw GeocodingError.apiKeyMissing
        }
        
        var components = URLComponents(string: openCageAPI)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(coordinate.latitude)+\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: openCageAPIKey),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else {
            throw GeocodingError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeocodingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GeocodingError.serverError(httpResponse.statusCode)
        }
        
        let openCageResponse = try JSONDecoder().decode(OpenCageResponse.self, from: data)
        return try convertOpenCageToGeocodingResult(openCageResponse, originalAddress: "\(coordinate.latitude),\(coordinate.longitude)")
    }
    
    // MARK: - Response Conversion
    
    private func convertGoogleMapsToGeocodingResult(_ response: GoogleMapsResponse, originalAddress: String) throws -> GeocodingResult {
        guard response.status == "OK", let result = response.results.first else {
            throw GeocodingError.noResultsFound
        }
        
        let geometry = result.geometry
        let addressComponents = result.addressComponents
        
        let country = addressComponents.first { $0.types.contains("country") }
        let administrativeArea = addressComponents.first { $0.types.contains("administrative_area_level_1") }
        let locality = addressComponents.first { $0.types.contains("locality") }
        let postalCode = addressComponents.first { $0.types.contains("postal_code") }
        
        return GeocodingResult(
            address: result.formattedAddress ?? originalAddress,
            coordinate: CLLocationCoordinate2D(
                latitude: geometry.location.lat,
                longitude: geometry.location.lng
            ),
            country: country?.longName ?? "Unknown",
            countryCode: country?.shortName ?? "XX",
            administrativeArea: administrativeArea?.longName,
            locality: locality?.longName,
            postalCode: postalCode?.longName,
            confidence: 0.9
        )
    }
    
    private func convertOpenCageToGeocodingResult(_ response: OpenCageResponse, originalAddress: String) throws -> GeocodingResult {
        guard response.status.code == 200, let result = response.results.first else {
            throw GeocodingError.noResultsFound
        }
        
        let components = result.components
        
        return GeocodingResult(
            address: result.formatted ?? originalAddress,
            coordinate: CLLocationCoordinate2D(
                latitude: result.geometry.lat,
                longitude: result.geometry.lng
            ),
            country: components.country ?? "Unknown",
            countryCode: components.countryCode ?? "XX",
            administrativeArea: components.state,
            locality: components.city,
            postalCode: components.postcode,
            confidence: result.confidence ?? 0.8
        )
    }
    
    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
}

// MARK: - Google Maps API Response Models

struct GoogleMapsResponse: Codable {
    let results: [GoogleMapsResult]
    let status: String
}

struct GoogleMapsResult: Codable {
    let addressComponents: [AddressComponent]
    let formattedAddress: String?
    let geometry: Geometry
    let placeId: String?
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case addressComponents = "address_components"
        case formattedAddress = "formatted_address"
        case geometry
        case placeId = "place_id"
        case types
    }
}

struct AddressComponent: Codable {
    let longName: String
    let shortName: String
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case types
    }
}

struct Geometry: Codable {
    let location: Location
    let locationType: String?
    let viewport: Viewport?
    
    enum CodingKeys: String, CodingKey {
        case location
        case locationType = "location_type"
        case viewport
    }
}

struct Location: Codable {
    let lat: Double
    let lng: Double
}

struct Viewport: Codable {
    let northeast: Location
    let southwest: Location
}

// MARK: - OpenCage API Response Models

struct OpenCageResponse: Codable {
    let results: [OpenCageResult]
    let status: OpenCageStatus
}

struct OpenCageResult: Codable {
    let components: OpenCageComponents
    let confidence: Double?
    let formatted: String?
    let geometry: OpenCageGeometry
}

struct OpenCageComponents: Codable {
    let city: String?
    let country: String?
    let countryCode: String?
    let postcode: String?
    let state: String?
    
    enum CodingKeys: String, CodingKey {
        case city
        case country
        case countryCode = "country_code"
        case postcode
        case state
    }
}

struct OpenCageGeometry: Codable {
    let lat: Double
    let lng: Double
}

struct OpenCageStatus: Codable {
    let code: Int
    let message: String
}

// MARK: - Error Types

enum GeocodingError: LocalizedError {
    case invalidAddress
    case networkUnavailable
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case noResultsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid address provided."
        case .networkUnavailable:
            return "Network connection is not available."
        case .apiKeyMissing:
            return "API key is missing or invalid."
        case .invalidURL:
            return "Invalid URL for geocoding request."
        case .invalidResponse:
            return "Invalid response from geocoding service."
        case .serverError(let code):
            return "Server error: \(code)"
        case .noResultsFound:
            return "No geocoding results found for the given address."
        }
    }
}
