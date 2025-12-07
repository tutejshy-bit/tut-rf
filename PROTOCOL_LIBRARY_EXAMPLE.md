# 📚 Примеры создания библиотеки протоколов на SD карте

## 🎯 Идея: Загружаемые протоколы

Вместо того чтобы все протоколы хранить в Flash прошивки (экономия ~100-200 KB!), можно загружать их динамически с SD карты.

---

## 📁 Предлагаемая структура на SD карте

```
SD:/
├── DATA/
│   ├── RECORDS/              # Пользовательские записи
│   │   ├── door_1.sub
│   │   ├── garage.sub
│   │   └── ...
│   │
│   ├── PROTOCOLS/            # Библиотека протоколов (НОВОЕ!)
│   │   ├── princeton.json    # Описание протокола
│   │   ├── keeloq.json
│   │   ├── came.json
│   │   └── custom/
│   │       ├── my_protocol.json
│   │       └── experimental.json
│   │
│   └── PRESETS/              # Предустановки CC1101 (НОВОЕ!)
│       ├── ook_270.preset
│       ├── ook_650.preset
│       ├── fsk_238.preset
│       └── custom_315mhz.preset
```

---

## 📄 Формат файла протокола (JSON)

### Пример: princeton.json

```json
{
  "name": "Princeton",
  "description": "PT2260/PT2262 protocol",
  "version": "1.0",
  "author": "Community",
  
  "encoding": {
    "type": "pulse_width",
    "short_pulse": 350,
    "long_pulse": 1050,
    "sync_pulse": 11000,
    "gap": 31
  },
  
  "parameters": {
    "bit_count": 24,
    "repeat": 5,
    "guard_time_multiplier": 30
  },
  
  "frequencies": [315000000, 433920000],
  
  "modulation": {
    "type": "OOK",
    "bandwidth": 270,
    "deviation": 0
  }
}
```

### Пример: keeloq.json (расширенный протокол)

```json
{
  "name": "KeeLoq",
  "description": "KeeLoq rolling code protocol",
  "version": "1.0",
  "author": "Community",
  
  "encoding": {
    "type": "manchester",
    "bit_time": 400,
    "preamble_length": 12,
    "sync_pattern": "0xA5"
  },
  
  "parameters": {
    "bit_count": 66,
    "repeat": 3,
    "encryption": "keeloq",
    "manufacturer_code": "0x0000"
  },
  
  "frequencies": [433920000],
  
  "modulation": {
    "type": "OOK",
    "bandwidth": 270,
    "deviation": 0
  },
  
  "features": {
    "rolling_code": true,
    "counter": true,
    "button_mapping": {
      "1": "Lock",
      "2": "Unlock",
      "3": "Trunk",
      "4": "Panic"
    }
  }
}
```

---

## 💾 Формат файла preset

### Пример: custom_315mhz.preset

```
# CC1101 Preset Configuration
# Frequency: 315 MHz
# Modulation: OOK
# Bandwidth: 270 kHz

[PRESET]
Name=Custom 315MHz OOK
Frequency=315000000
Modulation=OOK

[REGISTERS]
# Register: Value (HEX)
MDMCFG4=0xCA
MDMCFG3=0x83
MDMCFG2=0x30
DEVIATN=0x00
FREND0=0x11

[PATABLE]
# Power amplifier table
C0 00 00 00 00 00 00 00
```

---

## 💻 Код: Динамическая загрузка протоколов

### Новый класс: ProtocolLoader

**Файл**: `include/ProtocolLoader.h`

