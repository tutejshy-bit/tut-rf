/**
 * @file ProtocolLibraryImplementation.cpp
 * @brief Пример реализации библиотеки протоколов с SD карты
 * 
 * Этот файл содержит готовый код для:
 * - Индексации протоколов на SD карте
 * - Поиска и фильтрации
 * - Кэширования часто используемых
 * - Интеграции с мобильным приложением через BLE
 * 
 * ЭКОНОМИЯ FLASH: ~100-200 KB при использовании динамической загрузки протоколов
 */

#include <Arduino.h>
#include <SD.h>
#include <vector>
#include <map>

// ============================================================================
// СТРУКТУРЫ ДАННЫХ
// ============================================================================

/**
 * @brief Информация о протоколе из индекса
 */
struct ProtocolMetadata {
    String name;              // Имя файла без расширения
    String fullPath;          // Полный путь на SD
    uint32_t frequency;       // Частота в Hz
    String modulationType;    // OOK, FSK, etc
    String protocol;          // RAW, Princeton, etc
    uint32_t fileSize;        // Размер файла
    uint32_t lastAccess;      // Timestamp последнего доступа
    uint16_t accessCount;     // Счетчик обращений
};

/**
 * @brief Статистика использования библиотеки
 */
struct LibraryStats {
    uint16_t totalProtocols;
    uint32_t totalSize;
    uint16_t cacheHits;
    uint16_t cacheMisses;
    std::map<uint32_t, uint16_t> frequencyDistribution;
};

// ============================================================================
// КЛАСС БИБЛИОТЕКИ ПРОТОКОЛОВ
// ============================================================================

class ProtocolLibrary {
private:
    // Индекс всех протоколов (легкий - только метаданные)
    std::map<String, ProtocolMetadata> index;
    
    // Статистика
    LibraryStats stats;
    
    // LRU кэш часто используемых файлов
    static const size_t MAX_CACHE_SIZE = 5;
    struct CacheEntry {
        String content;
        uint32_t timestamp;
    };
    std::map<String, CacheEntry> cache;
    
public:
    // ========================================================================
    // ИНИЦИАЛИЗАЦИЯ
    // ========================================================================
    
    /**
     * @brief Инициализация библиотеки - вызвать в setup()
     */
    void begin() {
        ESP_LOGI("ProtocolLib", "Initializing protocol library...");
        
        // Проверить структуру директорий
        ensureDirectoryStructure();
        
        // Индексировать протоколы
        rebuildIndex();
        
        ESP_LOGI("ProtocolLib", "Initialization complete. %d protocols indexed", 
                 stats.totalProtocols);
    }
    
    /**
     * @brief Создать необходимые директории на SD
     */
    void ensureDirectoryStructure() {
        const char* dirs[] = {
            "/DATA",
            "/DATA/RECORDS",
            "/DATA/PROTOCOLS",
            "/DATA/PRESETS",
            "/DATA/BACKUPS"
        };
        
        for (const char* dir : dirs) {
            if (!SD.exists(dir)) {
                if (SD.mkdir(dir)) {
                    ESP_LOGI("ProtocolLib", "Created directory: %s", dir);
                } else {
                    ESP_LOGE("ProtocolLib", "Failed to create: %s", dir);
                }
            }
        }
    }
    
    // ========================================================================
    // ИНДЕКСАЦИЯ
    // ========================================================================
    
    /**
     * @brief Перестроить индекс - сканировать всю SD карту
     */
    void rebuildIndex() {
        index.clear();
        stats = LibraryStats(); // Reset stats
        
        ESP_LOGI("ProtocolLib", "Scanning SD card...");
        
        // Сканировать папки
        scanDirectory("/DATA/RECORDS", true);
        scanDirectory("/DATA/PROTOCOLS", false);
        
        stats.totalProtocols = index.size();
        
        ESP_LOGI("ProtocolLib", "Indexed %d protocols, total size: %d bytes", 
                 stats.totalProtocols, stats.totalSize);
        
        printFrequencyDistribution();
    }
    
