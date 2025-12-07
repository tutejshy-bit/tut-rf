# Руководство по оптимизации производительности ESP32 CC1101

## 🚀 Быстрые победы (Quick Wins)

### 1. Оптимизация вывода в Serial

**Проблема**: Множество Serial.print() замедляют выполнение

**Текущий код** (по всему проекту):
```cpp
ESP_LOGD(TAG, "Processing command");
ESP_LOGD(TAG, "Data: %s", data);
ESP_LOGD(TAG, "Size: %d", size);
```

**Оптимизация**:
```cpp
// В platformio.ini изменить уровень логирования для production:
build_flags = -DCORE_DEBUG_LEVEL=2  // 0=none, 1=error, 2=warn, 3=info, 4=debug

// Или использовать условную компиляцию:
#ifdef DEBUG_MODE
    #define DEBUG_LOG(tag, format, ...) ESP_LOGD(tag, format, ##__VA_ARGS__)
#else
    #define DEBUG_LOG(tag, format, ...) ((void)0)
#endif

// Использование:
DEBUG_LOG(TAG, "Processing command: %s", cmd);
```

**Выигрыш**: До 30% улучшение производительности в production

---

### 2. Пре-аллокация String объектов

**Проблема**: String постоянно реаллоцирует память

**Текущий код**:
```cpp
String fileList = "[";
while (...) {
    fileList += ",";  // Реаллокация каждый раз!
    fileList += item;
}
```

**Оптимизация**:
```cpp
String fileList;
fileList.reserve(4096);  // Резервируем сразу 4KB
fileList = "[";
while (...) {
    fileList += ",";  // Теперь без реаллокации
    fileList += item;
}
```

**Выигрыш**: 50% быстрее, меньше фрагментации

---

### 3. Использование const references

**Проблема**: Копирование больших объектов

**Текущий код**:
```cpp
void processData(String data) {  // Копирование!
    // ...
}
```

**Оптимизация**:
```cpp
void processData(const String& data) {  // Только ссылка
    // ...
}

// Еще лучше - для read-only операций:
void processData(const char* data, size_t len) {
    // ...
}
```

**Выигрыш**: Меньше копирований, быстрее работа

---

### 4. Кэширование частых вычислений

**Проблема**: Повторные вычисления одного и того же

**Текущий код**:
```cpp
for (int i = 0; i < data.length(); i++) {
    process(data[i]);  // data.length() вызывается каждый раз!
}
```

**Оптимизация**:
```cpp
const size_t len = data.length();  // Один раз
for (int i = 0; i < len; i++) {
    process(data[i]);
}

// Еще лучше - прямой доступ:
const char* dataPtr = data.c_str();
for (int i = 0; i < len; i++) {
    process(dataPtr[i]);
}
```

**Выигрыш**: 10-20% ускорение циклов

---

## 📊 Профилирование и мониторинг

### Добавление счетчиков производительности

**Создать файл: `include/PerformanceMonitor.h`**

```cpp
#ifndef PerformanceMonitor_h
#define PerformanceMonitor_h

#include <Arduino.h>

class PerformanceMonitor {
private:
    struct Metrics {
        unsigned long calls = 0;
        unsigned long totalTime = 0;
        unsigned long minTime = ULONG_MAX;
        unsigned long maxTime = 0;
    };
    
    Metrics metrics[10];  // 10 разных метрик
    
public:
    enum MetricID {
        FILE_LIST = 0,
        BLE_SEND = 1,
        RECORD_SIGNAL = 2,
        TRANSMIT_SIGNAL = 3,
        // ... добавить по необходимости
    };
    
    class ScopedTimer {
        PerformanceMonitor& monitor;
        MetricID id;
        unsigned long startTime;
        
    public:
        ScopedTimer(PerformanceMonitor& mon, MetricID metricId) 
            : monitor(mon), id(metricId) {
            startTime = micros();
        }
        
        ~ScopedTimer() {
            unsigned long elapsed = micros() - startTime;
            monitor.record(id, elapsed);
        }
    };
    
    void record(MetricID id, unsigned long elapsed) {
        Metrics& m = metrics[id];
        m.calls++;
        m.totalTime += elapsed;
        if (elapsed < m.minTime) m.minTime = elapsed;
        if (elapsed > m.maxTime) m.maxTime = elapsed;
    }
    
    void printStats(MetricID id, const char* name) {
        Metrics& m = metrics[id];
        if (m.calls > 0) {
            unsigned long avgTime = m.totalTime / m.calls;
            ESP_LOGI("Perf", "%s: calls=%lu, avg=%luµs, min=%luµs, max=%luµs",
                    name, m.calls, avgTime, m.minTime, m.maxTime);
        }
    }
    
    void reset() {
        for (auto& m : metrics) {
            m = Metrics();
        }
    }
    
    static PerformanceMonitor& getInstance() {
        static PerformanceMonitor instance;
        return instance;
    }
};

// Макрос для удобного использования
#define PERF_MEASURE(id) \
    PerformanceMonitor::ScopedTimer _timer(PerformanceMonitor::getInstance(), id)

#endif // PerformanceMonitor_h
```