```cpp
#ifndef ProtocolLoader_h
#define ProtocolLoader_h

#include <Arduino.h>
#include <SD.h>
#include <ArduinoJson.h>
#include <map>
#include <memory>

// Структура описания протокола
struct ProtocolDescriptor {
    String name;
    String description;
    String encodingType;
    uint16_t shortPulse;
    uint16_t longPulse;
    uint16_t syncPulse;
    uint8_t bitCount;
    uint8_t repeat;
    uint32_t frequency;
};

class ProtocolLoader {
private:
    std::map<String, ProtocolDescriptor> loadedProtocols;
    
public:
    // Загрузить протокол с SD карты
    bool loadProtocol(const String& protocolName) {
        String path = "/DATA/PROTOCOLS/" + protocolName + ".json";
        
        File file = SD.open(path);
        if (!file) {
            ESP_LOGE("ProtocolLoader", "Failed to open: %s", path.c_str());
            return false;
        }
        
        // Парсить JSON
        StaticJsonDocument<1024> doc;
        DeserializationError error = deserializeJson(doc, file);
        file.close();
        
        if (error) {
            ESP_LOGE("ProtocolLoader", "JSON parse error: %s", error.c_str());
            return false;
        }
        
        // Заполнить дескриптор
        ProtocolDescriptor descriptor;
        descriptor.name = doc["name"].as<String>();
        descriptor.description = doc["description"].as<String>();
        descriptor.encodingType = doc["encoding"]["type"].as<String>();
        descriptor.shortPulse = doc["encoding"]["short_pulse"];
        descriptor.longPulse = doc["encoding"]["long_pulse"];
        descriptor.syncPulse = doc["encoding"]["sync_pulse"];
        descriptor.bitCount = doc["parameters"]["bit_count"];
        descriptor.repeat = doc["parameters"]["repeat"];
        descriptor.frequency = doc["frequencies"][0];
        
        // Сохранить в map
        loadedProtocols[protocolName] = descriptor;
        
        ESP_LOGI("ProtocolLoader", "Loaded protocol: %s", protocolName.c_str());
        return true;
    }
    
    // Получить протокол
    bool getProtocol(const String& name, ProtocolDescriptor& out) {
        auto it = loadedProtocols.find(name);
        if (it != loadedProtocols.end()) {
            out = it->second;
            return true;
        }
        return false;
    }
    
    // Загрузить все протоколы при старте
    void loadAllProtocols() {
        File dir = SD.open("/DATA/PROTOCOLS");
        if (!dir || !dir.isDirectory()) {
            ESP_LOGW("ProtocolLoader", "Protocols directory not found");
            return;
        }
        
        File entry;
        while (entry = dir.openNextFile()) {
            String filename = entry.name();
            if (filename.endsWith(".json")) {
                String protocolName = filename.substring(0, filename.lastIndexOf('.'));
                loadProtocol(protocolName);
            }
            entry.close();
        }
        dir.close();
        
        ESP_LOGI("ProtocolLoader", "Loaded %d protocols", loadedProtocols.size());
    }
    
    // Получить список доступных протоколов
    std::vector<String> getAvailableProtocols() {
        std::vector<String> protocols;
        for (const auto& pair : loadedProtocols) {
            protocols.push_back(pair.first);
        }
        return protocols;
    }
    
    static ProtocolLoader& getInstance() {
        static ProtocolLoader instance;
        return instance;
    }
};

#endif // ProtocolLoader_h
```

---

## 🚀 Пример использования

### В setup():

```cpp
void setup() {
    // ... обычная инициализация ...
    
    // Загрузить протоколы с SD карты
    ProtocolLoader& loader = ProtocolLoader::getInstance();
    loader.loadAllProtocols();
    
    // Вывести список
    auto protocols = loader.getAvailableProtocols();
    ESP_LOGI("Setup", "Available protocols:");
    for (const auto& p : protocols) {
        ESP_LOGI("Setup", "  - %s", p.c_str());
    }
}
```

### При передаче:

```cpp
bool transmitWithLoadedProtocol(const String& protocolName, 
                               uint64_t key, 
                               int module) {
    ProtocolLoader& loader = ProtocolLoader::getInstance();
    ProtocolDescriptor protocol;
    
    if (!loader.getProtocol(protocolName, protocol)) {
        ESP_LOGE("Transmit", "Protocol not found: %s", protocolName.c_str());
        return false;
    }
    
    // Использовать параметры из протокола
    float frequency = protocol.frequency / 1000000.0;
    
    // Настроить CC1101
    moduleCC1101State[module].setTx(frequency);
    
    // Генерировать сигнал используя параметры протокола
    std::vector<int> pulses = generatePulses(protocol, key);
    
    // Передать
    transmitRawData(pulses, module);
    
    return true;
}
```

---

## 🎨 Визуализация процесса