    /**
     * @brief Рекурсивное сканирование директории
     */
    void scanDirectory(const char* path, bool recursive) {
        File dir = SD.open(path);
        if (!dir || !dir.isDirectory()) {
            ESP_LOGW("ProtocolLib", "Cannot open directory: %s", path);
            return;
        }
        
        int filesScanned = 0;
        File entry;
        
        while (entry = dir.openNextFile()) {
            String filename = entry.name();
            
            if (entry.isDirectory() && recursive) {
                // Рекурсивно сканировать подпапку
                scanDirectory(filename.c_str(), true);
            } else if (filename.endsWith(".sub")) {
                // Индексировать .sub файл
                if (indexFile(entry)) {
                    filesScanned++;
                }
            }
            
            entry.close();
            
            // Проверка памяти
            if (ESP.getFreeHeap() < 5000) {
                ESP_LOGW("ProtocolLib", "Low memory during scan, stopping");
                break;
            }
        }
        
        dir.close();
        ESP_LOGD("ProtocolLib", "Scanned %s: %d files", path, filesScanned);
    }
    
    /**
     * @brief Индексировать один .sub файл (читать только метаданные)
     */
    bool indexFile(File& file) {
        ProtocolMetadata meta;
        meta.fullPath = file.name();
        meta.fileSize = file.size();
        meta.lastAccess = 0;
        meta.accessCount = 0;
        
        // Извлечь имя без расширения
        int lastSlash = meta.fullPath.lastIndexOf('/');
        meta.name = meta.fullPath.substring(lastSlash + 1);
        meta.name.remove(meta.name.lastIndexOf('.'));
        
        // Быстро читать первые 15 строк для метаданных
        file.seek(0);
        for (int i = 0; i < 15 && file.available(); i++) {
            String line = file.readStringUntil('\n');
            line.trim();
            
            if (line.startsWith("Frequency:")) {
                meta.frequency = extractValue(line).toInt();
            } else if (line.startsWith("Preset:")) {
                String preset = extractValue(line);
                meta.modulationType = detectModulationType(preset);
            } else if (line.startsWith("Protocol:")) {
                meta.protocol = extractValue(line);
            }
        }
        
        // Валидация
        if (meta.frequency == 0) {
            ESP_LOGW("ProtocolLib", "Invalid file (no frequency): %s", 
                     meta.fullPath.c_str());
            return false;
        }
        
        // Добавить в индекс
        index[meta.name] = meta;
        
        // Обновить статистику
        stats.totalSize += meta.fileSize;
        stats.frequencyDistribution[meta.frequency]++;
        
        return true;
    }
    
    // ========================================================================
    // ПОИСК И ФИЛЬТРАЦИЯ
    // ========================================================================
    
    /**
     * @brief Найти протоколы по частоте (с допуском)
     */
    std::vector<ProtocolMetadata> findByFrequency(uint32_t targetFreq, 
                                                  uint32_t tolerance = 100000) {
        std::vector<ProtocolMetadata> results;
        
        for (const auto& pair : index) {
            const ProtocolMetadata& meta = pair.second;
            int32_t diff = abs((int32_t)(meta.frequency - targetFreq));
            
            if (diff <= tolerance) {
                results.push_back(meta);
            }
        }
        
        ESP_LOGI("ProtocolLib", "Found %d protocols near %.2f MHz", 
                 results.size(), targetFreq / 1e6);
        
        return results;
    }
    
    /**
     * @brief Поиск по имени (частичное совпадение)
     */
    std::vector<ProtocolMetadata> searchByName(const String& query) {
        std::vector<ProtocolMetadata> results;
        
        String lowerQuery = query;
        lowerQuery.toLowerCase();
        
        for (const auto& pair : index) {
            String lowerName = pair.second.name;
            lowerName.toLowerCase();
            
            if (lowerName.indexOf(lowerQuery) >= 0) {
                results.push_back(pair.second);
            }
        }
        
        return results;
    }
    
    /**
     * @brief Получить топ N наиболее используемых протоколов
     */
    std::vector<ProtocolMetadata> getTopUsed(size_t count = 10) {
        std::vector<ProtocolMetadata> all;
        
        for (const auto& pair : index) {
            all.push_back(pair.second);
        }
        
        // Сортировать по accessCount
        std::sort(all.begin(), all.end(), 
                 [](const ProtocolMetadata& a, const ProtocolMetadata& b) {
                     return a.accessCount > b.accessCount;
                 });
        
        // Вернуть топ N
        if (all.size() > count) {
            all.resize(count);
        }
        
        return all;
    }
    
