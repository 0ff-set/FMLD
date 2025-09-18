# FMLD Panel - Financial Fraud Detection System

A professional-grade fraud detection system built with SwiftUI for macOS, featuring local ML inference, real-time transaction monitoring, and comprehensive risk assessment.

## 🚀 Features

### Core Functionality
- **Real-time Transaction Monitoring** - Live fraud detection as transactions occur
- **Local ML Inference** - Privacy-focused machine learning without cloud dependencies
- **BIN Database Integration** - Comprehensive card issuer verification
- **Rule-based Engine** - Configurable fraud detection rules
- **Risk Scoring** - Multi-factor risk assessment algorithms
- **Transaction Analytics** - Detailed reporting and insights

### Technical Highlights
- **Local AI Processing** - Ollama integration for LLM-powered analysis
- **Encrypted Database** - Secure transaction storage
- **External Configuration** - JSON-based rule management
- **Environment Variables** - Secure API key management
- **Free API Alternatives** - No paid service dependencies

## 🛠️ Installation

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Ollama (optional, for AI analysis)

### Setup
1. Clone the repository
2. Open `FMLD Panel.xcodeproj` in Xcode
3. Build and run the project

### Ollama Setup (Optional)
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model (recommended: llama3.1 or mistral)
ollama pull llama3.1:8b
```

## ⚙️ Configuration

### Environment Variables
Create a `.env` file or set environment variables:
```bash
export APP_ENV=production
export OPENAI_API_KEY=your_key_here  # Optional
export STRIPE_PUBLISHABLE_KEY=your_key_here
export STRIPE_SECRET_KEY=your_key_here
```

### Rule Configuration
Edit `FMLD Panel/Rules/rules_config.json` to customize fraud detection rules:
```json
{
  "rules": [
    {
      "id": "001",
      "name": "High Amount Detection",
      "category": "amount",
      "priority": 90,
      "isActive": true,
      "conditions": [
        {
          "field": "amount",
          "operator": "greaterThan",
          "value": "10000",
          "dataType": "number"
        }
      ],
      "action": "review"
    }
  ]
}
```

## 📊 Usage

### Transaction Analysis
1. Launch the application
2. Click "Start Application" to initialize services
3. Navigate to "Transactions" tab
4. Add new transactions or import data
5. Review risk scores and AI insights

### Risk Assessment
- **Green (0-30%)**: Low risk - Auto approve
- **Yellow (31-70%)**: Medium risk - Manual review
- **Red (71-100%)**: High risk - Block transaction

### Real-time Monitoring
- Enable real-time processing in "Real-time" tab
- Monitor live transaction feeds
- Review flagged transactions immediately

## 🔧 Architecture

### Core Components
- **ML Layer**: Local CoreML models + Ollama LLM
- **Data Layer**: SQLite with encryption
- **API Layer**: Free alternatives (no paid services)
- **UI Layer**: SwiftUI with professional design

### Services
- `LocalMLService` - Core ML inference
- `OllamaService` - LLM-powered analysis
- `FreeBinDatabase` - BIN lookup service
- `RulesEngine` - Configurable rule processing
- `RealTimeProcessor` - Live transaction monitoring

## 🔒 Security

- **Local Processing** - No data leaves your machine
- **Encrypted Storage** - Database encryption at rest
- **Secure Configuration** - Environment variable management
- **No Hardcoded Keys** - All secrets externalized

## 📈 Performance

- **Real-time Processing** - Sub-second transaction analysis
- **Local Inference** - No network latency
- **Optimized Database** - Fast query performance
- **Memory Efficient** - Minimal resource usage

## 🛡️ Production Ready

This system is designed for production use with:
- Professional UI/UX
- Comprehensive error handling
- Logging and monitoring
- Scalable architecture
- Security best practices

## 📝 License

Proprietary - All rights reserved

## 🤝 Support

For technical support or feature requests, contact the development team.

---

**FMLD Panel** - Professional Fraud Detection Made Simple