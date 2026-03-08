l
# FMLD Panel

**FMLD Panel** is a macOS SwiftUI demo application that illustrates the structure of a local fraud‑monitoring dashboard. It combines rule‑based transaction evaluation, local data storage, and optional AI analysis through Ollama to demonstrate how a fraud detection interface could be built.

This project is intended primarily as a **developer template and learning reference**, not a complete production fraud‑detection system.

---

# Overview

FMLD Panel demonstrates how to build a fraud‑analysis interface using a modular Swift architecture. It focuses on:

- transaction monitoring UI
- rule‑based risk evaluation
- configurable detection logic
- local data processing
- optional LLM‑assisted analysis

The project is designed to be easy to explore and extend.

---

# Features

## Core Functionality

- **Transaction Dashboard**  
  View and manage transactions inside a SwiftUI monitoring panel.

- **Rule-Based Risk Engine**  
  Transactions are evaluated using configurable rules defined in JSON.

- **Risk Scoring System**  
  Basic scoring logic categorizes transactions into low, medium, and high risk.

- **Local Data Storage**  
  Transaction data is stored locally using SQLite.

- **BIN Lookup (Basic)**  
  Simple card issuer lookup functionality.

---

## Optional AI Analysis

The project includes optional integration with **Ollama** for local LLM analysis.

If enabled, the model can provide additional insights about flagged transactions.

Supported models include:

- llama3
- mistral
- any Ollama-compatible local model

AI analysis is optional and not required for running the project.

---

# Architecture

The project is structured into modular components.

### UI Layer
SwiftUI interface for transaction monitoring and risk visualization.

### Data Layer
Local storage and transaction persistence.

### Rule Engine
Evaluates transactions against configurable detection rules.

### AI Layer (Optional)
Provides LLM-based analysis through Ollama.

---

# Project Structure

```
FMLD Panel
│
├── UI
│   └── SwiftUI monitoring dashboard
│
├── Services
│   ├── RulesEngine
│   ├── LocalMLService
│   ├── OllamaService
│   └── FreeBinDatabase
│
├── Database
│   └── SQLite storage
│
└── Rules
    └── rules_config.json
```

---

# Installation

## Requirements

- macOS 14+
- Xcode 15+

## Setup

Clone the repository:

```
git clone https://github.com/0ff-set/FMLD
```

Open the project in Xcode:

```
FMLD Panel.xcodeproj
```

Build and run.

---

# Optional: Ollama Setup

Install Ollama:

```
curl -fsSL https://ollama.ai/install.sh | sh
```

Download a model:

```
ollama pull llama3
```

The application will automatically detect the local Ollama instance.

---

# Rule Configuration

Fraud detection rules are stored in:

```
Rules/rules_config.json
```

Example rule:

```json
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
```

Rules can be modified or extended without changing application code.

---

# Risk Levels

Transactions are categorized using a simple scoring system:

| Score | Risk Level | Action |
|------|-------------|--------|
| 0–30 | Low | Approve |
| 31–70 | Medium | Manual review |
| 71–100 | High | Block |

---

# Intended Use

FMLD Panel is useful for:

- learning SwiftUI architecture
- experimenting with rule engines
- prototyping fraud dashboards
- testing local LLM integrations
- building internal monitoring tools

---

# License

Proprietary.

If you reuse parts of this project, attribution is appreciated.
"""

output_file = "/mnt/data/README.md"
pypandoc.convert_text(md_text, "md", format="md", outputfile=output_file, extra_args=['--standalone'])

output_file