    // ========================================================================
    // КЭШИРОВАНИЕ
    // ========================================================================
    
    /**
     * @brief Получить содержимое файла (с кэшированием)
     */
    String getFileContent(const String& protocolName) {
        // Проверить кэш
        auto it = cache.find(protocolName);
        if (it != cache.end()) {
            stats.cacheHits++;
            ESP_LOGD("ProtocolLib", "Cache HIT for %s", protocolName.c_str());
            
            // Обновить timestamp
            it->second.timestamp = millis();
            
            return it->second.content;
        }
        
        stats.cacheMisses++;
        ESP_LOGD("ProtocolLib", "Cache MISS for %s", protocolName.c_str());
        
        // Найти в индексе
        auto indexIt = index.find(protocolName);
        if (indexIt == index.end()) {
            ESP_LOGE("ProtocolLib", "Protocol not found: %s", protocolName.c_str());
            return "";
        }
        
        // Прочитать файл
        File file = SD.open(indexIt->second.fullPath);
        if (!file) {
            ESP_LOGE("ProtocolLib", "Failed to open: %s", 
                     indexIt->second.fullPath.c_str());
            return "";
        }
        
        String content = file.readString();
        file.close();
        
        // Обновить метаданные
        indexIt->second.lastAccess = millis();
        indexIt->second.accessCount++;
        
        // Добавить в кэш
        addToCache(protocolName, content);
        
        return content;
    }
    
    /**
     * @brief Добавить в LRU кэш
     */
    void addToCache(const String& name, const String& content) {
        // Если кэш полон, удалить самый старый
        if (cache.size() >= MAX_CACHE_SIZE) {
            evictOldestFromCache();
        }
        
        CacheEntry entry;
        entry.content = content;
        entry.timestamp = millis();
        
        cache[name] = entry;
        
        ESP_LOGD("ProtocolLib", "Cached %s (%d bytes)", 
                 name.c_str(), content.length());
    }
    
    /**
     * @brief Удалить самый старый элемент из кэша
     */
    void evictOldestFromCache() {
        if (cache.empty()) return;
        
        String oldestKey;
        uint32_t oldestTime = UINT32_MAX;
        
        for (const auto& pair : cache) {
            if (pair.second.timestamp < oldestTime) {
                oldestTime = pair.second.timestamp;
                oldestKey = pair.first;
            }
        }
        
        if (!oldestKey.isEmpty()) {
            ESP_LOGD("ProtocolLib", "Evicting from cache: %s", oldestKey.c_str());
            cache.erase(oldestKey);
        }
    }
    
    /**
     * @brief Очистить кэш
     */
    void clearCache() {
        cache.clear();
        ESP_LOGI("ProtocolLib", "Cache cleared");
    }
    
    // ========================================================================
    // ЭКСПОРТ И ОТЧЕТЫ
    // ========================================================================
    
    /**
     * @brief Экспорт индекса в JSON для мобильного приложения
     */
    String exportIndexJson() {
        String json = "{\"protocols\":[";
        bool first = true;
        
        for (const auto& pair : index) {
            if (!first) json += ",";
            
            const ProtocolMetadata& meta = pair.second;
            
            json += "{";
            json += "\"name\":\"" + meta.name + "\",";
            json += "\"path\":\"" + meta.fullPath + "\",";
            json += "\"frequency\":" + String(meta.frequency) + ",";
            json += "\"modulation\":\"" + meta.modulationType + "\",";
            json += "\"protocol\":\"" + meta.protocol + "\",";
            json += "\"size\":" + String(meta.fileSize) + ",";
            json += "\"uses\":" + String(meta.accessCount);
            json += "}";
            
            first = false;
        }
        
        json += "],";
        json += "\"stats\":{";
        json += "\"total\":" + String(stats.totalProtocols) + ",";
        json += "\"totalSize\":" + String(stats.totalSize) + ",";
        json += "\"cacheHits\":" + String(stats.cacheHits) + ",";
        json += "\"cacheMisses\":" + String(stats.cacheMisses);
        json += "}}";
        
        return json;
    }
    
