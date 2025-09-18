//
//  BinDatabaseService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation

// MARK: - BIN Database Service
class BinDatabaseService: ObservableObject {
    static let shared = BinDatabaseService()
    
    @Published var binData: [String: BinInfo] = [:]
    private let logger = Logger.shared
    private let freeBinDatabase = FreeBinDatabase.shared
    
    private init() {
        setupBinDatabase()
    }
    
    // MARK: - Add BIN
    func addBin(_ binInfo: BinInfo) {
        binData[binInfo.bin] = binInfo
        logger.info("Added BIN: \(binInfo.bin) - \(binInfo.bank)")
    }
    
    // MARK: - Update BIN
    func updateBin(_ binInfo: BinInfo) {
        binData[binInfo.bin] = binInfo
        logger.info("Updated BIN: \(binInfo.bin) - \(binInfo.bank)")
    }
    
    // MARK: - Delete BIN
    func deleteBin(_ bin: String) {
        binData.removeValue(forKey: bin)
        logger.info("Deleted BIN: \(bin)")
    }
    
    // MARK: - Setup BIN Database
    private func setupBinDatabase() {
        // Wait for free database to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncWithFreeDatabase()
        }
    }
    
    private func syncWithFreeDatabase() {
        // Copy data from free database
        for (bin, info) in freeBinDatabase.allBinData {
            binData[bin] = info
        }
        logger.info("Synced with free BIN database: \(binData.count) records")
    }
    
    func lookupBin(_ bin: String) -> BinInfo? {
        let cleanBin = String(bin.prefix(6))
        
        // First try local cache
        if let cachedBin = binData[cleanBin] {
            return cachedBin
        }
        
        // Then try free database
        if let freeBin = freeBinDatabase.lookupBin(cleanBin) {
            binData[cleanBin] = freeBin // Cache it
            return freeBin
        }
        
        return nil
    }
    
    func isHighRiskCountry(_ countryCode: String) -> Bool {
        return freeBinDatabase.isHighRiskCountry(countryCode)
    }
    
    func isHighRiskBank(_ bank: String) -> Bool {
        return freeBinDatabase.isHighRiskBank(bank)
    }
}

// MARK: - BIN Database Service Protocol
protocol BinDatabaseServiceProtocol {
    func lookupBin(_ bin: String) -> BinInfo?
    func addBin(_ binInfo: BinInfo)
    func updateBin(_ binInfo: BinInfo)
    func deleteBin(_ bin: String)
}

// MARK: - Mock BIN Database Service
class MockBinDatabaseService: BinDatabaseServiceProtocol, ObservableObject {
    static let shared = MockBinDatabaseService()
    
    @Published var binData: [String: BinInfo] = [:]
    
    private init() {
        loadSampleData()
    }
    
    func lookupBin(_ bin: String) -> BinInfo? {
        return binData[bin]
    }
    
    func addBin(_ binInfo: BinInfo) {
        binData[binInfo.bin] = binInfo
    }
    
    func updateBin(_ binInfo: BinInfo) {
        binData[binInfo.bin] = binInfo
    }
    
    func deleteBin(_ bin: String) {
        binData.removeValue(forKey: bin)
    }
    
    private func loadSampleData() {
        // Sample BIN data for testing
        let sampleBins = [
            BinInfo(bin: "411111", brand: "Visa", scheme: "Visa", type: "Debit", country: "United States", countryCode: "US", bank: "Chase Bank", level: "Classic"),
            BinInfo(bin: "555555", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "United States", countryCode: "US", bank: "Bank of America", level: "Gold"),
            BinInfo(bin: "378282", brand: "American Express", scheme: "American Express", type: "Credit", country: "United States", countryCode: "US", bank: "American Express", level: "Platinum"),
            BinInfo(bin: "601111", brand: "Discover", scheme: "Discover", type: "Credit", country: "United States", countryCode: "US", bank: "Discover Bank", level: "Classic"),
            BinInfo(bin: "400000", brand: "Visa", scheme: "Visa", type: "Debit", country: "Canada", countryCode: "CA", bank: "Royal Bank of Canada", level: "Classic"),
            BinInfo(bin: "510000", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "United Kingdom", countryCode: "GB", bank: "HSBC", level: "Gold"),
            BinInfo(bin: "400001", brand: "Visa", scheme: "Visa", type: "Debit", country: "Germany", countryCode: "DE", bank: "Deutsche Bank", level: "Classic"),
            BinInfo(bin: "510001", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "France", countryCode: "FR", bank: "BNP Paribas", level: "Gold"),
            BinInfo(bin: "400002", brand: "Visa", scheme: "Visa", type: "Debit", country: "Japan", countryCode: "JP", bank: "MUFG Bank", level: "Classic"),
            BinInfo(bin: "510002", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "Australia", countryCode: "AU", bank: "Commonwealth Bank", level: "Gold")
        ]
        
        for binInfo in sampleBins {
            binData[binInfo.bin] = binInfo
        }
    }
}

// MARK: - BIN Info Model
typealias BINInfo = BinInfo