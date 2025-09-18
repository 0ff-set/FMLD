//
//  OllamaService.swift
//  FMLD Panel
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation

/// Local LLM service using Ollama
class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    @Published var isAvailable = false
    @Published var modelLoaded = false
    
    private let logger = Logger.shared
    private let baseURL = AIConfiguration.ollamaBaseURL
    private let model = AIConfiguration.ollamaModel
    
    private init() {
        checkOllamaAvailability()
    }
    
    // MARK: - Availability Check
    
    private func checkOllamaAvailability() {
        Task {
            let available = await pingOllama()
            await MainActor.run {
                self.isAvailable = available
                if available {
                    self.logger.info("Ollama service is available")
                    Task {
                        await self.checkModelLoaded()
                    }
                } else {
                    self.logger.warning("Ollama service is not available")
                }
            }
        }
    }
    
    private func pingOllama() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            logger.error("Ollama ping failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func checkModelLoaded() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            
            await MainActor.run {
                self.modelLoaded = response.models.contains { $0.name.contains(self.model) }
                if self.modelLoaded {
                    self.logger.info("Model \(self.model) is loaded")
                } else {
                    self.logger.warning("Model \(self.model) is not loaded")
                }
            }
        } catch {
            logger.error("Failed to check model: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Text Generation
    
    func generateText(prompt: String, maxTokens: Int = 500) async -> String? {
        guard isAvailable else {
            logger.warning("Ollama not available for text generation")
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/api/generate") else { return nil }
        
        do {
            let requestBody = OllamaGenerateRequest(
                model: model,
                prompt: prompt,
                stream: false,
                options: OllamaOptions(num_predict: maxTokens, temperature: AIConfiguration.ollamaTemperature)
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30.0
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
            
            return response.response
        } catch {
            logger.error("Ollama text generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Transaction Analysis
    
    func analyzeTransaction(_ transaction: Transaction) async -> String? {
        let prompt = createTransactionAnalysisPrompt(transaction)
        return await generateText(prompt: prompt)
    }
    
    private func createTransactionAnalysisPrompt(_ transaction: Transaction) -> String {
        return """
        Analyze this financial transaction for fraud risk:
        
        Amount: $\(transaction.amount)
        Currency: \(transaction.currency)
        Country: \(transaction.country)
        City: \(transaction.city)
        Card BIN: \(transaction.bin)
        Time: \(transaction.timestamp)
        
        Please provide a brief risk assessment focusing on:
        1. Geographic risk factors
        2. Amount-based concerns
        3. Timing patterns
        4. Overall risk level (Low/Medium/High)
        
        Keep response under 200 words.
        """
    }
    
    // MARK: - Model Management
    
    func pullModel() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/pull") else { return false }
        
        do {
            let requestBody = OllamaPullRequest(name: model)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 300.0 // 5 minutes for model download
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            
            if success {
                await checkModelLoaded()
            }
            
            return success
        } catch {
            logger.error("Failed to pull model: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Ollama API Models

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable {
    let name: String
    let size: Int
    let modified_at: String
}

struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Codable {
    let num_predict: Int
    let temperature: Double
}

struct OllamaGenerateResponse: Codable {
    let response: String
    let done: Bool
}

struct OllamaPullRequest: Codable {
    let name: String
}

