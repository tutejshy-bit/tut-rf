# 📡 Работа с SubGhz протоколами через SD карту

## 🎯 Концепция

ESP32 CC1101 использует SD карту для хранения сигналов в формате **Flipper Zero .sub файлов**. Это позволяет:
- Записывать перехваченные сигналы
- Хранить библиотеку сигналов
- Передавать сохраненные сигналы
- Обмениваться файлами между устройствами

---

## 📁 Структура файлов на SD карте

```
SD:/
└── DATA/
    └── RECORDS/
        ├── door_remote.sub        # Пульт от двери
        ├── garage_433.sub         # Гаражные ворота
        ├── car_key_1.sub          # Ключ от машины #1
        ├── car_key_2.sub          # Ключ от машины #2
        ├── protocols/
        │   ├── princeton_test.sub
        │   ├── raw_315mhz.sub
        │   └── custom_signal.sub
        └── backups/
            ├── backup_2024_01.sub
            └── backup_2024_02.sub
```

**Определение в коде**:
```cpp
// include/config.h
#define FILES_RECORDS_PATH "/DATA/RECORDS"
```

---

## 📄 Формат .sub файла

### Пример 1: RAW Protocol (записанный сигнал)

**Файл**: `door_remote.sub`
```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok270Async
Protocol: RAW
RAW_Data: 500 -200 300 -400 500 -200 300 -400 500 -200 300 -400 500 -200 ...
RAW_Data: 300 -400 500 -200 300 -400 500 -200 300 -400 500 -200 300 -400 ...
```

**Объяснение**:
- `Filetype`: Идентификатор формата
- `Version`: Версия формата (1)
- `Frequency`: Частота в Hz (433.92 MHz)
- `Preset`: Предустановка модуляции
- `Protocol`: Тип протокола (RAW = сырые данные)
- `RAW_Data`: Данные импульсов (положительные = HIGH, отрицательные = LOW, в микросекундах)

---

### Пример 2: Princeton Protocol (декодированный)

**Файл**: `garage_433.sub`
```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok270Async
Protocol: Princeton
Bit: 24
Key: 00 00 00 00 00 D1 E5 94
TE: 400
Repeat: 5
```

**Объяснение**:
- `Bit`: Количество бит в ключе (24 бита)
- `Key`: Декодированный ключ в HEX
- `TE`: Time Element - базовая длительность импульса (400 мкс)
- `Repeat`: Количество повторов передачи

---

### Пример 3: Custom Preset (кастомные настройки CC1101)

**Файл**: `custom_signal.sub`
```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 315000000
Preset: FuriHalSubGhzPresetCustom
Custom_preset_module: CC1101
Custom_preset_data: 02 0D 03 07 08 32 0B 06 14 00 13 00 12 30 11 32 10 17 18 18 19 18 1D 91 1C 00 1B 07 20 FB 22 11 21 B6 00 00 00 C0 00 00 00 00 00 00
Protocol: RAW
RAW_Data: 1000 -500 750 -250 1000 -500 750 -250 1000 -500 ...
```

**Объяснение**:
- `Custom_preset_data`: Прямые регистры CC1101 в HEX формате
- Позволяет точно настроить модуляцию, bandwidth, deviation и т.д.

---

## 💻 Код: Запись сигнала на SD карту

### Функция записи (из Recorder.cpp)

