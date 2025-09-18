//
//  AdminView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var rulesEngine: RulesEngine
    @EnvironmentObject private var riskScorer: RiskScorer
    @EnvironmentObject private var encryptedDB: EncryptedDatabaseManager
    @StateObject private var binService = MockBinDatabaseService.shared
    @State private var selectedTab = 0
    @State private var showingAddRule = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Administration")
                .font(.largeTitle)
                .fontWeight(.bold)
                
                Spacer()
                
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.bordered)
            }
                .padding()
            
            // Tab Picker
            Picker("Admin Section", selection: $selectedTab) {
                Text("Rules").tag(0)
                Text("BIN Database").tag(1)
                Text("System").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Content
            TabView(selection: $selectedTab) {
                RulesManagementView()
                    .tag(0)
                
                BINDatabaseManagementView()
                    .tag(1)
                
                SystemManagementView()
                    .tag(2)
            }
            .tabViewStyle(DefaultTabViewStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct RulesManagementView: View {
    @EnvironmentObject private var rulesEngine: RulesEngine
    @State private var showingAddRule = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Fraud Detection Rules")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add Rule") {
                    showingAddRule = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            List {
                ForEach(rulesEngine.rules) { rule in
                    RuleRowView(rule: rule)
                }
            }
            .listStyle(PlainListStyle())
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleView()
        }
    }
}

struct RuleRowView: View {
    let rule: Rule
    
    var body: some View {
            HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(rule.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Category: \(rule.category.rawValue)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Action: \(rule.action.rawValue)")
                        .font(.caption)
                        .foregroundColor(actionColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(actionColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack {
                Toggle("Enabled", isOn: .constant(rule.isActive))
                    .toggleStyle(SwitchToggleStyle())
                
                Button("Delete") {
                    // Delete rule logic
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var actionColor: Color {
        switch rule.action {
        case .block: return .red
        case .review: return .orange
        case .approve: return .green
        case .flag: return .yellow
        case .log: return .blue
        }
    }
}

struct BINDatabaseManagementView: View {
    @StateObject private var binService = MockBinDatabaseService.shared
    @State private var searchText = ""
    @State private var showingAddBIN = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("BIN Database Management")
                .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add BIN") {
                    showingAddBIN = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search BINs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            List {
                ForEach(filteredBINs, id: \.bin) { binInfo in
                    BINRowView(binInfo: binInfo)
                }
            }
            .listStyle(PlainListStyle())
        }
        .sheet(isPresented: $showingAddBIN) {
            AddBINView()
        }
    }
    
    private var filteredBINs: [BinInfo] {
        let bins = Array(binService.binData.values)
        if searchText.isEmpty {
            return bins
        } else {
            return bins.filter { $0.bin.contains(searchText) || $0.bank.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct BINRowView: View {
    let binInfo: BinInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(binInfo.bin)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(binInfo.bank)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(binInfo.brand)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(binInfo.country)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(binInfo.type)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(binInfo.level)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SystemManagementView: View {
    @EnvironmentObject private var encryptedDB: EncryptedDatabaseManager
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Management")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                // Database Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(encryptedDB.isUnlocked ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(encryptedDB.isUnlocked ? "Unlocked" : "Locked")
                            .font(.subheadline)
                    }
                    
                    Text(encryptedDB.isEncrypted ? "Database is encrypted" : "Database is not encrypted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button("Export Data") {
                            showingExportDialog = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Import Data") {
                            showingImportDialog = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Cache") {
                            clearCache()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: "bin_database_cache")
        UserDefaults.standard.removeObject(forKey: "geocoding_cache")
        UserDefaults.standard.removeObject(forKey: "aml_blacklist_cache")
    }
}

struct AddRuleView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var rulesEngine: RulesEngine
    @State private var ruleName = ""
    @State private var ruleDescription = ""
    @State private var condition = RuleCondition(field: "amount", operator: .greaterThan, value: "1000", dataType: .number)
    @State private var selectedAction: RuleAction = .flag
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Information") {
                    TextField("Rule Name", text: $ruleName)
                    TextField("Description", text: $ruleDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Condition") {
                    TextField("Field", text: Binding(
                        get: { condition.field },
                        set: { condition = RuleCondition(field: $0, operator: condition.operator, value: condition.value, dataType: condition.dataType) }
                    ))
                    
                    Picker("Operator", selection: Binding(
                        get: { condition.operator },
                        set: { condition = RuleCondition(field: condition.field, operator: $0, value: condition.value, dataType: condition.dataType) }
                    )) {
                        ForEach(RuleOperator.allCases, id: \.self) { op in
                            Text(op.rawValue).tag(op)
                        }
                    }
                    
                    TextField("Value", text: Binding(
                        get: { condition.value },
                        set: { condition = RuleCondition(field: condition.field, operator: condition.operator, value: $0, dataType: condition.dataType) }
                    ))
                    
                    Picker("Data Type", selection: Binding(
                        get: { condition.dataType },
                        set: { condition = RuleCondition(field: condition.field, operator: condition.operator, value: condition.value, dataType: $0) }
                    )) {
                        ForEach(RuleDataType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Action") {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(RuleAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(ruleName.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveRule() {
        let newRule = Rule(
            name: ruleName,
            description: ruleDescription,
            category: .custom,
            conditions: [condition],
            action: selectedAction
        )
        rulesEngine.addRule(newRule)
        dismiss()
    }
}

struct AddBINView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var binService = MockBinDatabaseService.shared
    @State private var bin = ""
    @State private var bank = ""
    @State private var brand = ""
    @State private var country = ""
    @State private var countryCode = ""
    @State private var type = ""
    @State private var level = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("BIN Information") {
                    TextField("BIN (6 digits)", text: $bin)
                    TextField("Bank Name", text: $bank)
                    TextField("Brand", text: $brand)
                }
                
                Section("Location") {
                    TextField("Country", text: $country)
                    TextField("Country Code", text: $countryCode)
                }
                
                Section("Card Details") {
                    TextField("Type", text: $type)
                    TextField("Level", text: $level)
                }
            }
            .navigationTitle("Add BIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBIN()
                    }
                    .disabled(bin.isEmpty || bank.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveBIN() {
        let binInfo = BinInfo(
            bin: bin,
            brand: brand,
            scheme: brand,
            type: type,
            country: country,
            countryCode: countryCode,
            bank: bank,
            level: level
        )
        binService.addBin(binInfo)
        dismiss()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("refreshInterval") private var refreshInterval = 30.0
    @AppStorage("riskThreshold") private var riskThreshold = 0.7
    
    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    Toggle("Auto Refresh", isOn: $autoRefresh)
                    
                    if autoRefresh {
                        VStack(alignment: .leading) {
                            Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                            Slider(value: $refreshInterval, in: 10...300, step: 10)
                        }
                    }
                }
                
                Section("Risk Management") {
                    VStack(alignment: .leading) {
                        Text("Risk Threshold: \(String(format: "%.1f", riskThreshold))")
                        Slider(value: $riskThreshold, in: 0.1...1.0, step: 0.1)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    AdminView()
        .environmentObject(RulesEngine.shared)
        .environmentObject(RiskScorer.shared)
        .environmentObject(EncryptedDatabaseManager.shared)
}