**Использование**:

```cpp
void listFiles(const String& path) {
    PERF_MEASURE(PerformanceMonitor::FILE_LIST);
    
    // ... код функции ...
}

// В loop() или периодически:
void printPerformanceStats() {
    auto& monitor = PerformanceMonitor::getInstance();
    monitor.printStats(PerformanceMonitor::FILE_LIST, "listFiles");
    monitor.printStats(PerformanceMonitor::BLE_SEND, "bleSend");
    // ...
    monitor.reset();  // Сброс для новых измерений
}
```

---

## ⚡ Оптимизация BLE передачи

### 1. Батчинг нотификаций

**Проблема**: Каждая нотификация - отдельная BLE операция

**Текущий код**:
```cpp
notify("type1", "data1");
notify("type2", "data2");
notify("type3", "data3");
```

**Оптимизация**:
```cpp
class NotificationBatcher {
    String batch;
    static const size_t MAX_BATCH_SIZE = 500;
    unsigned long lastFlush = 0;
    static const unsigned long FLUSH_INTERVAL = 50; // 50ms
    
public:
    void add(const String& type, const String& data) {
        String notification = "{\"type\":\"" + type + "\",\"data\":" + data + "}";
        
        if (batch.length() + notification.length() > MAX_BATCH_SIZE) {
            flush();
        }
        
        if (batch.length() > 0) batch += ",";
        batch += notification;
        
        // Auto-flush по таймауту
        if (millis() - lastFlush > FLUSH_INTERVAL) {
            flush();
        }
    }
    
    void flush() {
        if (batch.length() > 0) {
            String wrapper = "[" + batch + "]";
            sendBinaryResponse(wrapper);
            batch = "";
            lastFlush = millis();
        }
    }
};
```

**Выигрыш**: Меньше BLE операций, выше throughput

---

### 2. Адаптивный размер чанков

**Текущий код**: Фиксированный размер чанка (100 байт)

**Оптимизация**:
```cpp
class AdaptiveChunking {
    uint8_t currentChunkSize = 100;
    unsigned long lastSuccessTime = 0;
    int consecutiveSuccesses = 0;
    
public:
    uint8_t getChunkSize() const { return currentChunkSize; }
    
    void onSuccess() {
        consecutiveSuccesses++;
        if (consecutiveSuccesses > 10 && currentChunkSize < 200) {
            currentChunkSize += 20;  // Увеличиваем размер
            consecutiveSuccesses = 0;
            ESP_LOGD("BLE", "Increased chunk size to %d", currentChunkSize);
        }
        lastSuccessTime = millis();
    }
    
    void onFailure() {
        if (currentChunkSize > 50) {
            currentChunkSize -= 20;  // Уменьшаем размер
            ESP_LOGD("BLE", "Decreased chunk size to %d", currentChunkSize);
        }
        consecutiveSuccesses = 0;
    }
};
```

**Выигрыш**: Автоматическая адаптация к качеству связи

---

## 🔋 Энергоэффективность

### 1. Dynamic CPU Frequency Scaling

**Добавить в setup()**:
```cpp
void setupPowerManagement() {
    // Снижаем частоту когда не нужна производительность
    setCpuFrequencyMhz(80);  // Вместо 240MHz
    
    // Или динамически:
    if (heavyOperation) {
        setCpuFrequencyMhz(240);
    } else {
        setCpuFrequencyMhz(80);
    }
}
```

### 2. Оптимизация Wi-Fi/BLE

**В config.h**:
```cpp
// Отключаем WiFi если используем только BLE
#define CONFIG_ESP32_WIFI_ENABLED 0

// Оптимизация BLE
#define CONFIG_BTDM_CTRL_MODE_BLE_ONLY 1
#define CONFIG_BTDM_CTRL_MODE_BR_EDR_ONLY 0
#define CONFIG_BTDM_CTRL_MODE_BTDM 0
```

---

## 💾 Оптимизация работы с памятью

### 1. Пул объектов для QueueItem

**Проблема**: Постоянное new/delete для QueueItem

**Создать файл: `include/ObjectPool.h`**