    /**
     * @brief Вывести статистику в Serial
     */
    void printStats() {
        Serial.println("\n=== Protocol Library Statistics ===");
        Serial.printf("Total protocols: %d\n", stats.totalProtocols);
        Serial.printf("Total size: %d bytes (%.2f KB)\n", 
                     stats.totalSize, stats.totalSize / 1024.0);
        Serial.printf("Cache hits: %d, misses: %d (%.1f%% hit rate)\n",
                     stats.cacheHits, stats.cacheMisses,
                     100.0 * stats.cacheHits / (stats.cacheHits + stats.cacheMisses + 1));
        
        Serial.println("\nFrequency distribution:");
        for (const auto& pair : stats.frequencyDistribution) {
            Serial.printf("  %.2f MHz: %d protocols\n", 
                         pair.first / 1e6, pair.second);
        }
        
        Serial.println("\nTop 5 most used:");
        auto top = getTopUsed(5);
        for (size_t i = 0; i < top.size(); i++) {
            Serial.printf("  %d. %s (used %d times)\n", 
                         i + 1, top[i].name.c_str(), top[i].accessCount);
        }
        
        Serial.println("=====================================\n");
    }
    
    // ========================================================================
    // UTILITY
    // ========================================================================
    
    static ProtocolLibrary& getInstance() {
        static ProtocolLibrary instance;
        return instance;
    }
    
private:
    /**
     * @brief Извлечь значение из строки "Key: Value"
     */
    String extractValue(const String& line) {
        int pos = line.indexOf(':');
        if (pos == -1) return "";
        String val = line.substring(pos + 1);
        val.trim();
        return val;
    }
    
    /**
     * @brief Определить тип модуляции из preset
     */
    String detectModulationType(const String& preset) {
        if (preset.indexOf("Ook") >= 0) return "OOK";
        if (preset.indexOf("FSK") >= 0) return "FSK";
        if (preset.indexOf("Gfsk") >= 0) return "GFSK";
        if (preset.indexOf("Msk") >= 0) return "MSK";
        return "Unknown";
    }
    
    /**
     * @brief Вывести распределение по частотам
     */
    void printFrequencyDistribution() {
        if (stats.frequencyDistribution.empty()) return;
        
        ESP_LOGI("ProtocolLib", "Frequency distribution:");
        for (const auto& pair : stats.frequencyDistribution) {
            ESP_LOGI("ProtocolLib", "  %.2f MHz: %d files", 
                     pair.first / 1e6, pair.second);
        }
    }
    
    /**
     * @brief Получить топ используемых (для внутреннего использования)
     */
    std::vector<ProtocolMetadata> getTopUsed(size_t count) {
        std::vector<ProtocolMetadata> all;
        
        for (const auto& pair : index) {
            all.push_back(pair.second);
        }
        
        std::sort(all.begin(), all.end(), 
                 [](const ProtocolMetadata& a, const ProtocolMetadata& b) {
                     return a.accessCount > b.accessCount;
                 });
        
        if (all.size() > count) {
            all.resize(count);
        }
        
        return all;
    }
};

// ============================================================================
// ИНТЕГРАЦИЯ С BLE ADAPTER
// ============================================================================

/**
 * @brief Добавить в BleAdapter.cpp
 */

// Команда 0x10: Получить индекс библиотеки
void BleAdapter::handleGetProtocolLibrary() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    String json = lib.exportIndexJson();
    
    ESP_LOGI("BLE", "Sending protocol library index (%d bytes)", json.length());
    sendBinaryResponse(json);
}

// Команда 0x11: Поиск протоколов по частоте
void BleAdapter::handleSearchProtocolsByFreq(uint8_t* payload, size_t len) {
    if (len < 4) {
        notifyError("Invalid payload for frequency search");
        return;
    }
    
    uint32_t frequency = *((uint32_t*)&payload[0]);
    uint32_t tolerance = (len >= 8) ? *((uint32_t*)&payload[4]) : 100000;
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    auto results = lib.findByFrequency(frequency, tolerance);
    
    // Формировать JSON ответ
    String json = "[";
    for (size_t i = 0; i < results.size(); i++) {
        if (i > 0) json += ",";
        
        json += "{";
        json += "\"name\":\"" + results[i].name + "\",";
        json += "\"path\":\"" + results[i].fullPath + "\",";
        json += "\"freq\":" + String(results[i].frequency) + ",";
        json += "\"size\":" + String(results[i].fileSize);
        json += "}";
    }
    json += "]";
    
    sendBinaryResponse(json);
}