### Запись сигнала:

```
1. Пользователь → BLE → ESP32
   "Записать сигнал на 433.92 MHz"

2. ESP32 → CC1101 Module
   Настроить прием, частота = 433.92 MHz

3. Пользователь нажимает кнопку на пульте
   Пульт → CC1101 → ESP32
   
4. ESP32 (ISR) → Буфер
   Сохранить импульсы: [500, -200, 300, -400, ...]

5. ESP32 → SD Card
   Записать в файл: "door_remote.sub"
   
6. ESP32 → BLE → Мобильное приложение
   "Файл сохранен: door_remote.sub"
```

### Передача сигнала:

```
1. Пользователь → Мобильное приложение
   Выбрать файл: "door_remote.sub"
   
2. Приложение → BLE → ESP32
   Command: transmitFromFile("door_remote.sub")

3. ESP32 → SD Card
   Читать файл → Парсить → Получить данные

4. ESP32 → CC1101 Module
   Настроить: frequency, modulation, preset
   
5. ESP32 → CC1101 Module
   Передать импульсы: [500, -200, 300, -400, ...]
   
6. CC1101 → Антенна → Устройство
   Сигнал передан!

7. ESP32 → BLE → Приложение
   "Сигнал передан успешно"
```

---

## 🛠️ Инструменты для работы с .sub файлами

### 1. Просмотр на ПК

```python
# tools/view_sub_file.py

import sys

def parse_sub_file(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    print(f"📄 File: {filename}")
    print("=" * 50)
    
    for line in lines:
        line = line.strip()
        if line.startswith("Filetype:"):
            print(f"📋 Type: {line.split(':')[1].strip()}")
        elif line.startswith("Frequency:"):
            freq = int(line.split(':')[1].strip())
            print(f"📡 Frequency: {freq/1e6:.2f} MHz")
        elif line.startswith("Preset:"):
            print(f"⚙️  Preset: {line.split(':')[1].strip()}")
        elif line.startswith("Protocol:"):
            print(f"🔧 Protocol: {line.split(':')[1].strip()}")
        elif line.startswith("RAW_Data:"):
            data = line.split(':')[1].strip()
            samples = data.split()
            print(f"📊 Samples: {len(samples)} pulses")
            print(f"   First 10: {' '.join(samples[:10])}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python view_sub_file.py <file.sub>")
        sys.exit(1)
    
    parse_sub_file(sys.argv[1])
```

**Использование**:
```bash
python tools/view_sub_file.py door_remote.sub

# Вывод:
# 📄 File: door_remote.sub
# ==================================================
# 📋 Type: Flipper SubGhz RAW File
# 📡 Frequency: 433.92 MHz
# ⚙️  Preset: FuriHalSubGhzPresetOok270Async
# 🔧 Protocol: RAW
# 📊 Samples: 248 pulses
#    First 10: 520 -180 310 -390 520 -180 310 -390 520 -180
```

---

### 2. Конвертер между форматами

```python
# tools/convert_sub_format.py

def sub_to_csv(sub_file, csv_file):
    """Конвертировать .sub в CSV для анализа в Excel"""
    with open(sub_file, 'r') as f:
        lines = f.readlines()
    
    # Найти RAW_Data
    raw_data = []
    for line in lines:
        if line.startswith("RAW_Data:"):
            data = line.split(':')[1].strip()
            raw_data.extend(data.split())
    
    # Записать в CSV
    with open(csv_file, 'w') as f:
        f.write("Index,Duration,Level\n")
        for i, duration in enumerate(raw_data):
            level = "HIGH" if i % 2 == 0 else "LOW"
            f.write(f"{i},{duration},{level}\n")
    
    print(f"✅ Converted {len(raw_data)} samples to {csv_file}")

def csv_to_sub(csv_file, sub_file, frequency=433920000, preset="Ook270"):
    """Конвертировать CSV обратно в .sub"""
    import csv
    
    samples = []
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            duration = int(row['Duration'])
            level = row['Level']
            if level == "LOW":
                duration = -duration
            samples.append(str(duration))
    
    # Создать .sub файл
    with open(sub_file, 'w') as f:
        f.write("Filetype: Flipper SubGhz RAW File\n")
        f.write("Version: 1\n")
        f.write(f"Frequency: {frequency}\n")
        f.write(f"Preset: FuriHalSubGhzPreset{preset}Async\n")
        f.write("Protocol: RAW\n")
        f.write("RAW_Data: ")
        f.write(' '.join(samples))
        f.write("\n")
    
    print(f"✅ Created {sub_file} with {len(samples)} samples")
```

