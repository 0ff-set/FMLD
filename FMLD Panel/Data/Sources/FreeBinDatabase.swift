//
//  FreeBinDatabase.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

/// Free BIN database service using CSV data and free APIs
class FreeBinDatabase: ObservableObject {
    static let shared = FreeBinDatabase()
    
    @Published var isLoaded = false
    @Published var binCount = 0
    
    private let logger = Logger.shared
    private var binData: [String: BinInfo] = [:]
    
    // Public access to binData for other services
    var allBinData: [String: BinInfo] {
        return binData
    }
    private let freeAPIEndpoints = [
        "https://api.binlist.net/json/",
        "https://lookup.binlist.net/"
    ]
    
    private init() {
        loadBinData()
    }
    
    // MARK: - Data Loading
    
    private func loadBinData() {
        Task {
            await loadFromCSV()
            await loadFromFreeAPI()
            
            await MainActor.run {
                binCount = binData.count
                isLoaded = true
                logger.info("Loaded \(binCount) BIN records")
            }
        }
    }
    
    private func loadFromCSV() async {
        // Try to load from bundled CSV file
        guard let csvPath = Bundle.main.path(forResource: "bin_database", ofType: "csv") else {
            logger.warning("BIN CSV file not found, creating sample data")
            await createSampleBinData()
            return
        }
        
        do {
            let csvContent = try String(contentsOfFile: csvPath)
            await parseCSVContent(csvContent)
        } catch {
            logger.error("Failed to load CSV: \(error.localizedDescription)")
            await createSampleBinData()
        }
    }
    
    private func parseCSVContent(_ content: String) async {
        let lines = content.components(separatedBy: .newlines)
        var parsedCount = 0
        
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            
            let fields = line.components(separatedBy: ",")
            if fields.count >= 7 {
                let binInfo = BinInfo(
                    bin: fields[0].trimmingCharacters(in: .whitespaces),
                    brand: fields[1].trimmingCharacters(in: .whitespaces),
                    scheme: fields[2].trimmingCharacters(in: .whitespaces),
                    type: fields[3].trimmingCharacters(in: .whitespaces),
                    country: fields[4].trimmingCharacters(in: .whitespaces),
                    countryCode: fields[5].trimmingCharacters(in: .whitespaces),
                    bank: fields[6].trimmingCharacters(in: .whitespaces),
                    level: fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : "Standard"
                )
                
                binData[binInfo.bin] = binInfo
                parsedCount += 1
            }
        }
        