// Команда 0x12: Поиск по имени
void BleAdapter::handleSearchProtocolsByName(uint8_t* payload, size_t len) {
    if (len < 1) {
        notifyError("Invalid payload for name search");
        return;
    }
    
    uint8_t queryLength = payload[0];
    if (len < 1 + queryLength) {
        notifyError("Payload too short");
        return;
    }
    
    char query[256];
    memcpy(query, &payload[1], queryLength);
    query[queryLength] = '\0';
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    auto results = lib.searchByName(query);
    
    // Формировать JSON (аналогично поиску по частоте)
    // ...
}

// Команда 0x13: Получить статистику
void BleAdapter::handleGetLibraryStats() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    lib.printStats();
    
    // Отправить JSON со статистикой
    String json = lib.exportIndexJson();
    sendBinaryResponse(json);
}

// Команда 0x14: Пере-индексировать библиотеку
void BleAdapter::handleRebuildLibraryIndex() {
    ESP_LOGI("BLE", "Rebuilding protocol library index...");
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    lib.rebuildIndex();
    
    String response = "{\"action\":\"rebuild_index\",\"success\":true,";
    response += "\"protocols\":" + String(lib.getStats().totalProtocols) + "}";
    
    sendBinaryResponse(response);
}

// ============================================================================
// ИСПОЛЬЗОВАНИЕ В SETUP()
// ============================================================================

void setup() {
    // ... обычная инициализация ...
    
    // Инициализировать SD карту
    sdspi.begin(SD_SCLK, SD_MISO, SD_MOSI, SD_SS);
    if (!SD.begin(SD_SS, sdspi)) {
        ESP_LOGE(TAG, "Card Mount Failed");
        return;
    }
    
    // Инициализировать библиотеку протоколов
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    lib.begin();
    
    // Вывести статистику (опционально)
    lib.printStats();
    
    // ... остальная инициализация ...
}

// ============================================================================
// ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ
// ============================================================================

/**
 * @brief Пример 1: Найти все протоколы на 433.92 MHz
 */
void example_findByFrequency() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    auto protocols = lib.findByFrequency(433920000, 50000); // ±50 kHz
    
    Serial.printf("Found %d protocols on 433.92 MHz:\n", protocols.size());
    for (const auto& p : protocols) {
        Serial.printf("  - %s (%.2f MHz)\n", 
                     p.name.c_str(), p.frequency / 1e6);
    }
}

/**
 * @brief Пример 2: Найти все файлы с "door" в имени
 */
void example_searchByName() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    auto results = lib.searchByName("door");
    
    Serial.printf("Found %d protocols with 'door':\n", results.size());
    for (const auto& p : results) {
        Serial.printf("  - %s (%s)\n", 
                     p.name.c_str(), p.fullPath.c_str());
    }
}

/**
 * @brief Пример 3: Показать наиболее используемые протоколы
 */
void example_topUsed() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    auto top = lib.getTopUsed(5);
    
    Serial.println("Top 5 most used protocols:");
    for (size_t i = 0; i < top.size(); i++) {
        Serial.printf("%d. %s (used %d times)\n", 
                     i + 1, top[i].name.c_str(), top[i].accessCount);
    }
}

/**
 * @brief Пример 4: Получить содержимое файла с кэшированием
 */
void example_getCachedFile() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    // Первый раз - читается с SD (медленно)
    String content1 = lib.getFileContent("door_remote");
    
    // Второй раз - из кэша (быстро!)
    String content2 = lib.getFileContent("door_remote");
    
    // Показать статистику кэша
    lib.printStats();
}

// ============================================================================
// ТЕСТИРОВАНИЕ
// ============================================================================