```cpp
template<typename T, size_t PoolSize = 10>
class ObjectPool {
private:
    struct PoolEntry {
        T object;
        bool inUse;
    };
    
    PoolEntry pool[PoolSize];
    
public:
    ObjectPool() {
        for (auto& entry : pool) {
            entry.inUse = false;
        }
    }
    
    T* acquire() {
        for (auto& entry : pool) {
            if (!entry.inUse) {
                entry.inUse = true;
                return &entry.object;
            }
        }
        // Пул заполнен, fallback на new
        ESP_LOGW("Pool", "Pool exhausted, using new");
        return new T();
    }
    
    void release(T* obj) {
        // Проверяем, из пула ли объект
        for (auto& entry : pool) {
            if (&entry.object == obj) {
                entry.inUse = false;
                return;
            }
        }
        // Не из пула, удаляем
        delete obj;
    }
    
    size_t getUsageCount() const {
        size_t count = 0;
        for (const auto& entry : pool) {
            if (entry.inUse) count++;
        }
        return count;
    }
};

// Использование
ObjectPool<QueueItem> queueItemPool;

QueueItem* item = queueItemPool.acquire();
// ... использование ...
queueItemPool.release(item);
```

---

### 2. Circular Buffer для логов

**Проблема**: Логи забивают Serial и тормозят

**Оптимизация**:
```cpp
class CircularLogBuffer {
private:
    static const size_t BUFFER_SIZE = 100;
    String logs[BUFFER_SIZE];
    size_t head = 0;
    size_t count = 0;
    
public:
    void add(const String& log) {
        logs[head] = log;
        head = (head + 1) % BUFFER_SIZE;
        if (count < BUFFER_SIZE) count++;
    }
    
    void flush() {
        size_t start = (head >= count) ? (head - count) : 0;
        for (size_t i = 0; i < count; i++) {
            size_t idx = (start + i) % BUFFER_SIZE;
            Serial.println(logs[idx]);
        }
        count = 0;
    }
    
    // Вызывать в низкоприоритетной задаче
    static void flushTask(void* params) {
        CircularLogBuffer* buffer = (CircularLogBuffer*)params;
        while (true) {
            vTaskDelay(pdMS_TO_TICKS(1000));  // Раз в секунду
            buffer->flush();
        }
    }
};
```

---

## 📈 Оптимизация файловых операций

### 1. Кэширование списка файлов

**Создать файл: `include/FileCache.h`**

```cpp
class FileCache {
private:
    struct CacheEntry {
        String path;
        String content;
        unsigned long timestamp;
        bool valid;
    };
    
    static const size_t CACHE_SIZE = 5;
    static const unsigned long CACHE_TTL = 30000;  // 30 секунд
    CacheEntry cache[CACHE_SIZE];
    
public:
    String get(const String& path) {
        unsigned long now = millis();
        
        for (auto& entry : cache) {
            if (entry.valid && entry.path == path) {
                if (now - entry.timestamp < CACHE_TTL) {
                    ESP_LOGD("Cache", "Cache hit for %s", path.c_str());
                    return entry.content;
                } else {
                    entry.valid = false;  // Expired
                }
            }
        }
        
        return "";  // Cache miss
    }
    
    void put(const String& path, const String& content) {
        // Простая FIFO замена
        static size_t nextSlot = 0;
        
        cache[nextSlot] = {
            .path = path,
            .content = content,
            .timestamp = millis(),
            .valid = true
        };
        
        nextSlot = (nextSlot + 1) % CACHE_SIZE;
        ESP_LOGD("Cache", "Cached %s (%d bytes)", path.c_str(), content.length());
    }
    
    void invalidate(const String& path = "") {
        for (auto& entry : cache) {
            if (path.isEmpty() || entry.path == path) {
                entry.valid = false;
            }
        }
    }
};

// Использование в FilesManager
String listAllFiles(const String& path) {
    static FileCache cache;
    
    String cached = cache.get(path);
    if (!cached.isEmpty()) {
        return cached;
    }
    
    String result = /* ... реальный листинг ... */;
    cache.put(path, result);
    return result;
}
```

---

### 2. Асинхронное чтение файлов

**Проблема**: Блокирующее чтение больших файлов