```cpp
// src/Recorder.cpp - функция process()

void Recorder::process(int module)
{
    // 1. Запустить прием сигнала
    Recorder::start(module);
    
    while (true) {
        // Проверка на команду остановки
        if (ulTaskNotifyTake(pdTRUE, 0) == 1) {
            break;
        }
        
        // 2. Получить сэмплы из прерываний
        std::vector<unsigned long> samplesCopy;
        unsigned long lastReceiveTime;
        
        // Копирование в critical section
        portENTER_CRITICAL(&Recorder::muxes[module]);
        ReceivedSamples &data = getReceivedData(module);
        // ... копирование сэмплов ...
        portEXIT_CRITICAL(&Recorder::muxes[module]);
        
        size_t samplecount = samplesCopy.size();
        
        // 3. Проверка: достаточно ли сэмплов и закончился ли сигнал
        if (samplecount >= MIN_SAMPLE && 
            micros() - lastReceiveTime > MAX_SIGNAL_DURATION) {
            
            // 4. Генерация имени файла
            RecordConfig& config = recorder.recordConfig[module];
            std::string filename = Recorder::generateFilename(
                module, 
                config.frequency, 
                config.modulation, 
                config.rxBandwidth
            );
            // Пример: "m0_43392_AM_270_abc123.sub"
            
            // 5. Конвертация сэмплов в строку RAW_Data
            std::stringstream rawSignal;
            for (size_t i = 0; i < samplecount; i++) {
                rawSignal << (i > 0 ? (i % 2 == 1 ? " -" : " ") : "");
                rawSignal << samplesCopy[i];
            }
            // Результат: "500 -200 300 -400 500 -200 ..."
            
            // 6. Открыть файл на SD карте
            std::string fullPath = "/DATA/RECORDS/" + filename;
            File outputFile = SD.open(fullPath.c_str(), FILE_WRITE);
            
            if (outputFile) {
                // 7. Записать .sub файл
                const std::string preset = config.preset;
                std::vector<byte> customPresetData;
                
                if (preset == "Custom") {
                    // Получить текущие регистры CC1101
                    ModuleCc1101& m = moduleCC1101State[module];
                    customPresetData.insert(customPresetData.end(), {
                        CC1101_MDMCFG4, m.getRegisterValue(CC1101_MDMCFG4),
                        CC1101_MDMCFG3, m.getRegisterValue(CC1101_MDMCFG3),
                        // ... другие регистры
                    });
                }
                
                // 8. Генерация файла через FlipperSubFile
                FlipperSubFile::generateRaw(
                    outputFile,      // File handle
                    preset,          // Preset name
                    customPresetData, // Custom data
                    rawSignal,       // RAW samples
                    config.frequency // Frequency
                );
                
                outputFile.close();
                
                // 9. Уведомить клиента об успехе
                recorder.recorderCallback(true, filename);
            } else {
                recorder.recorderCallback(false, filename);
            }
            
            // 10. Очистить и продолжить запись
            recorder.clearReceivedSamples(module);
            addModuleReceiver(module);
        }
        
        vTaskDelay(pdMS_TO_TICKS(100));
    }
    
    Recorder::stop(module);
}
```

### Генератор .sub файлов

```cpp
// lib/generators/FlipperSubFile.cpp

void FlipperSubFile::generateRaw(
    File& file,
    const std::string& presetName,
    const std::vector<byte>& customPresetData,
    std::stringstream& samples,
    float frequency
) {
    // 1. Записать заголовок
    writeHeader(file, frequency);
    
    // 2. Записать preset информацию
    writePresetInfo(file, presetName, customPresetData);
    
    // 3. Записать данные протокола
    writeRawProtocolData(file, samples);
}

void FlipperSubFile::writeHeader(File& file, float frequency) {
    file.println("Filetype: Flipper SubGhz RAW File");
    file.println("Version: 1");
    file.print("Frequency: ");
    file.print(frequency * 1e6, 0); // MHz -> Hz
    file.println();
}

void FlipperSubFile::writePresetInfo(File& file, 
                                    const std::string& presetName, 
                                    const std::vector<byte>& customPresetData) {
    file.print("Preset: ");
    file.println(getPresetName(presetName).c_str());
    
    if (presetName == "Custom") {
        file.println("Custom_preset_module: CC1101");
        file.print("Custom_preset_data: ");
        for (size_t i = 0; i < customPresetData.size(); ++i) {
            char hexStr[3];
            sprintf(hexStr, "%02X", customPresetData[i]);
            file.print(hexStr);
            if (i < customPresetData.size() - 1) {
                file.print(" ");
            }
        }
        file.println();
    }
}

void FlipperSubFile::writeRawProtocolData(File& file, std::stringstream& samples) {
    file.println("Protocol: RAW");
    file.print("RAW_Data: ");
    
    std::string sample;
    int wordCount = 0;
    
    // Разбивать данные по 512 значений на строку
    while (getline(samples, sample, ' ')) {
        if (wordCount > 0 && wordCount % 512 == 0) {
            file.println();
            file.print("RAW_Data: ");
        }
        file.print(sample.c_str());
        file.print(' ');
        wordCount++;
    }
    
    file.println();
}
```

