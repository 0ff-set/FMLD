# FMLD Panel - Примеры использования

## 🚀 Быстрый старт

### 1. Создание транзакции

```swift
import FMLD_Panel

// Создание новой транзакции
let transactionInput = TransactionInput(
    amount: 1000.00,
    currency: "USD",
    cardBin: "411111",
    walletAddress: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
    billingAddress: AddressInput(
        street: "123 Main St",
        city: "New York",
        state: "NY",
        country: "US",
        postalCode: "10001",
        coordinates: nil
    ),
    shippingAddress: nil,
    userId: "user123",
    metadata: [
        "source": "mobile_app",
        "device_id": "device_456"
    ]
)

// Создание транзакции через репозиторий
let repository = TransactionRepository(
    database: DatabaseManager.shared.database,
    embeddingGenerator: CoreMLEmbeddingGenerator()
)

let transaction = try await repository.createTransaction(transactionInput)
print("Transaction created: \(transaction.id)")
```

### 2. Оценка риска

```swift
// Создание risk scorer
let riskScorer = RiskScorer(
    ruleEngine: RuleEngine(
        database: DatabaseManager.shared.database,
        rules: []
    ),
    embeddingGenerator: CoreMLEmbeddingGenerator()
)

// Оценка риска транзакции
let riskScore = try await riskScorer.scoreTransaction(transactionInput)

print("Risk Score: \(riskScore.finalScore)")
print("Decision: \(riskScore.decision)")
print("Confidence: \(riskScore.confidence)")

// Проверка сработавших правил
for rule in riskScore.triggeredRules {
    print("Rule: \(rule.details) - Score: \(rule.score)")
}
```

### 3. Поиск похожих транзакций

```swift
// Поиск похожих транзакций
let similarTransactions = try await repository.getSimilarTransactions(
    to: transaction,
    limit: 10
)

for similar in similarTransactions {
    print("Similar transaction: \(similar.referenceId)")
    print("Similarity: \(similar.similarity)")
    print("Distance: \(similar.distance)")
}
```

## 📊 Аналитика

### 1. Получение статистики транзакций

```swift
// Аналитика за последние 30 дней
let dateRange = DateInterval(
    start: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
    end: Date()
)

let analytics = try await repository.getTransactionAnalytics(
    dateRange: dateRange,
    groupBy: .day
)

print("Total transactions: \(analytics.totalTransactions)")
print("Total amount: \(analytics.totalAmount)")
print("Average amount: \(analytics.averageAmount)")

// Распределение по статусам
for (status, count) in analytics.riskDistribution {
    print("\(status): \(count)")
}

// Распределение по странам
for (country, count) in analytics.countryDistribution {
    print("\(country): \(count)")
}
```

### 2. Фильтрация транзакций

```swift
// Получение high-risk транзакций
let highRiskTransactions = try await repository.getTransactionsByRiskScore(
    minScore: 0.7,
    maxScore: 1.0
)

// Фильтрация по статусу
let pendingTransactions = try await repository.getTransactions(
    status: .pending,
    limit: 50
)

// Фильтрация по пользователю
let userTransactions = try await repository.getTransactions(
    userId: "user123",
    limit: 100
)
```

## 🔧 Правила и ML

### 1. Создание правила

```swift
// Создание нового правила
let rule = Rule(
    id: UUID().uuidString,
    name: "High Amount Check",
    description: "Flag transactions over $10,000",
    category: .amount,
    condition: "amount > 10000",
    weight: 0.8,
    isActive: true,
    priority: 1,
    createdAt: Date(),
    updatedAt: Date()
)

// Сохранение правила в БД
try await db.write { db in
    try rule.insert(db)
}
```

### 2. Настройка ML модели

```swift
// Создание embedding generator
let embeddingGenerator = CoreMLEmbeddingGenerator()

// Генерация embedding для текста
let embedding = try await embeddingGenerator.generateEmbedding(
    for: "Transaction amount: $1000, Currency: USD, BIN: 411111"
)

// Генерация embedding для транзакции
let transactionEmbedding = try await embeddingGenerator.generateEmbedding(
    for: transaction
)
```

## 🌐 Интеграции

### 1. BIN Database

```swift
// Создание BIN service
let binService = BinDatabaseService(database: DatabaseManager.shared.database)

// Поиск информации о карте
let card = try await binService.lookupBIN("411111")

print("Card scheme: \(card.scheme)")
print("Issuer: \(card.issuer)")
print("Country: \(card.country)")
print("Risk level: \(card.riskLevel)")

// Обновление BIN базы
await binService.updateBINDatabase()
```

### 2. Crypto Blacklist

```swift
// Создание blacklist service
let blacklistService = CryptoBlacklistService(database: DatabaseManager.shared.database)

// Проверка адреса кошелька
let result = try await blacklistService.checkWalletAddress(
    "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
)

if result.isBlacklisted {
    print("Address is blacklisted: \(result.reason)")
    print("Confidence: \(result.confidence)")
} else {
    print("Address is clean")
}

// Обновление blacklist
await blacklistService.updateBlacklist()
```

## 🔍 Мониторинг и логирование

### 1. Логирование транзакций