**Оптимизация**:
```cpp
class AsyncFileReader {
private:
    File file;
    size_t chunkSize;
    size_t bytesRead;
    
public:
    AsyncFileReader(const String& path, size_t chunk = 512) 
        : chunkSize(chunk), bytesRead(0) {
        file = SD.open(path, FILE_READ);
    }
    
    bool readChunk(String& outData) {
        if (!file || !file.available()) {
            return false;
        }
        
        outData.reserve(chunkSize);
        size_t read = 0;
        
        while (file.available() && read < chunkSize) {
            outData += (char)file.read();
            read++;
        }
        
        bytesRead += read;
        
        // Даем другим задачам время
        if (file.available()) {
            vTaskDelay(pdMS_TO_TICKS(1));
        }
        
        return file.available();
    }
    
    void close() {
        if (file) file.close();
    }
    
    size_t getTotalBytesRead() const { return bytesRead; }
};

// Использование
void sendLargeFile(const String& path) {
    AsyncFileReader reader(path);
    String chunk;
    
    while (reader.readChunk(chunk)) {
        sendBinaryResponse(chunk);
        chunk = "";  // Очищаем для следующего чанка
    }
    
    reader.close();
}
```

---

## 🎯 Checklist перед релизом

### Производительность
- [ ] Отключен DEBUG_LEVEL для production
- [ ] Все String используют reserve()
- [ ] Нет блокирующих delay()
- [ ] Используются const references где возможно
- [ ] Критичные пути оптимизированы

### Память
- [ ] Нет утечек памяти
- [ ] Большие буферы не на стеке
- [ ] Используются пулы объектов
- [ ] Кэширование для частых операций
- [ ] Мониторинг heap включен

### BLE
- [ ] Оптимальный размер чанков
- [ ] Батчинг нотификаций где возможно
- [ ] Обработка ошибок передачи
- [ ] Адаптивная скорость

### Файлы
- [ ] Кэширование листингов
- [ ] Асинхронное чтение больших файлов
- [ ] Лимиты на количество файлов
- [ ] Проверка свободного места

---

## 📊 Целевые показатели производительности

| Метрика | Текущее | Цель | Приоритет |
|---------|---------|------|-----------|
| File listing (<100 files) | ~3s | <1s | Высокий |
| BLE response time | ~150ms | <50ms | Высокий |
| Memory fragmentation | 30% | <10% | Критический |
| Free heap (idle) | 50KB | >80KB | Средний |
| Signal record start | ~800ms | <300ms | Средний |
| Transmit latency | ~600ms | <200ms | Средний |

---

## 🔬 Инструменты для измерения

### 1. Heap Monitoring

```cpp
void printMemoryStats() {
    ESP_LOGI("Memory", "=== Memory Statistics ===");
    ESP_LOGI("Memory", "Free heap: %d bytes", ESP.getFreeHeap());
    ESP_LOGI("Memory", "Largest free block: %d bytes", ESP.getMaxAllocHeap());
    ESP_LOGI("Memory", "Min free heap: %d bytes", ESP.getMinFreeHeap());
    
    multi_heap_info_t info;
    heap_caps_get_info(&info, MALLOC_CAP_INTERNAL);
    ESP_LOGI("Memory", "Total free: %d bytes", info.total_free_bytes);
    ESP_LOGI("Memory", "Total allocated: %d bytes", info.total_allocated_bytes);
    ESP_LOGI("Memory", "Largest free block: %d bytes", info.largest_free_block);
}
```

### 2. Task Stack Usage

```cpp
void printTaskStats() {
    char taskStats[512];
    vTaskGetRunTimeStats(taskStats);
    ESP_LOGI("Tasks", "Runtime stats:\n%s", taskStats);
    
    TaskHandle_t handle = xTaskGetCurrentTaskHandle();
    UBaseType_t stackHighWater = uxTaskGetStackHighWaterMark(handle);
    ESP_LOGI("Tasks", "Stack high water mark: %d words", stackHighWater);
}
```

---

## 💡 Дополнительные советы

### 1. Использовать WiFi только когда нужно
```cpp
// Отключать WiFi при использовании BLE
WiFi.mode(WIFI_OFF);
btStart();  // Экономия ~30-40mA
```

### 2. Batch-обработка SD операций
```cpp
// Группировать мелкие записи в одну большую
std::vector<String> pendingWrites;
// ... накопить ...
// Записать все разом
```

### 3. Компиляция с оптимизацией
```ini
# platformio.ini
build_flags = 
    -O2  # Оптимизация скорости
    -DCORE_DEBUG_LEVEL=2  # Меньше логов
    -ffunction-sections
    -fdata-sections
build_unflags = -Os  # Убрать оптимизацию размера
```

---

**Результат**: После применения всех оптимизаций ожидается:
- ⚡ 40-50% улучшение отклика
- 💾 30-40% снижение использования памяти
- 🔋 20-30% снижение энергопотребления
- 📈 Более плавная работа UI в приложении

