---

## 📖 Код: Чтение и парсинг .sub файла

### Парсер файлов

```cpp
// include/SubFileParser.h

class SubFileParser {
public:
    SubFileHeader header;     // Filetype, Version, Frequency
    SubFilePreset preset;     // Preset, Custom data
    SubFileData data;         // Protocol, RAW data, Key, TE, etc
    uint8_t moduleParams[128]; // CC1101 регистры
    
    SubFileParser(File file) : file(file) {
        clearMemory();
    }
    
    // Парсинг файла
    bool parseFile() {
        readFile();
        
        if (!file || data.protocol.isEmpty()) {
            return false;
        }
        
        // Создать экземпляр протокола
        protocol.reset(SubGhzProtocol::create(data.protocol.c_str()));
        
        if (!protocol) {
            return false;
        }
        
        // Парсить протокол-специфичные данные
        file.seek(0);
        bool result = protocol->parse(file);
        
        return result;
    }
    
    // Получить payload для передачи
    bool getPayload(PulsePayload &payload) const {
        if (!protocol) {
            return false;
        }
        
        const auto& pulseData = protocol->getPulseData();
        payload = PulsePayload(pulseData, protocol->getRepeatCount());
        
        return true;
    }
    
private:
    File file;
    std::unique_ptr<SubGhzProtocol> protocol;
    
    // Чтение файла построчно
    void readFile() {
        if (!file) return;
        
        while (file.available()) {
            String line = file.readStringUntil('\n');
            if (line.endsWith("\r")) {
                line.remove(line.length() - 1);
            }
            parseLine(line);
        }
        
        handlePreset();
    }
    
    // Парсинг одной строки
    void parseLine(const String &line) {
        if (line.startsWith("Filetype:")) {
            header.filetype = parseValue(line);
        } else if (line.startsWith("Version:")) {
            header.version = parseValue(line).toInt();
        } else if (line.startsWith("Frequency:")) {
            header.frequency = parseValue(line).toInt();
        } else if (line.startsWith("Preset:")) {
            preset.preset = parseValue(line);
        } else if (line.startsWith("Custom_preset_module:")) {
            preset.customPresetModule = parseValue(line);
        } else if (line.startsWith("Custom_preset_data:")) {
            preset.customPresetData = parseValue(line);
        } else if (line.startsWith("Protocol:")) {
            data.protocol = parseValue(line);
        }
    }
    
    // Обработка preset данных
    void handlePreset() {
        if (preset.preset == "FuriHalSubGhzPresetCustom") {
            // Парсить custom preset data в moduleParams
            parseCustomPresetData(preset.customPresetData);
        } else {
            // Использовать предустановку
            const uint8_t *byteArray = getByteArrayForPreset(preset.preset);
            if (byteArray != nullptr) {
                for (int i = 0; i < 44; i++) {
                    moduleParams[i] = byteArray[i];
                }
            }
        }
    }
};
```

---

## 📡 Код: Передача сигнала из файла

### Функция transmitSub