```swift
// Создание logger
let logger = Logger.shared

// Логирование создания транзакции
logger.logTransaction(transaction, action: .created)

// Логирование оценки риска
logger.logRiskAssessment(transaction, riskScore: riskScore)

// Логирование срабатывания правила
logger.logRuleTriggered(rule, transaction: transaction, score: 0.8)
```

### 2. Системные события

```swift
// Логирование системных событий
logger.logSystemEvent(.appLaunched)
logger.logSystemEvent(.databaseInitialized)
logger.logSystemEvent(.rulesUpdated)

// Логирование событий безопасности
logger.logSecurityEvent(.highRiskTransaction)
logger.logSecurityEvent(.suspiciousActivity)
```

### 3. Экспорт логов

```swift
// Получение списка логов
let logFiles = logger.getLogFiles()

// Экспорт логов
let exportURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("logs_export.zip")

try logger.exportLogs(to: exportURL)

// Очистка старых логов
logger.clearOldLogs(olderThan: 30)
```

## 🗄️ Управление базой данных

### 1. Статистика БД

```swift
// Получение статистики БД
let stats = try await DatabaseManager.shared.getDatabaseStats()

print("Total transactions: \(stats.transactionCount)")
print("Total cards: \(stats.cardCount)")
print("Total addresses: \(stats.addressCount)")
print("Database size: \(stats.databaseSizeMB) MB")
```

### 2. Бэкап и восстановление

```swift
// Создание бэкапа
let backupURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("backup.sqlite")

try DatabaseManager.shared.backup(to: backupURL)

// Восстановление из бэкапа
try DatabaseManager.shared.restore(from: backupURL)
```

### 3. Миграции

```swift
// Выполнение миграции
try DatabaseManager.shared.migrateToVersion(2)
```

## 🎨 UI Компоненты

### 1. Создание кастомного view

```swift
struct CustomTransactionView: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(transaction.currency)
                .font(.headline)
            
            Text(transaction.amount, format: .currency(code: transaction.currency))
                .font(.title)
                .fontWeight(.bold)
            
            Text(transaction.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
```

### 2. Создание кастомного chart

```swift
struct CustomRiskChart: View {
    let analytics: TransactionAnalytics
    
    var body: some View {
        Chart {
            ForEach(Array(analytics.riskDistribution.keys.sorted()), id: \.self) { status in
                BarMark(
                    x: .value("Status", status),
                    y: .value("Count", analytics.riskDistribution[status] ?? 0)
                )
                .foregroundStyle(by: .value("Status", status))
            }
        }
        .chartForegroundStyleScale([
            "pending": .orange,
            "approved": .green,
            "rejected": .red
        ])
    }
}
```

## 🧪 Тестирование

### 1. Unit тесты

```swift
import XCTest
@testable import FMLD_Panel

class TransactionRepositoryTests: XCTestCase {
    var repository: TransactionRepository!
    var database: DatabaseWriter!
    
    override func setUp() {
        database = try! DatabaseQueue()
        repository = TransactionRepository(
            database: database,
            embeddingGenerator: MockEmbeddingGenerator()
        )
    }
    
    func testCreateTransaction() async throws {
        let input = TransactionInput(
            amount: 100.0,
            currency: "USD",
            cardBin: nil,
            walletAddress: nil,
            billingAddress: nil,
            shippingAddress: nil,
            userId: nil,
            metadata: [:]
        )
        
        let transaction = try await repository.createTransaction(input)
        
        XCTAssertEqual(transaction.amount, 100.0)
        XCTAssertEqual(transaction.currency, "USD")
    }
}
```

### 2. Mock объекты

```swift
class MockEmbeddingGenerator: EmbeddingGenerator {
    func generateEmbedding(for text: String) async throws -> [Double] {
        return Array(repeating: 0.0, count: 384)
    }
    
    func generateEmbedding(for transaction: Transaction) async throws -> [Double] {
        return Array(repeating: 0.0, count: 384)
    }
    
    func generateEmbedding(for address: Address) async throws -> [Double] {
        return Array(repeating: 0.0, count: 384)
    }
}
```

## 🚀 Production настройки

### 1. Конфигурация безопасности

```swift
// Настройка шифрования БД
let configuration = Configuration()
configuration.prepareDatabase { db in
    try db.execute(sql: "PRAGMA key = 'your-secure-key'")
    try db.execute(sql: "PRAGMA cipher_page_size = 4096")
    try db.execute(sql: "PRAGMA kdf_iter = 64000")
}
```

### 2. Настройка производительности

```swift
// Оптимизация БД
configuration.prepareDatabase { db in
    try db.execute(sql: "PRAGMA journal_mode = WAL")
    try db.execute(sql: "PRAGMA synchronous = NORMAL")
    try db.execute(sql: "PRAGMA cache_size = 10000")
    try db.execute(sql: "PRAGMA temp_store = MEMORY")
}
```

### 3. Мониторинг

```swift
// Настройка мониторинга
let monitor = PerformanceMonitor()
monitor.startMonitoring()

// Отслеживание метрик
monitor.trackTransactionProcessingTime { time in
    logger.info("Transaction processed in \(time)ms")
}

monitor.trackMLInferenceTime { time in
    logger.info("ML inference completed in \(time)ms")
}
```

---

Эти примеры показывают основные возможности FMLD Panel и помогут вам быстро начать работу с системой.





