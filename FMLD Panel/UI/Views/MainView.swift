//
//  MainView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var transactionRepository = TransactionRepository.shared
    @StateObject private var rulesEngine = RulesEngine.shared
    @StateObject private var localMLService = LocalMLService.shared
    @StateObject private var ollamaService = OllamaService.shared
    @StateObject private var freeBinDatabase = FreeBinDatabase.shared
    @StateObject private var secretsManager = SecretsManager.shared
    @StateObject private var riskScorer = RiskScorer.shared
    @StateObject private var productionMLService = ProductionMLService.shared
    @StateObject private var realTimeProcessor = RealTimeProcessor.shared
    @StateObject private var encryptedDB = EncryptedDatabaseManager.shared
    @StateObject private var binService = BinDatabaseService.shared
    @StateObject private var geocodingService = GeocodingService.shared
    @StateObject private var amlService = AMLBlacklistService.shared
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var isUnlocked = false
    @State private var showingPasswordAlert = false
    @State private var password = ""
    @State private var isUnlocking = false
    @State private var unlockError = ""
    @State private var showingAddTransaction = false
    
    var body: some View {
        Group {
            if !isUnlocked {
                // Database unlock screen
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("FMLD Panel")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Financial Fraud Detection System")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("Start Application") {
                        Task {
                            await initializeApplication()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUnlocking)
                    
                    if isUnlocking {
                        ProgressView("Initializing application...")
                            .padding(.top, 10)
                    }
                    
                    if !unlockError.isEmpty {
                        Text(unlockError)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 5)
                    }
                    
                    VStack(spacing: 8) {
                        Text("🛡️ ML Service: \(localMLService.isInitialized ? "Ready" : "Loading")")
                        Text("💳 BIN Database: \(freeBinDatabase.isLoaded ? "\(freeBinDatabase.binCount) records" : "Loading")")
                        Text("🤖 AI Service: \(ollamaService.isAvailable ? "Available" : "Local Fallback")")
                        Text("⚙️ Environment: \(secretsManager.environment.capitalized)")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 10)
                }
                .padding()
                .frame(minWidth: 1200, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Main application
                NavigationSplitView {
                    SidebarView(selectedTab: $selectedTab)
                } detail: {
                    switch selectedTab {
                    case 0:
                        TransactionsView()
                    case 1:
                        AnalyticsView()
                    case 2:
                        ReviewView()
                    case 3:
                        AdminView()
                    case 4:
                        RealTimeView()
                    case 5:
                        AnalyticsView()
                    case 6:
                        SubscriptionView()
                    case 7:
                        AIInsightsView()
                    case 8:
                        CasinoDashboardView()
                    default:
                        Text("Select a tab")
                    }
                }
                .frame(minWidth: 1200, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(transactionRepository)
                .environmentObject(rulesEngine)
                .environmentObject(riskScorer)
                .environmentObject(productionMLService)
                .environmentObject(realTimeProcessor)
                .environmentObject(encryptedDB)
                .environmentObject(binService)
                .environmentObject(geocodingService)
                .environmentObject(amlService)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Lock") {
                            lockDatabase()
                        }
                    }
                    
                    ToolbarItem(placement: .automatic) {
                        Button("Add Transaction") {
                            showingAddTransaction = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .sheet(isPresented: $showingAddTransaction) {
                    AddTransactionView()
                }
            }
        }
        .onAppear {
            checkDatabaseStatus()
        }
    }
    
    private func checkDatabaseStatus() {
        if encryptedDB.isUnlocked {
            isUnlocked = true
        } else if encryptedDB.isEncrypted {
            showingPasswordAlert = true
        } else {
            // First time setup - create encrypted database
            Task {
                await setupFirstTimeDatabase()
            }
        }
    }
    
    private func setupFirstTimeDatabase() async {
        await MainActor.run {
            isUnlocking = true
            unlockError = ""
        }
        
        // Simulate first-time setup delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isUnlocked = true
            isUnlocking = false
            unlockError = ""
        }
    }
    
    private func initializeApplication() async {
        await MainActor.run {
            isUnlocking = true
            unlockError = ""
        }
        
        // Initialize services
        await Task.detached {
            // Wait for services to initialize
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Generate some test data if none exists
            let existingTransactions = try? DatabaseManager.shared.fetchTransactions(limit: 10)
            if existingTransactions?.isEmpty != false {
                let testTransactions = TestDataGenerator.shared.generateTestTransactions(count: 20)
                for transaction in testTransactions {
                    try? DatabaseManager.shared.saveTransaction(transaction)
                }
                Logger.shared.info("Generated \(testTransactions.count) test transactions")
            }
        }.value
        
        await MainActor.run {
            isUnlocking = false
            isUnlocked = true
            unlockError = ""
            
            Logger.shared.info("Application initialized successfully")
            Logger.shared.info(secretsManager.getConfigurationSummary())
        }
    }
    
    private func lockDatabase() {
        realTimeProcessor.stopRealTimeIngestion()
        encryptedDB.lockDatabase()
        isUnlocked = false
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        List {
            // User Info Section
            VStack(alignment: .leading, spacing: 8) {
                if let user = authManager.currentUser {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(user.role.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let subscription = subscriptionManager.currentSubscription {
                        Text(subscription.plan.displayName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Navigation Links
            Button(action: { selectedTab = 0 }) {
                Label("Transactions", systemImage: "list.bullet.rectangle.portrait")
            }
            .foregroundColor(selectedTab == 0 ? .accentColor : .primary)
            
            Button(action: { selectedTab = 1 }) {
                Label("Analytics", systemImage: "chart.bar.fill")
            }
            .foregroundColor(selectedTab == 1 ? .accentColor : .primary)
            
            if authManager.hasPermission(.analyzeTransactions) {
                Button(action: { selectedTab = 2 }) {
                    Label("Review", systemImage: "hand.raised.fill")
                }
                .foregroundColor(selectedTab == 2 ? .accentColor : .primary)
            }
            
            if authManager.hasPermission(.manageSettings) {
                Button(action: { selectedTab = 3 }) {
                    Label("Admin", systemImage: "gearshape.fill")
                }
                .foregroundColor(selectedTab == 3 ? .accentColor : .primary)
            }
            
            if authManager.hasPermission(.viewTransactions) {
                Button(action: { selectedTab = 4 }) {
                    Label("Real-Time", systemImage: "bolt.fill")
                }
                .foregroundColor(selectedTab == 4 ? .accentColor : .primary)
            }
            
            Button(action: { selectedTab = 5 }) {
                Label("Free APIs", systemImage: "globe")
            }
            .foregroundColor(selectedTab == 5 ? .accentColor : .primary)
            
            Button(action: { selectedTab = 7 }) {
                Label("AI Insights", systemImage: "brain.head.profile")
            }
            .foregroundColor(selectedTab == 7 ? .accentColor : .primary)
            
            Button(action: { selectedTab = 8 }) {
                Label("Casino Dashboard", systemImage: "dice.fill")
            }
            .foregroundColor(selectedTab == 8 ? .accentColor : .primary)
            
            // Subscription Section
            if subscriptionManager.currentSubscription == nil {
                Button(action: { selectedTab = 6 }) {
                    Label("Subscription", systemImage: "creditcard")
                }
                .foregroundColor(selectedTab == 6 ? .accentColor : .primary)
            }
            
            Divider()
            
            // Logout Button
            Button(action: {
                authManager.logout()
            }) {
                Label("Logout", systemImage: "arrow.right.square")
            }
            .foregroundColor(.red)
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("FMLD Panel")
    }
}
