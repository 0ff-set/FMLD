//
//  AIInsightsView.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import SwiftUI

struct AIInsightsView: View {
    @StateObject private var aiService = RealAIService.shared
    @StateObject private var transactionRepository = TransactionRepository.shared
    @State private var insights: [AIInsight] = []
    @State private var isLoading = false
    @State private var selectedInsight: AIInsight?
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            // AI Status
            aiStatusSection
            
            // Insights Grid
            if isLoading {
                loadingSection
            } else if insights.isEmpty {
                emptyStateSection
            } else {
                insightsGrid
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadInsights()
        }
        .refreshable {
            await refreshInsights()
        }
        .sheet(isPresented: $showingDetail) {
            if let insight = selectedInsight {
                AIInsightDetailView(insight: insight)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🤖 AI Insights")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await refreshInsights()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Real-time AI analysis of transaction patterns and fraud detection")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - AI Status Section
    private var aiStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI System Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                AIStatusCard(
                    title: "AI Service",
                    status: aiService.isInitialized ? "Active" : "Initializing",
                    color: aiService.isInitialized ? .green : .orange
                )
                
                AIStatusCard(
                    title: "Model Accuracy",
                    value: String(format: "%.1f%%", aiService.modelAccuracy * 100),
                    color: aiService.modelAccuracy > 0.8 ? .green : aiService.modelAccuracy > 0.6 ? .orange : .red
                )
                
                AIStatusCard(
                    title: "Last Training",
                    value: aiService.lastTrainingDate?.timeAgoDisplay() ?? "Never",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing transactions with AI...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This may take a few moments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State Section
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No AI Insights Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("AI analysis will appear here once transactions are processed")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Analyze Transactions") {
                Task {
                    await refreshInsights()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Insights Grid
    private var insightsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(insights, id: \.type) { insight in
                AIInsightCard(insight: insight)
                    .onTapGesture {
                        selectedInsight = insight
                        showingDetail = true
                    }
            }
        }
    }
    
    // MARK: - Methods
    private func loadInsights() {
        Task {
            await refreshInsights()
        }
    }
    
    private func refreshInsights() async {
        isLoading = true
        
        let transactions = transactionRepository.transactions
        let newInsights = await aiService.getRealTimeInsights(for: transactions)
        
        await MainActor.run {
            self.insights = newInsights
            self.isLoading = false
        }
    }
}

// MARK: - AI Status Card
struct AIStatusCard: View {
    let title: String
    let status: String?
    let value: String?
    let color: Color
    
    init(title: String, status: String, color: Color) {
        self.title = title
        self.status = status
        self.value = nil
        self.color = color
    }
    
    init(title: String, value: String, color: Color) {
        self.title = title
        self.status = nil
        self.value = value
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(status ?? value ?? "")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - AI Insight Card
struct AIInsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                insightIcon
                
                Spacer()
                
                severityBadge
            }
            
            Text(insight.type.capitalized)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(insight.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("Confidence: \(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tap for details")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var insightIcon: some View {
        Image(systemName: iconForType(insight.type))
            .font(.title2)
            .foregroundColor(colorForSeverity(insight.severity))
    }
    
    private var severityBadge: some View {
        Text(insight.severity.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForSeverity(insight.severity).opacity(0.2))
            .foregroundColor(colorForSeverity(insight.severity))
            .cornerRadius(6)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "velocity": return "speedometer"
        case "geographic": return "globe"
        case "llm": return "brain.head.profile"
        case "statistical": return "chart.bar"
        case "anomaly": return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .blue
        }
    }
}

// MARK: - AI Insight Detail View
struct AIInsightDetailView: View {
    let insight: AIInsight
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Description
                    descriptionSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    // Technical Details
                    technicalDetailsSection
                }
                .padding()
            }
            .navigationTitle("AI Insight Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconForType(insight.type))
                    .font(.largeTitle)
                    .foregroundColor(colorForSeverity(insight.severity))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.type.capitalized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Severity: \(insight.severity.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(colorForSeverity(insight.severity))
                }
                
                Spacer()
            }
            
            Text(insight.description)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(insight.recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(recommendation)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Type", value: insight.type)
                DetailRow(label: "Severity", value: insight.severity)
                DetailRow(label: "Confidence", value: "\(Int(insight.confidence * 100))%")
                DetailRow(label: "Generated", value: Date().formatted())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "velocity": return "speedometer"
        case "geographic": return "globe"
        case "llm": return "brain.head.profile"
        case "statistical": return "chart.bar"
        case "anomaly": return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .blue
        }
    }
}


// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    AIInsightsView()
}