```cpp
// src/Transmitter.cpp

bool Transmitter::transmitSub(const std::string& filename, 
                              int module, 
                              int repeat)
{
    // 1. Открыть файл с SD карты
    std::string fullPath = std::string(FILES_RECORDS_PATH) + "/" + filename;
    File file = fm.open(fullPath.c_str(), FILE_READ);
    
    if (!file) {
        ESP_LOGE("Transmitter", "Failed to open file: %s", filename.c_str());
        return false;
    }
    
    // 2. Парсить файл
    SubFileParser parser(file);
    if (!parser.parseFile()) {
        ESP_LOGE("Transmitter", "Failed to parse file");
        file.close();
        return false;
    }
    file.close();
    
    // 3. Проверить что это CC1101 совместимый файл
    if (!parser.isModuleCc1101()) {
        ESP_LOGE("Transmitter", "Not a CC1101 compatible file");
        return false;
    }
    
    // 4. Получить payload для передачи
    PulsePayload payload;
    if (!parser.getPayload(payload)) {
        ESP_LOGE("Transmitter", "Failed to create payload");
        return false;
    }
    
    // 5. Настроить CC1101 модуль
    float frequency = parser.header.frequency / 1000000.0; // Hz -> MHz
    moduleCC1101State[module].setTx(frequency);
    
    // Применить регистры из файла
    moduleCC1101State[module].applySubConfiguration(
        parser.moduleParams, 
        128
    );
    
    delay(10); // Дать модулю время на инициализацию
    
    // 6. Передать сигнал
    boolean signalTransmitted = transmitData(payload, module);
    
    // 7. Очистить память и восстановить модуль
    parser.clearMemory();
    moduleCC1101State[module].restoreConfig().setSidle();
    
    return signalTransmitted;
}

// Передача RAW данных
boolean Transmitter::transmitData(const PulsePayload &payload, int module)
{
    const auto& pulseData = payload.getPulseData();
    int repeatCount = payload.getRepeatCount();
    
    for (int r = 0; r < repeatCount; r++) {
        for (const auto& pulse : pulseData) {
            uint32_t duration = pulse.first;
            bool level = pulse.second;
            
            // Установить пин в HIGH или LOW
            digitalWrite(moduleCC1101State[module].getOutputPin(), 
                        level ? HIGH : LOW);
            
            // Держать заданное время
            delayMicroseconds(duration);
        }
        
        delay(1); // Пауза между повторами
    }
    
    return true;
}
```

---

## 🔄 Полный пример использования

### Сценарий 1: Записать сигнал с пульта

```cpp
// Пользователь через BLE отправляет команду:
// Command: START_RECORD
// Module: 0
// Frequency: 433.92 MHz
// Preset: Ook270

void handleStartRecord() {
    // 1. Настроить recorder
    recorder.setRecordConfig(
        0,                    // module
        433.92,              // frequency
        MODULATION_ASK_OOK,  // modulation
        2.380371,            // deviation
        270.833333,          // rxBandwidth
        3.79372,             // dataRate
        "Ook270"             // preset
    );
    
    // 2. Переключить модуль в режим записи
    cc1101Control[0].switchMode(OperationMode::RecordSignal);
    
    // 3. Пользователь нажимает кнопку на пульте
    // ... сигнал записывается автоматически ...
    
    // 4. Файл сохраняется: "m0_43392_AM_270_xyz123.sub"
    // 5. Уведомление отправляется на мобильное приложение
}
```

**Результат на SD карте**:

```
SD:/DATA/RECORDS/m0_43392_AM_270_xyz123.sub
```

```
Filetype: Flipper SubGhz RAW File
Version: 1
Frequency: 433920000
Preset: FuriHalSubGhzPresetOok270Async
Protocol: RAW
RAW_Data: 520 -180 310 -390 520 -180 310 -390 520 -180 310 -390 520 -180 ...
```

---

### Сценарий 2: Передать сохраненный сигнал