---

## 🔧 Расширенный функционал для ESP32

### Идея: Менеджер библиотеки протоколов

**Новый файл**: `include/ProtocolLibrary.h`

```cpp
#ifndef ProtocolLibrary_h
#define ProtocolLibrary_h

#include <Arduino.h>
#include <SD.h>
#include <vector>
#include <map>

/**
 * @brief Менеджер библиотеки протоколов на SD карте
 * 
 * Позволяет:
 * - Загружать протоколы динамически
 * - Кэшировать часто используемые
 * - Экономить Flash память
 */
class ProtocolLibrary {
public:
    struct ProtocolInfo {
        String name;
        String description;
        String path;
        uint32_t frequency;
        String modulation;
        uint32_t fileSize;
        bool cached;
    };
    
    /**
     * @brief Сканировать SD карту и индексировать все .sub файлы
     */
    void indexProtocols() {
        protocolIndex.clear();
        scanDirectory("/DATA/RECORDS");
        scanDirectory("/DATA/PROTOCOLS");
        
        ESP_LOGI("ProtocolLib", "Indexed %d protocols", protocolIndex.size());
    }
    
    /**
     * @brief Получить список всех протоколов
     */
    std::vector<ProtocolInfo> getProtocolList() {
        std::vector<ProtocolInfo> list;
        for (const auto& pair : protocolIndex) {
            list.push_back(pair.second);
        }
        return list;
    }
    
    /**
     * @brief Найти протоколы по частоте
     */
    std::vector<ProtocolInfo> findByFrequency(uint32_t frequency, 
                                              uint32_t tolerance = 50000) {
        std::vector<ProtocolInfo> results;
        
        for (const auto& pair : protocolIndex) {
            uint32_t diff = abs((int32_t)(pair.second.frequency - frequency));
            if (diff <= tolerance) {
                results.push_back(pair.second);
            }
        }
        
        return results;
    }
    
    /**
     * @brief Найти протоколы по имени (частичное совпадение)
     */
    std::vector<ProtocolInfo> searchByName(const String& query) {
        std::vector<ProtocolInfo> results;
        
        String lowerQuery = query;
        lowerQuery.toLowerCase();
        
        for (const auto& pair : protocolIndex) {
            String lowerName = pair.second.name;
            lowerName.toLowerCase();
            
            if (lowerName.indexOf(lowerQuery) >= 0) {
                results.push_back(pair.second);
            }
        }
        
        return results;
    }
    
    /**
     * @brief Экспорт библиотеки в JSON
     */
    String exportLibraryJson() {
        String json = "[";
        bool first = true;
        
        for (const auto& pair : protocolIndex) {
            if (!first) json += ",";
            
            const ProtocolInfo& info = pair.second;
            json += "{";
            json += "\"name\":\"" + info.name + "\",";
            json += "\"description\":\"" + info.description + "\",";
            json += "\"frequency\":" + String(info.frequency) + ",";
            json += "\"modulation\":\"" + info.modulation + "\",";
            json += "\"path\":\"" + info.path + "\"";
            json += "}";
            
            first = false;
        }
        json += "]";
        
        return json;
    }
    
    static ProtocolLibrary& getInstance() {
        static ProtocolLibrary instance;
        return instance;
    }
    
private:
    std::map<String, ProtocolInfo> protocolIndex;
    
    void scanDirectory(const String& path) {
        File dir = SD.open(path);
        if (!dir || !dir.isDirectory()) {
            return;
        }
        
        File entry;
        while (entry = dir.openNextFile()) {
            String filename = entry.name();
            
            if (entry.isDirectory()) {
                // Рекурсивно сканировать подпапки
                scanDirectory(filename);
            } else if (filename.endsWith(".sub")) {
                // Индексировать .sub файл
                indexSubFile(entry);
            }
            
            entry.close();
        }
        dir.close();
    }
    
    void indexSubFile(File& file) {
        ProtocolInfo info;
        info.path = file.name();
        info.fileSize = file.size();
        info.cached = false;
        
        // Быстро прочитать метаданные (только первые строки)
        file.seek(0);
        for (int i = 0; i < 10 && file.available(); i++) {
            String line = file.readStringUntil('\n');
            line.trim();
            
            if (line.startsWith("Frequency:")) {
                info.frequency = parseValue(line).toInt();
            } else if (line.startsWith("Preset:")) {
                String preset = parseValue(line);
                if (preset.indexOf("Ook") >= 0) {
                    info.modulation = "OOK";
                } else if (preset.indexOf("FSK") >= 0) {
                    info.modulation = "FSK";
                }
            } else if (line.startsWith("Protocol:")) {
                info.description = parseValue(line);
            }
        }
        
        // Имя из пути файла
        int lastSlash = info.path.lastIndexOf('/');
        info.name = info.path.substring(lastSlash + 1);
        info.name.remove(info.name.lastIndexOf('.')); // Убрать .sub
        
        // Добавить в индекс
        protocolIndex[info.name] = info;
    }
    
    String parseValue(const String &line) {
        int pos = line.indexOf(':');
        if (pos == -1) return "";
        String val = line.substring(pos + 1);
        val.trim();
        return val;
    }
};

#endif // ProtocolLibrary_h
```