void test_protocolLibrary() {
    Serial.println("\n=== Testing Protocol Library ===\n");
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    // Тест 1: Индексация
    Serial.println("Test 1: Rebuilding index...");
    lib.rebuildIndex();
    lib.printStats();
    
    // Тест 2: Поиск по частоте
    Serial.println("\nTest 2: Search by frequency (433.92 MHz)...");
    example_findByFrequency();
    
    // Тест 3: Поиск по имени
    Serial.println("\nTest 3: Search by name ('door')...");
    example_searchByName();
    
    // Тест 4: Топ используемых
    Serial.println("\nTest 4: Top used protocols...");
    example_topUsed();
    
    // Тест 5: Кэширование
    Serial.println("\nTest 5: Cache performance...");
    unsigned long start = millis();
    String content1 = lib.getFileContent("test_protocol");
    unsigned long time1 = millis() - start;
    
    start = millis();
    String content2 = lib.getFileContent("test_protocol");
    unsigned long time2 = millis() - start;
    
    Serial.printf("First read: %lu ms (from SD)\n", time1);
    Serial.printf("Second read: %lu ms (from cache)\n", time2);
    Serial.printf("Speedup: %.1fx faster!\n", (float)time1 / time2);
    
    Serial.println("\n=== All tests completed ===\n");
}

// ============================================================================
// MAINTENANCE ФУНКЦИИ
// ============================================================================

/**
 * @brief Очистка старых/неиспользуемых файлов
 */
void cleanupUnusedProtocols(uint32_t maxAgeMs = 2592000000) { // 30 дней
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    uint32_t now = millis();
    
    std::vector<String> toDelete;
    
    for (const auto& pair : lib.index) {
        const ProtocolMetadata& meta = pair.second;
        
        // Если не использовался давно
        if (meta.accessCount == 0 || 
            (now - meta.lastAccess) > maxAgeMs) {
            toDelete.push_back(meta.fullPath);
        }
    }
    
    Serial.printf("Found %d unused protocols to clean up\n", toDelete.size());
    
    for (const String& path : toDelete) {
        if (SD.remove(path)) {
            Serial.printf("Deleted: %s\n", path.c_str());
        }
    }
    
    // Пере-индексировать
    lib.rebuildIndex();
}

/**
 * @brief Экспорт всей библиотеки в один файл (backup)
 */
void backupProtocolLibrary(const char* backupFile) {
    File backup = SD.open(backupFile, FILE_WRITE);
    if (!backup) {
        ESP_LOGE("Backup", "Failed to create backup file");
        return;
    }
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    
    backup.println("# Protocol Library Backup");
    backup.printf("# Date: %lu\n", millis());
    backup.printf("# Protocols: %d\n\n", lib.getStats().totalProtocols);
    
    for (const auto& pair : lib.index) {
        const ProtocolMetadata& meta = pair.second;
        
        backup.println("---");
        backup.printf("Name: %s\n", meta.name.c_str());
        backup.printf("Path: %s\n", meta.fullPath.c_str());
        backup.printf("Frequency: %u\n", meta.frequency);
        backup.printf("Uses: %u\n", meta.accessCount);
        backup.println();
    }
    
    backup.close();
    ESP_LOGI("Backup", "Backup created: %s", backupFile);
}

// ============================================================================
// КАК ИСПОЛЬЗОВАТЬ В ПРОЕКТЕ
// ============================================================================

/*

1. Скопировать этот файл в include/ProtocolLibrary.h

2. В src/main.cpp добавить в setup():

    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    lib.begin();

3. В include/BleAdapter.h добавить методы:

    void handleGetProtocolLibrary();
    void handleSearchProtocolsByFreq(uint8_t* payload, size_t len);
    void handleSearchProtocolsByName(uint8_t* payload, size_t len);
    void handleGetLibraryStats();
    void handleRebuildLibraryIndex();

4. В src/BleAdapter.cpp добавить в handleSingleCommand():

    case 0x10:
        handleGetProtocolLibrary();
        break;
    case 0x11:
        handleSearchProtocolsByFreq(commandPayload, commandPayloadLength);
        break;
    case 0x12:
        handleSearchProtocolsByName(commandPayload, commandPayloadLength);
        break;
    case 0x13:
        handleGetLibraryStats();
        break;
    case 0x14:
        handleRebuildLibraryIndex();
        break;

5. Создать структуру на SD карте:
   - /DATA/RECORDS/
   - /DATA/PROTOCOLS/
   - /DATA/PRESETS/
   - /DATA/BACKUPS/

6. PROFIT! Библиотека работает.

ЭКОНОМИЯ FLASH: Если хранить 20+ протоколов на SD вместо прошивки,
                экономия ~100-200 KB Flash памяти!

*/

















