# FMLD Panel - Архитектурная диаграмма

## 🏗️ Общая архитектура

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                FMLD Panel                                      │
│                           Enterprise Anti-Fraud System                        │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   UI Layer      │    │   ML Layer      │    │  Rules Engine   │    │  Integration    │
│   (SwiftUI)     │    │   (CoreML)      │    │   (Fast Rules)  │    │   (External)    │
│                 │    │                 │    │                 │    │                 │
│ • Transactions  │    │ • Risk Scoring  │    │ • Velocity      │    │ • BIN Database  │
│ • Analytics     │    │ • Embeddings    │    │ • Geography     │    │ • Crypto Lists  │
│ • Review        │    │ • Vector Search │    │ • Amount        │    │ • AML Services  │
│ • Admin         │    │ • ML Models     │    │ • BIN Checks    │    │ • Geocoding     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         └───────────────────────┼───────────────────────┼───────────────────────┘
                                 │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Data Layer     │    │   Security      │    │   Logging       │    │   Monitoring    │
│  (GRDB+SQLite)  │    │  (Encryption)   │    │  (Structured)   │    │  (Performance)  │
│                 │    │                 │    │                 │    │                 │
│ • Transactions  │    │ • SQLCipher     │    │ • Transaction   │    │ • Metrics       │
│ • Cards         │    │ • PII Hashing   │    │ • Risk          │    │ • Alerts        │
│ • Addresses     │    │ • Key Management│    │ • Rules         │    │ • Health Checks │
│ • Embeddings    │    │ • Audit Trail   │    │ • System        │    │ • Dashboards    │
│ • Rules         │    │                 │    │ • Security      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 Поток обработки транзакции