```cpp
// Пользователь выбирает файл в мобильном приложении:
// File: "door_remote.sub"
// Module: 0
// Repeat: 3

void handleTransmitFile(const std::string& filename, 
                       int module, 
                       int repeat) {
    // 1. Передать сигнал
    bool success = transmitter.transmitSub(filename, module, repeat);
    
    if (success) {
        ESP_LOGI("App", "Signal transmitted successfully");
        // Уведомить пользователя об успехе
    } else {
        ESP_LOGE("App", "Failed to transmit signal");
        // Уведомить пользователя об ошибке
    }
}

// Внутри transmitSub:
// 1. Открыть SD:/DATA/RECORDS/door_remote.sub
// 2. Парсить файл (частота, preset, данные)
// 3. Настроить CC1101
// 4. Передать сигнал 3 раза
// 5. Вернуть модуль в idle
```

---

### Сценарий 3: Список файлов на SD карте

```cpp
// Получить список всех .sub файлов

void handleGetFilesList(const std::string& path) {
    std::string fullPath = FILES_RECORDS_PATH;
    if (!path.empty()) {
        fullPath += "/" + path;
    }
    
    // Получить список файлов
    std::string filesList = filesManager.listAllFiles(fullPath);
    
    // Результат в JSON формате:
    // {
    //   "action": "list",
    //   "files": [
    //     {"name": "door_remote.sub", "size": 2048, "type": "file"},
    //     {"name": "garage_433.sub", "size": 1536, "type": "file"},
    //     {"name": "protocols", "type": "directory"}
    //   ]
    // }
    
    clients.enqueueMessage(NotificationType::FileSystem, filesList);
}
```

---

## 🛠️ Поддерживаемые протоколы

### 1. RAW Protocol (универсальный)

**Когда использовать**: Для любых неизвестных сигналов

```cpp
Protocol: RAW
RAW_Data: <импульсы в микросекундах>
```

**Преимущества**:
- ✅ Работает с любым сигналом
- ✅ Точное воспроизведение

**Недостатки**:
- ⚠️ Большой размер файла
- ⚠️ Не декодируется

---

### 2. Princeton Protocol

**Когда использовать**: Для пультов на чипе PT2262/PT2264

```cpp
Protocol: Princeton
Bit: 24
Key: 00 00 00 00 00 D1 E5 94
TE: 400
Repeat: 5
```

**Преимущества**:
- ✅ Компактный размер
- ✅ Легко читается
- ✅ Можно изменять ключ

**Пример использования**:
- Дверные звонки
- Розетки с пультом
- Простые брелки

---

### 3. BinRAW Protocol

**Когда использовать**: Для бинарных данных

```cpp
Protocol: BinRAW
Bit_RAW: 48
Data_RAW: A5 3C 4D 7E 9F 12
TE: 500
```

---

## 📊 Сравнение форматов хранения

| Протокол | Размер файла | Точность | Редактируемость | Совместимость |
|----------|--------------|----------|-----------------|---------------|
| **RAW** | 5-20 KB | 100% | ❌ | ✅ Flipper Zero |
| **Princeton** | <1 KB | 95% | ✅ | ✅ Flipper Zero |
| **BinRAW** | 1-3 KB | 98% | ⚠️ | ✅ Flipper Zero |
| **Custom** | Varies | 100% | ✅ | ⚠️ Partial |

---

## 🔧 Расширенные функции

### Создание библиотеки сигналов

```cpp
// Структура для организации:

SD:/DATA/RECORDS/
  ├── home/
  │   ├── front_door.sub
  │   ├── garage.sub
  │   └── gate.sub
  ├── car/
  │   ├── central_lock.sub
  │   └── alarm.sub
  └── test/
      ├── test_315mhz.sub
      └── test_433mhz.sub
```

### Редактирование файлов

```cpp
// Можно редактировать .sub файлы на ПК:

// Изменить частоту:
Frequency: 433920000  →  Frequency: 315000000

// Изменить количество повторов для Princeton:
Repeat: 5  →  Repeat: 10

// Изменить ключ для Princeton:
Key: 00 00 00 00 00 D1 E5 94  →  Key: 00 00 00 00 00 AB CD EF
```