---

## 📱 Интеграция с мобильным приложением

### Новые BLE команды:

```cpp
// 1. Получить библиотеку протоколов
case 0x10:  // getProtocolLibrary
    handleGetProtocolLibrary();
    break;

void BleAdapter::handleGetProtocolLibrary() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    String json = lib.exportLibraryJson();
    sendBinaryResponse(json);
}

// 2. Поиск протоколов по частоте
case 0x11:  // searchProtocolsByFreq
    handleSearchProtocols(commandPayload, commandPayloadLength);
    break;

void BleAdapter::handleSearchProtocols(uint8_t* payload, size_t len) {
    if (len < 4) return;
    
    uint32_t frequency = *((uint32_t*)&payload[0]);
    
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    auto results = lib.findByFrequency(frequency);
    
    // Отправить результаты
    String json = "[";
    for (size_t i = 0; i < results.size(); i++) {
        if (i > 0) json += ",";
        json += "{\"name\":\"" + results[i].name + "\",";
        json += "\"path\":\"" + results[i].path + "\"}";
    }
    json += "]";
    
    sendBinaryResponse(json);
}

// 3. Передать по имени протокола
case 0x12:  // transmitByProtocolName
    handleTransmitByName(commandPayload, commandPayloadLength);
    break;
```

---

## 🎯 Преимущества подхода с SD картой

### ✅ Экономия Flash памяти

| Вариант | Flash используется | Flash свободно |
|---------|-------------------|----------------|
| **Все в прошивке** | 1,550 KB (98.8%) | 19 KB (1.2%) |
| **Протоколы на SD** | 1,250 KB (79.5%) | 319 KB (20.5%) |

**Экономия**: ~300 KB! Можно добавить множество новых функций.

---

### ✅ Гибкость

- Добавлять новые протоколы без перепрошивки
- Обновлять существующие протоколы
- Делиться протоколами между устройствами (просто скопировать файл)
- Создавать коллекции сигналов

---

### ✅ Совместимость

- Полная совместимость с Flipper Zero
- Можно обмениваться файлами
- Можно использовать готовые базы сигналов из интернета

---

## 📊 Примеры реальных файлов

### Пульт от гаражных ворот (433.92 MHz, Princeton)

```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok270Async
Protocol: Princeton
Bit: 24
Key: 00 00 00 00 00 12 34 56
TE: 350
Repeat: 5
```

### Брелок от машины (315 MHz, Custom)

```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 315000000
Preset: FuriHalSubGhzPresetCustom
Custom_preset_module: CC1101
Custom_preset_data: 02 0D 07 04 0E 90 ...
Protocol: RAW
RAW_Data: 9000 -4500 600 -600 600 -1800 600 -600 ...
```

