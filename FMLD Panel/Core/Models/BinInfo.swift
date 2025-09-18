//
//  BinInfo.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - BIN Information Model
struct BinInfo: Codable, Hashable, Identifiable, Equatable {
    let id = UUID()
    let bin: String
    let brand: String
    let scheme: String
    let type: String
    let country: String
    let countryCode: String
    let bank: String
    let level: String
    
    init(bin: String, brand: String, scheme: String, type: String, country: String, countryCode: String, bank: String, level: String) {
        self.bin = bin
        self.brand = brand
        self.scheme = scheme
        self.type = type
        self.country = country
        self.countryCode = countryCode
        self.bank = bank
        self.level = level
    }
    
    var riskLevel: String {
        if BinDatabaseService.shared.isHighRiskCountry(countryCode) || 
           BinDatabaseService.shared.isHighRiskBank(bank) {
            return "High"
        }
        return level == "Premium" || level == "Platinum" ? "Medium" : "Low"
    }
}