---

## 🎯 Best Practices

### 1. Именование файлов

```cpp
// ✅ ХОРОШО - описательные имена
door_front_433mhz.sub
garage_gate_left.sub
car_toyota_lock.sub

// ❌ ПЛОХО - автогенерированные имена
m0_43392_AM_270_abc123.sub
signal_001.sub
test.sub
```

### 2. Организация

```cpp
// ✅ ХОРОШО - по категориям
/home/
/car/
/test/

// ❌ ПЛОХО - всё в куче
/all_files/
```

### 3. Резервное копирование

```cpp
// Периодически копировать важные файлы:
/backups/
  └── 2024-01-15/
      ├── important_1.sub
      └── important_2.sub
```

---

## ⚠️ Ограничения

### Память

```cpp
// Проверка свободного места перед записью:
if (ESP.getFreeHeap() < 8000) {
    ESP_LOGW("Recorder", "Low memory, cannot record");
    return false;
}

// Проверка места на SD:
uint64_t cardSize = SD.cardSize() / (1024 * 1024);
uint64_t usedSpace = SD.usedBytes() / (1024 * 1024);
ESP_LOGI("SD", "Card: %lluMB, Used: %lluMB", cardSize, usedSpace);
```

### Размер файла

```cpp
// Максимальный размер RAW файла:
// - 10,000 samples × 6 bytes ≈ 60 KB
// - Ограничение в Recorder.cpp:
if (samplecount > 10000) {
    samplecount = 10000; // Обрезать
}
```

---

## 🔬 Отладка

### Просмотр содержимого файла

```cpp
void printSubFile(const char* filename) {
    File file = SD.open(filename, FILE_READ);
    if (!file) return;
    
    Serial.println("=== File Content ===");
    while (file.available()) {
        Serial.write(file.read());
    }
    Serial.println("\n=== End ===");
    
    file.close();
}
```

### Валидация файла

```cpp
bool validateSubFile(const char* filename) {
    File file = SD.open(filename, FILE_READ);
    if (!file) return false;
    
    SubFileParser parser(file);
    bool valid = parser.parseFile();
    file.close();
    
    if (valid) {
        ESP_LOGI("Validator", "✅ File is valid");
        parser.displayInfo(); // Вывести информацию
    } else {
        ESP_LOGE("Validator", "❌ File is invalid");
    }
    
    return valid;
}
```

---

## 📱 Интеграция с мобильным приложением

### Команды BLE

```cpp
// 1. Список файлов
Command: 0x05 (getFilesList)
Payload: [path_length] [path_bytes]
Response: Binary file list

// 2. Загрузить файл
Command: 0x09 (loadFileData)
Payload: [path_length] [path_bytes]
Response: File content (chunked)

// 3. Передать файл
Command: 0x07 (transmitFromFile)
Payload: [path_length] [path_bytes]
Response: Success/Error

// 4. Начать запись
Command: 0x08 (requestRecord)
Payload: [frequency] [preset] [modulation] ...
Response: Filename when complete
```

---

## 🎉 Заключение

Работа с протоколами через SD карту обеспечивает:

✅ **Гибкость** - хранение неограниченного количества сигналов  
✅ **Совместимость** - формат Flipper Zero  
✅ **Удобство** - редактирование на ПК  
✅ **Надежность** - энергонезависимое хранение  

---

## 🔗 Связанные файлы в проекте

- `lib/generators/FlipperSubFile.cpp` - Генерация .sub файлов
- `include/SubFileParser.h` - Парсинг .sub файлов
- `src/Recorder.cpp` - Запись сигналов
- `src/Transmitter.cpp` - Передача сигналов
- `lib/subghz/protocols/` - Реализации протоколов
- `include/FilesManager.h` - Управление файлами на SD

---

**Версия документа**: 1.0  
**Дата**: 2025-01-08  
**Проект**: ESP32 CC1101 BLE Controller

















