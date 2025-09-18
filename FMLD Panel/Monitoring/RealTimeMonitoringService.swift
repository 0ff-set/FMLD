//
//  RealTimeMonitoringService.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import Foundation
import Network
import Combine

// MARK: - Real-Time Monitoring Service
class RealTimeMonitoringService: ObservableObject {
    static let shared = RealTimeMonitoringService()
    
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    // Monitoring state
    @Published var isConnected = false
    @Published var systemHealth = SystemHealth.good
    @Published var activeAlerts: [Alert] = []
    @Published var performanceMetrics = PerformanceMetrics()
    
    // Real-time data
    @Published var transactionCount = 0
    @Published var fraudDetectedCount = 0
    @Published var averageProcessingTime: Double = 0.0
    @Published var errorRate: Double = 0.0
    
    // WebSocket connection for real-time updates
    private var webSocketTask: URLSessionWebSocketTask?
    private let webSocketURL = URL(string: "wss://api.fmld-panel.com/ws")!
    
    private init() {
        startNetworkMonitoring()
        startPerformanceMonitoring()
        connectWebSocket()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        logger.info("Starting real-time monitoring")
        
        // Start system health monitoring
        startSystemHealthMonitoring()
        
        // Start transaction monitoring
        startTransactionMonitoring()
        
        // Start fraud detection monitoring
        startFraudDetectionMonitoring()
        
        // Start performance monitoring
        startPerformanceMonitoring()
    }
    
    func stopMonitoring() {
        logger.info("Stopping real-time monitoring")
        
        webSocketTask?.cancel()
        webSocketTask = nil
        
        cancellables.removeAll()
    }
    
    func createAlert(_ alert: Alert) {
        DispatchQueue.main.async {
            self.activeAlerts.append(alert)
            self.logger.warning("Alert created: \(alert.title)")
        }
    }
    
    func dismissAlert(_ alertId: UUID) {
        DispatchQueue.main.async {
            self.activeAlerts.removeAll { $0.id == alertId }
        }
    }
    
    // MARK: - Private Methods
    
    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    self?.logger.info("Network connection restored")
                } else {
                    self?.logger.warning("Network connection lost")
                    self?.createAlert(Alert(
                        title: "Network Disconnected",
                        message: "Lost connection to monitoring services",
                        severity: .warning,
                        timestamp: Date()
                    ))
                }
            }
        }
    }
    
    private func startSystemHealthMonitoring() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkSystemHealth()
            }
            .store(in: &cancellables)
    }
    
    private func startTransactionMonitoring() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTransactionMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func startFraudDetectionMonitoring() {
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateFraudDetectionMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func startPerformanceMonitoring() {
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePerformanceMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func checkSystemHealth() {
        // Check CPU usage
        let cpuUsage = getCPUUsage()
        
        // Check memory usage
        let memoryUsage = getMemoryUsage()
        
        // Check disk usage
        let diskUsage = getDiskUsage()
        
        // Determine overall health
        let health: SystemHealth
        if cpuUsage > 90 || memoryUsage > 90 || diskUsage > 90 {
            health = .critical
            createAlert(Alert(
                title: "System Health Critical",
                message: "High resource usage detected",
                severity: .critical,
                timestamp: Date()
            ))
        } else if cpuUsage > 80 || memoryUsage > 80 || diskUsage > 80 {
            health = .warning
            createAlert(Alert(
                title: "System Health Warning",
                message: "Elevated resource usage detected",
                severity: .warning,
                timestamp: Date()
            ))
        } else {
            health = .good
        }
        
        DispatchQueue.main.async {
            self.systemHealth = health
        }
    }
    
    private func updateTransactionMetrics() {
        // In a real implementation, this would query the database
        // For now, we'll simulate some data
        let newTransactions = Int.random(in: 0...5)
        let newFraudDetected = Int.random(in: 0...1)
        
        DispatchQueue.main.async {
            self.transactionCount += newTransactions
            self.fraudDetectedCount += newFraudDetected
            
            if newFraudDetected > 0 {
                self.createAlert(Alert(
                    title: "Fraud Detected",
                    message: "\(newFraudDetected) fraudulent transaction(s) detected",
                    severity: .critical,
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func updateFraudDetectionMetrics() {
        // Update fraud detection statistics
        // In a real implementation, this would query the ML models
    }
    
    private func updatePerformanceMetrics() {
        // Update performance metrics
        let newProcessingTime = Double.random(in: 0.1...2.0)
        let newErrorRate = Double.random(in: 0.0...0.05)
        
        DispatchQueue.main.async {
            self.averageProcessingTime = (self.averageProcessingTime + newProcessingTime) / 2
            self.errorRate = (self.errorRate + newErrorRate) / 2
            
            if newErrorRate > 0.1 {
                self.createAlert(Alert(
                    title: "High Error Rate",
                    message: "Error rate is above acceptable threshold",
                    severity: .warning,
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func connectWebSocket() {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: webSocketURL)
        webSocketTask?.resume()
        
        receiveWebSocketMessage()
    }
    
    private func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveWebSocketMessage()
            case .failure(let error):
                self?.logger.error("WebSocket error: \(error.localizedDescription)")
                // Attempt to reconnect after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectWebSocket()
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: String) {
        // Parse WebSocket message and update monitoring data
        // In a real implementation, this would parse JSON and update the appropriate metrics
        logger.info("Received WebSocket message: \(message)")
    }
    
    // MARK: - System Metrics
    
    private func getCPUUsage() -> Double {
        // In a real implementation, this would get actual CPU usage
        return Double.random(in: 0...100)
    }
    
    private func getMemoryUsage() -> Double {
        // In a real implementation, this would get actual memory usage
        return Double.random(in: 0...100)
    }
    
    private func getDiskUsage() -> Double {
        // In a real implementation, this would get actual disk usage
        return Double.random(in: 0...100)
    }
}

// MARK: - Data Models

enum SystemHealth: String, CaseIterable {
    case good = "Good"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .good:
            return "green"
        case .warning:
            return "yellow"
        case .critical:
            return "red"
        }
    }
}

struct Alert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
}

enum AlertSeverity: String, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "yellow"
        case .critical:
            return "red"
        }
    }
}

struct PerformanceMetrics {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var diskUsage: Double = 0.0
    var networkLatency: Double = 0.0
    var responseTime: Double = 0.0
    var throughput: Double = 0.0
    var errorRate: Double = 0.0
    var availability: Double = 100.0
}
