# FMLD Panel - Setup Guide

Этот проект был очищен от демо-мусора и настроен для работы с бесплатными альтернативами.

## 🚀 Быстрый старт

### 1. Установка зависимостей

```bash
# Клонируйте проект
git clone <your-repo>
cd "FMLD Panel"

# Установите Ollama (опционально, для локального LLM)
brew install ollama

# Запустите Ollama в фоне
ollama serve
```

### 2. Настройка переменных окружения

Создайте файл `.env` в корне проекта или установите переменные окружения:

```bash
# Основные настройки
export ENVIRONMENT=development
export DEBUG_MODE=true
export LOG_LEVEL=info

# AI/ML сервисы
export ENABLE_OPENAI=false
export ENABLE_LOCAL_ML=true
export ENABLE_BIN_LOOKUP=true

# API ключи (опционально)
export OPENAI_API_KEY=your-openai-key-here
export BINLIST_API_KEY=your-binlist-key-here
export GOOGLE_MAPS_API_KEY=your-google-maps-key-here
export MAPBOX_API_KEY=your-mapbox-key-here

# Stripe (опционально)
export STRIPE_SECRET_KEY=your-stripe-secret-key
export STRIPE_PUBLISHABLE_KEY=your-stripe-publishable-key
```

### 3. Запуск проекта

```bash
# Откройте проект в Xcode
open "FMLD Panel.xcodeproj"

# Или соберите из командной строки
xcodebuild -project "FMLD Panel.xcodeproj" -scheme "FMLD Panel" build
```

## 🛠 Что было изменено

### ✅ Очищено от демо-мусора:

1. **Конфигурация**
   - Убраны хардкод API ключи
   - Добавлена поддержка ENV переменных
   - Создан `SecretsManager` для безопасного управления секретами

2. **BIN Database**
   - Заменена на бесплатную альтернативу
   - Добавлена поддержка CSV файлов
   - Интеграция с бесплатными BIN API

3. **ML/AI сервисы**
   - Заменен OpenAI на локальную ML модель
   - Добавлена поддержка Ollama для локального LLM
   - Создан `LocalMLService` с правилами

4. **Rules Engine**
   - Правила вынесены в JSON конфигурацию
   - Можно редактировать без изменения кода
   - Поддержка динамической загрузки правил

5. **Тестовые данные**
   - Создан генератор реалистичных транзакций
   - Поддержка различных типов тестовых данных
   - Интеграция с реальными API для получения данных

## 📁 Структура проекта

```
FMLD Panel/
├── Configuration/
│   ├── SecretsManager.swift      # Управление секретами
│   ├── AIConfiguration.swift     # Конфигурация AI (очищена)
│   └── APIConfiguration.swift    # Конфигурация API (очищена)
├── Data/
│   ├── bin_database.csv          # CSV база BIN данных
│   └── Sources/
│       ├── FreeBinDatabase.swift # Бесплатная BIN база
│       └── TestDataGenerator.swift # Генератор тестовых данных
├── AI/
│   ├── LocalMLService.swift      # Локальная ML модель
│   └── OllamaService.swift       # Интеграция с Ollama
├── Rules/
│   ├── rules_config.json         # JSON конфигурация правил
│   └── JSONRuleModels.swift      # Модели для JSON правил
└── UI/
    └── Views/
        └── FreeAPIView.swift     # UI для тестирования API (обновлен)
```

## 🔧 Настройка сервисов

### Ollama (Локальный LLM)

```bash
# Установка модели
ollama pull llama3.1:8b

# Проверка статуса
ollama list

# Запуск сервера
ollama serve
```

### BIN Lookup

Проект автоматически использует:
1. Локальную CSV базу (`bin_database.csv`)
2. Бесплатные API (binlist.net)
3. Fallback данные

### Правила

Правила настраиваются в файле `Rules/rules_config.json`:

```json
{
  "rules": [
    {
      "id": "high_amount",
      "name": "High Amount",
      "conditions": [
        {
          "field": "amount",
          "operator": "greaterThan",
          "value": "5000"
        }
      ],
      "action": "review"
    }
  ]
}
```

## 🧪 Тестирование

### Генерация тестовых данных

```swift
// В коде
let testTransactions = TestDataGenerator.shared.generateTestTransactions(count: 50)
let highRiskTransactions = TestDataGenerator.shared.generateHighRiskTransactions(count: 10)
let fraudulentTransactions = TestDataGenerator.shared.generateFraudulentTransactions(count: 5)
```

### Тестирование API

1. Откройте вкладку "Free APIs & Databases"
2. Нажмите "Test" на любом API
3. При успешном тесте автоматически создадутся транзакции

## 🔍 Мониторинг

### Логи

Логи доступны в консоли Xcode или в файле:
- Уровень: `INFO`, `WARNING`, `ERROR`
- Компоненты: AI, Rules, Database, API

### Метрики

- Количество загруженных BIN записей
- Статус AI сервисов
- Статистика правил
- API успешность

## 🚨 Troubleshooting

### Ollama не работает

```bash
# Проверьте статус
ollama ps

# Перезапустите сервер
pkill ollama
ollama serve
```

### BIN данные не загружаются

1. Проверьте файл `bin_database.csv`
2. Убедитесь что интернет доступен для API
3. Проверьте логи на ошибки

### Правила не применяются

1. Проверьте синтаксис `rules_config.json`
2. Убедитесь что файл добавлен в Bundle
3. Проверьте логи загрузки правил

## 📊 Производительность

### Оптимизация

- BIN данные кешируются локально
- AI модели загружаются один раз
- Правила компилируются при старте

### Лимиты

- BIN API: 1000 запросов/месяц (бесплатно)
- Ollama: без лимитов (локально)
- CSV база: без лимитов

## 🔒 Безопасность

### Секреты

- API ключи хранятся в ENV переменных
- Нет хардкод ключей в коде
- Поддержка .env файлов

### Данные

- Тестовые данные не содержат реальной информации
- BIN данные анонимизированы
- Логи не содержат чувствительных данных

## 📈 Развитие

### Следующие шаги

1. Добавить больше бесплатных API
2. Улучшить локальную ML модель
3. Добавить веб-интерфейс для правил
4. Интеграция с реальными данными

### Вклад в проект

1. Fork репозитория
2. Создайте feature branch
3. Внесите изменения
4. Создайте Pull Request

---

**Готово!** Проект очищен от демо-мусора и готов к работе с бесплатными альтернативами.