```
┌─────────────────┐
│  New Transaction│
│     Input       │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data          │    │   Rules         │    │   ML            │
│  Normalization  │    │   Engine        │    │   Scoring       │
│                 │    │                 │    │                 │
│ • Address       │    │ • Velocity      │    │ • Embedding     │
│ • BIN Lookup    │    │ • Geography     │    │ • Risk Model    │
│ • Wallet Check  │    │ • Amount        │    │ • Vector Search │
│ • PII Hashing   │    │ • Blacklist     │    │ • Similarity    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Risk          │    │   Decision      │    │   Action        │
│  Calculation    │    │   Engine        │    │   Execution     │
│                 │    │                 │    │                 │
│ • Rule Score    │    │ • Approve       │    │ • Auto Approve  │
│ • ML Score      │    │ • Review        │    │ • Flag Review   │
│ • Final Score   │    │ • Block         │    │ • Block         │
│ • Confidence    │    │ • Thresholds    │    │ • Notifications │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Storage       │    │   Logging       │    │   Analytics     │
│   & Indexing    │    │   & Audit       │    │   & Reporting   │
│                 │    │                 │    │                 │
│ • Transaction   │    │ • Transaction   │    │ • Real-time     │
│ • Embedding     │    │ • Risk Score    │    │ • Historical    │
│ • Vector Index  │    │ • Rule Trigger  │    │ • Trends        │
│ • Metadata      │    │ • Decision      │    │ • Alerts        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🗄️ Схема базы данных

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                SQLite Database                                 │
│                              (SQLCipher Encrypted)                            │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  transactions   │    │     cards       │    │   addresses     │    │   embeddings    │
│                 │    │                 │    │                 │    │                 │
│ • id (PK)       │    │ • id (PK)       │    │ • id (PK)       │    │ • id (PK)       │
│ • timestamp     │    │ • bin (UNIQUE)  │    │ • normalized    │    │ • type          │
│ • amount        │    │ • scheme        │    │ • street        │    │ • vector        │
│ • currency      │    │ • issuer        │    │ • city          │    │ • reference_id  │
│ • card_bin (FK) │    │ • country       │    │ • state         │    │ • created_at    │
│ • wallet_addr   │    │ • type          │    │ • country       │    │ • updated_at    │
│ • address_id(FK)│    │ • is_prepaid    │    │ • postal_code   │    │                 │
│ • user_id       │    │ • is_commercial │    │ • latitude      │    │                 │
│ • metadata      │    │ • risk_level    │    │ • longitude     │    │                 │
│ • risk_score    │    │ • updated_at    │    │ • geohash       │    │                 │
│ • rule_score    │    │                 │    │ • hashed_pii    │    │                 │
│ • ml_score      │    │                 │    │ • risk_score    │    │                 │
│ • status        │    │                 │    │ • is_high_risk  │    │                 │
│ • decision      │    │                 │    │ • created_at    │    │                 │
│ • created_at    │    │                 │    │ • updated_at    │    │                 │
│ • updated_at    │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     rules       │    │   rule_logs     │    │ blacklist_entries│
│                 │    │                 │    │                 │
│ • id (PK)       │    │ • id (PK)       │    │ • id (PK)       │
│ • name          │    │ • transaction_id│    │ • address       │
│ • description   │    │ • rule_id       │    │ • is_blacklisted│
│ • category      │    │ • triggered     │    │ • reason        │
│ • condition     │    │ • weight        │    │ • confidence    │
│ • weight        │    │ • score         │    │ • last_checked  │
│ • is_active     │    │ • details       │    │                 │
│ • priority      │    │ • executed_at   │    │                 │
│ • created_at    │    │                 │    │                 │
│ • updated_at    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 Технологический стек

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                Technology Stack                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │   Database      │    │   ML/AI         │
│                 │    │                 │    │                 │    │                 │
│ • SwiftUI       │    │ • Swift         │    │ • SQLite        │    │ • CoreML        │
│ • Combine       │    │ • GRDB          │    │ • SQLCipher     │    │ • Vector Search │
│ • Charts        │    │ • URLSession    │    │ • Extensions    │    │ • Embeddings    │
│ • Navigation    │    │ • JSON          │    │ • Indexes       │    │ • ANN Search    │
│ • Animations    │    │ • Codable       │    │ • Migrations    │    │ • Risk Models   │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Security      │    │   Logging       │    │   Monitoring    │    │   Integration   │
│                 │    │                 │    │                 │    │                 │
│ • Encryption    │    │ • OSLog         │    │ • Performance   │    │ • REST APIs     │
│ • Hashing       │    │ • File Logs     │    │ • Metrics       │    │ • JSON/XML      │
│ • Key Management│    │ • Structured    │    │ • Health Checks │    │ • Webhooks      │
│ • Audit Trail   │    │ • Categories    │    │ • Alerts        │    │ • Rate Limiting │
│ • Access Control│    │ • Export        │    │ • Dashboards    │    │ • Retry Logic   │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 Производительность и масштабирование

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Performance Characteristics                         │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Throughput    │    │   Latency       │    │   Memory        │    │   Storage       │
│                 │    │                 │    │                 │    │                 │
│ • 10k+ tx/min   │    │ • ML: <100ms    │    │ • <500MB        │    │ • Compressed    │
│ • Batch Import  │    │ • Rules: <10ms  │    │ • Efficient     │    │ • Indexed       │
│ • Real-time     │    │ • Vector: <50ms │    │ • Cached        │    │ • Encrypted     │
│ • Concurrent    │    │ • DB: <5ms      │    │ • Optimized     │    │ • Backup        │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Scalability   │    │   Reliability   │    │   Security      │    │   Maintainability│
│                 │    │                 │    │                 │    │                 │
│ • Horizontal    │    │ • 99.9% Uptime  │    │ • End-to-End    │    │ • Modular       │
│ • Vertical      │    │ • Fault Tolerant│    │ • Encryption    │    │ • Testable      │
│ • Load Balancing│    │ • Auto Recovery │    │ • Audit Trail   │    │ • Documented    │
│ • Caching       │    │ • Health Checks │    │ • Access Control│    │ • Versioned     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 Жизненный цикл транзакции

```
┌─────────────────┐
│  Transaction    │
│     Created     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data          │    │   Rules         │    │   ML            │
│  Processing     │    │   Evaluation    │    │   Inference     │
│                 │    │                 │    │                 │
│ • Normalize     │    │ • Check Rules   │    │ • Generate      │
│ • Validate      │    │ • Calculate     │    │   Embedding     │
│ • Enrich        │    │   Score         │    │ • Predict Risk  │
│ • Store         │    │ • Log Results   │    │ • Find Similar  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Risk          │    │   Decision      │    │   Action        │
│  Aggregation    │    │   Making        │    │   Execution     │
│                 │    │                 │    │                 │
│ • Combine       │    │ • Apply         │    │ • Auto Approve  │
│   Scores        │    │   Thresholds    │    │ • Flag Review   │
│ • Calculate     │    │ • Determine     │    │ • Block         │
│   Final         │    │   Action        │    │ • Notify        │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Storage       │    │   Logging       │    │   Analytics     │
│   & Indexing    │    │   & Audit       │    │   & Reporting   │
│                 │    │                 │    │                 │
│ • Persist       │    │ • Log All       │    │ • Update        │
│ • Index         │    │   Events        │    │   Metrics       │
│ • Cache         │    │ • Audit Trail   │    │ • Generate      │
│ • Archive       │    │ • Export        │    │   Reports       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛡️ Безопасность и соответствие

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Security & Compliance                               │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data          │    │   Access        │    │   Audit         │    │   Compliance    │
│  Protection     │    │   Control       │    │   & Logging     │    │   & Standards   │
│                 │    │                 │    │                 │    │                 │
│ • Encryption    │    │ • Role-based    │    │ • All Actions   │    │ • GDPR          │
│ • Hashing       │    │ • Permissions   │    │ • Timestamps    │    │ • PCI DSS       │
│ • Key Management│    │ • Authentication│    │ • User Tracking │    │ • SOX           │
│ • Secure Storage│    │ • Authorization │    │ • Data Lineage  │    │ • AML/KYC       │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Network       │    │   Application   │    │   Infrastructure│    │   Monitoring    │
│   Security      │    │   Security      │    │   Security      │    │   & Alerting    │
│                 │    │                 │    │                 │    │                 │
│ • TLS/SSL       │    │ • Input         │    │ • Secure        │    │ • Real-time     │
│ • VPN           │    │   Validation    │    │   Configuration│    │   Monitoring    │
│ • Firewall      │    │ • Output        │    │ • Patch         │    │ • Anomaly       │
│ • Rate Limiting │    │   Encoding      │    │   Management    │    │   Detection     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

Эта архитектурная диаграмма показывает полную структуру FMLD Panel и помогает понять, как различные компоненты взаимодействуют друг с другом для создания enterprise-grade anti-fraud системы.