### Датчик температуры (433.92 MHz, Oregon Scientific)

```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok650Async
Protocol: Oregon2
Sensor_ID: 0x1D20
Channel: 1
Temperature: 23.5
Humidity: 45
Battery: OK
```

---

## 🔬 Отладка и тестирование

### Проверка целостности файла

```cpp
bool checkSubFileIntegrity(const char* filename) {
    File file = SD.open(filename, FILE_READ);
    if (!file) {
        ESP_LOGE("Check", "File not found: %s", filename);
        return false;
    }
    
    SubFileParser parser(file);
    bool valid = parser.parseFile();
    
    if (valid) {
        ESP_LOGI("Check", "✅ File valid: %s", filename);
        ESP_LOGI("Check", "   Frequency: %d Hz", parser.header.frequency);
        ESP_LOGI("Check", "   Protocol: %s", parser.data.protocol.c_str());
    } else {
        ESP_LOGE("Check", "❌ File corrupted: %s", filename);
    }
    
    file.close();
    return valid;
}
```

### Статистика по библиотеке

```cpp
void printLibraryStats() {
    ProtocolLibrary& lib = ProtocolLibrary::getInstance();
    auto protocols = lib.getProtocolList();
    
    // Подсчет по частотам
    std::map<uint32_t, int> freqCount;
    for (const auto& p : protocols) {
        freqCount[p.frequency]++;
    }
    
    ESP_LOGI("Stats", "=== Protocol Library Statistics ===");
    ESP_LOGI("Stats", "Total protocols: %d", protocols.size());
    ESP_LOGI("Stats", "Frequencies:");
    for (const auto& pair : freqCount) {
        ESP_LOGI("Stats", "  %.2f MHz: %d protocols", 
                 pair.first / 1e6, pair.second);
    }
    
    // Общий размер
    uint32_t totalSize = 0;
    for (const auto& p : protocols) {
        totalSize += p.fileSize;
    }
    ESP_LOGI("Stats", "Total size: %d bytes (%.2f KB)", 
             totalSize, totalSize / 1024.0);
}
```

---

## 💡 Идеи для улучшения

### 1. Теги для организации

```
# В начале .sub файла добавить метаданные:

Filetype: Flipper SubGhz RAW File
Version: 1
# Tags: home, door, main_entrance
# Description: Front door remote control
# Date_Created: 2024-01-15
# Date_Modified: 2024-01-20
Frequency: 433920000
...
```

### 2. Избранное (Favorites)

```cpp
// Файл: /DATA/favorites.txt
door_remote.sub
garage.sub
car_key_1.sub

// Быстрый доступ через мобильное приложение
```

### 3. Автоматическое распознавание протокола

```cpp
String detectProtocol(const std::vector<int>& samples) {
    // Анализ паттернов
    if (isPrinceton(samples)) return "Princeton";
    if (isKeeLoq(samples)) return "KeeLoq";
    // ...
    return "RAW"; // Unknown
}
```

### 4. Компрессия RAW файлов

```cpp
// Вместо:
RAW_Data: 500 500 500 500 -200 -200 -200

// Использовать:
RAW_Data_RLE: 500x4 -200x3  // Run-Length Encoding
// Экономия: до 50% размера файла
```

---

## 🎓 Заключение

Работа с протоколами через SD карту - ключевая особенность проекта:

✅ **Гибкость** - неограниченное количество сигналов  
✅ **Экономия Flash** - протоколы не в прошивке  
✅ **Совместимость** - формат Flipper Zero  
✅ **Удобство** - редактирование на ПК  
✅ **Масштабируемость** - легко добавлять новые протоколы  

---

**Следующие шаги**:
1. Индексирование протоколов при старте
2. Поиск по частоте/имени
3. Кэширование часто используемых
4. Веб-интерфейс для управления библиотекой

---

**Связанные файлы**:
- `lib/generators/FlipperSubFile.cpp` - Генерация
- `include/SubFileParser.h` - Парсинг
- `src/Recorder.cpp` - Запись
- `src/Transmitter.cpp` - Передача

**Версия**: 1.0  
**Дата**: 2025-10-08

