        logger.info("Parsed \(parsedCount) BIN records from CSV")
    }
    
    private func createSampleBinData() async {
        // Create comprehensive sample BIN data
        let sampleBins = [
            // Visa cards
            BinInfo(bin: "411111", brand: "Visa", scheme: "Visa", type: "Debit", country: "United States", countryCode: "US", bank: "Chase Bank", level: "Classic"),
            BinInfo(bin: "424242", brand: "Visa", scheme: "Visa", type: "Credit", country: "United Kingdom", countryCode: "GB", bank: "Barclays Bank", level: "Gold"),
            BinInfo(bin: "400000", brand: "Visa", scheme: "Visa", type: "Debit", country: "Canada", countryCode: "CA", bank: "Royal Bank of Canada", level: "Classic"),
            BinInfo(bin: "400001", brand: "Visa", scheme: "Visa", type: "Credit", country: "Germany", countryCode: "DE", bank: "Deutsche Bank", level: "Gold"),
            BinInfo(bin: "400002", brand: "Visa", scheme: "Visa", type: "Debit", country: "France", countryCode: "FR", bank: "BNP Paribas", level: "Classic"),
            BinInfo(bin: "400003", brand: "Visa", scheme: "Visa", type: "Credit", country: "Japan", countryCode: "JP", bank: "MUFG Bank", level: "Platinum"),
            BinInfo(bin: "400004", brand: "Visa", scheme: "Visa", type: "Debit", country: "Australia", countryCode: "AU", bank: "Commonwealth Bank", level: "Classic"),
            BinInfo(bin: "400005", brand: "Visa", scheme: "Visa", type: "Credit", country: "Italy", countryCode: "IT", bank: "UniCredit", level: "Gold"),
            
            // Mastercard
            BinInfo(bin: "555555", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "United States", countryCode: "US", bank: "Bank of America", level: "Gold"),
            BinInfo(bin: "510510", brand: "Mastercard", scheme: "Mastercard", type: "Debit", country: "United Kingdom", countryCode: "GB", bank: "HSBC", level: "Classic"),
            BinInfo(bin: "520000", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "Germany", countryCode: "DE", bank: "Commerzbank", level: "Gold"),
            BinInfo(bin: "530000", brand: "Mastercard", scheme: "Mastercard", type: "Debit", country: "France", countryCode: "FR", bank: "Crédit Agricole", level: "Classic"),
            BinInfo(bin: "540000", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "Canada", countryCode: "CA", bank: "TD Bank", level: "Platinum"),
            
            // American Express
            BinInfo(bin: "378282", brand: "American Express", scheme: "American Express", type: "Credit", country: "United States", countryCode: "US", bank: "American Express", level: "Premium"),
            BinInfo(bin: "371449", brand: "American Express", scheme: "American Express", type: "Credit", country: "United Kingdom", countryCode: "GB", bank: "American Express", level: "Gold"),
            
            // Discover
            BinInfo(bin: "601111", brand: "Discover", scheme: "Discover", type: "Credit", country: "United States", countryCode: "US", bank: "Discover Bank", level: "Classic"),
            BinInfo(bin: "601100", brand: "Discover", scheme: "Discover", type: "Credit", country: "United States", countryCode: "US", bank: "Discover Bank", level: "Gold"),
            
            // Test cards for different countries
            BinInfo(bin: "400000", brand: "Visa", scheme: "Visa", type: "Debit", country: "Brazil", countryCode: "BR", bank: "Banco do Brasil", level: "Classic"),
            BinInfo(bin: "500000", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "India", countryCode: "IN", bank: "State Bank of India", level: "Gold"),
            BinInfo(bin: "600000", brand: "Visa", scheme: "Visa", type: "Debit", country: "China", countryCode: "CN", bank: "Industrial and Commercial Bank", level: "Classic"),
            
            // High-risk countries (for testing)
            BinInfo(bin: "700000", brand: "Visa", scheme: "Visa", type: "Debit", country: "Russia", countryCode: "RU", bank: "Sberbank", level: "Classic"),
            BinInfo(bin: "800000", brand: "Mastercard", scheme: "Mastercard", type: "Credit", country: "Iran", countryCode: "IR", bank: "Bank Melli", level: "Gold"),
        ]
        
        for binInfo in sampleBins {
            binData[binInfo.bin] = binInfo
        }
        
        logger.info("Created \(sampleBins.count) sample BIN records")
    }
    
    private func loadFromFreeAPI() async {
        // Load additional BIN data from free APIs
        let commonBins = ["411111", "424242", "555555", "400000", "510510", "378282", "601111"]
        
        for bin in commonBins {
            if binData[bin] == nil {
                await fetchBinFromAPI(bin)
            }
        }
    }
    
    private func fetchBinFromAPI(_ bin: String) async {
        for endpoint in freeAPIEndpoints {
            do {
                let url = URL(string: "\(endpoint)\(bin)")!
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10.0
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let binInfo = try JSONDecoder().decode(BinlistResponse.self, from: data)
                    
                    let info = BinInfo(
                        bin: bin,
                        brand: binInfo.brand ?? "Unknown",
                        scheme: binInfo.scheme ?? "Unknown",
                        type: binInfo.type ?? "Unknown",
                        country: binInfo.country?.name ?? "Unknown",
                        countryCode: binInfo.country?.alpha2 ?? "XX",
                        bank: binInfo.bank?.name ?? "Unknown Bank",
                        level: binInfo.type?.contains("Credit") == true ? "Premium" : "Standard"
                    )
                    
                    binData[bin] = info
                    logger.info("Fetched BIN \(bin) from API: \(info.bank)")
                    break // Success, no need to try other endpoints
                }
            } catch {
                logger.warning("Failed to fetch BIN \(bin) from \(endpoint): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func lookupBin(_ bin: String) -> BinInfo? {
        let cleanBin = String(bin.prefix(6))
        return binData[cleanBin]
    }
    
    func addBin(_ binInfo: BinInfo) {
        binData[binInfo.bin] = binInfo
        binCount = binData.count
    }
    
    func getAllBins() -> [BinInfo] {
        return Array(binData.values).sorted { $0.bin < $1.bin }
    }
    
    func searchBins(query: String) -> [BinInfo] {
        let lowerQuery = query.lowercased()
        return binData.values.filter { binInfo in
            binInfo.bin.contains(lowerQuery) ||
            binInfo.bank.lowercased().contains(lowerQuery) ||
            binInfo.country.lowercased().contains(lowerQuery) ||
            binInfo.brand.lowercased().contains(lowerQuery)
        }.sorted { $0.bin < $1.bin }
    }
    
    // MARK: - Risk Assessment
    
    func isHighRiskCountry(_ countryCode: String) -> Bool {
        let highRiskCountries = ["RU", "CN", "IR", "KP", "SY", "AF", "LR", "LY", "SO", "SD"]
        return highRiskCountries.contains(countryCode)
    }
    
    func isHighRiskBank(_ bank: String) -> Bool {
        let highRiskBanks = ["Offshore Bank", "Crypto Exchange", "High Risk Institution"]
        return highRiskBanks.contains(bank)
    }
}

// MARK: - API Response Models (using existing ones from RealBinLookupService)

