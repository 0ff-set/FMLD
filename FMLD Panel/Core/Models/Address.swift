//
//  Address.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import CoreLocation

// MARK: - Address Model
struct Address: Identifiable, Codable, Hashable {
    let id: UUID
    let street: String
    let city: String
    let state: String?
    let postalCode: String
    let country: String
    let countryCode: String
    let latitude: Double?
    let longitude: Double?
    let isVerified: Bool
    let verificationDate: Date?
    let riskLevel: AddressRiskLevel
    let createdAt: Date
    
    var fullAddress: String {
        var components = [street, city]
        if let state = state {
            components.append(state)
        }
        components.append(postalCode)
        components.append(country)
        return components.joined(separator: ", ")
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(id: UUID = UUID(),
         street: String,
         city: String,
         state: String? = nil,
         postalCode: String,
         country: String,
         countryCode: String,
         latitude: Double? = nil,
         longitude: Double? = nil,
         isVerified: Bool = false,
         verificationDate: Date? = nil,
         riskLevel: AddressRiskLevel = .unknown,
         createdAt: Date = Date()) {
        self.id = id
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.isVerified = isVerified
        self.verificationDate = verificationDate
        self.riskLevel = riskLevel
        self.createdAt = createdAt
    }
}

// MARK: - Address Risk Level
enum AddressRiskLevel: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case unknown = "Unknown"
}