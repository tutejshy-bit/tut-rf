---
name: Unified Improvements Plan
overview: "Объединённый план улучшений: синхронизация частоты CC1101, очистка StringHelpers и StreamingSubFileParser, оптимизация буферов, и улучшение BinaryStatus с указанием количества модулей"
todos:
  - id: optimize_getfrequency
    content: Оптимизировать getFrequency() для использования SpiReadBurstReg вместо трёх отдельных SpiReadReg
    status: pending
  - id: fix_calibrate
    content: Изменить Calibrate() для чтения частоты из регистров через getFrequency() вместо MHz[currentModule]
    status: pending
    dependencies:
      - optimize_getfrequency
  - id: fix_setpa
    content: Изменить setPA() для чтения частоты из регистров через getFrequency() вместо MHz[currentModule]
    status: pending
    dependencies:
      - optimize_getfrequency
  - id: cleanup_stringhelpers
    content: Удалить неиспользуемые функции из StringHelpers (оставить только generateRandomString)
    status: pending
  - id: remove_unused_streamrawdata
    content: Удалить неиспользуемый метод streamRawData из StreamingSubFileParser (дублирует функциональность StreamingPulsePayload)
    status: pending
  - id: extract_preset_arrays
    content: Вынести preset byte arrays из SubFileParser.h в отдельный файл CC1101Presets.h
    status: pending
  - id: remove_subfileparser
    content: Удалить SubFileParser класс и файл SubFileParser.h после выноса preset arrays
    status: pending
    dependencies:
      - extract_preset_arrays
  - id: update_binarystatus_structure
    content: Добавить поле numModules в структуру BinaryStatus и изменить структуру для поддержки до 4 модулей
    status: pending
  - id: update_binarystatus_creation
    content: Обновить код создания BinaryStatus в main.cpp и CC1101Worker.cpp для указания количества модулей
    status: pending
    dependencies:
      - update_binarystatus_structure
  - id: update_binarystatus_parser
    content: Обновить парсер BinaryStatus в Dart для поддержки numModules и переменного количества модулей
    status: pending
    dependencies:
      - update_binarystatus_structure
  - id: fix_filelist_buffer_overflow
    content: Исправить перезапись пакетов в handleGetFilesList - увеличить буфер Notification.binaryData с 128 до 512 байт
    status: pending
  - id: fix_filelist_async_send
    content: Обеспечить копирование данных перед отправкой в handleGetFilesList - использовать enqueueMessage вместо прямого notifyAllBinary или копировать данные в локальный буфер
    status: pending
    dependencies:
      - fix_filelist_buffer_overflow
  - id: remove_unnecessary_mkdir_in_filelist
    content: Удалить создание директории из handleGetFilesList - это не нужно для получения списка файлов
    status: pending
  - id: refactor_file_operations
    content: Рефакторинг файловых операций - вынести повторяющиеся куски (копирование файлов, создание директорий, построение FATFS путей) в отдельные функции
    status: pending
  - id: optimize_file_operations
    content: Оптимизация файловых операций - убрать лишние проверки, оптимизировать копирование файлов (использовать буфер вместо byte-by-byte)
    status: pending
    dependencies:
      - refactor_file_operations
  - id: remove_protocol_decoder
    content: Удалить ProtocolDecoder из ESP32 - не работает и не нужен, будет реализован в приложении
    status: pending
  - id: cleanup_request_header
    content: Очистить Request.h - оставить только RequestScan, удалить RequestRecord, TransmitFromFileRequest и calculateCRC32
    status: pending
  - id: remove_request_cpp
    content: Удалить Request.cpp - функция calculateCRC32 не используется в ESP32 коде
    status: pending
    dependencies:
      - cleanup_request_header
  - id: remove_unused_request_includes
    content: Удалить неиспользуемые
    status: pending
    dependencies:
      - cleanup_request_header
  - id: use_safebuffer_for_filelist
    content: Использовать SafeBuffer вместо статического буфера в handleGetFilesList для предотвращения перезаписи
    status: pending
    dependencies:
      - fix_filelist_async_send
  - id: use_safebuffer_for_directory_tree
    content: Использовать SafeBuffer вместо статического буфера в handleGetDirectoryTree для предотвращения перезаписи
    status: pending
---

# Объединённый план улучшений

## 1. Исправление синхронизации частоты в CC1101_Radio

### Проблема

Методы `Calibrate()` и `setPA()` используют переменную `MHz[currentModule]` вместо реальной частоты из регистров, что приводит к ошибкам при прямом изменении регистров.

### Решение

- Оптимизировать `getFrequency()` для использования `SpiReadBurstReg` (1 транзакция вместо 3)
- Использовать `getFrequency()` в `Calibrate()` и `setPA()` вместо `MHz[currentModule]`

**Файлы**: [lib/cc1101/CC1101_Radio.cpp](lib/cc1101/CC1101_Radio.cpp)

---

## 2. Очистка StringHelpers и оптимизация StreamingSubFileParser/StreamingPulsePayload

### StringHelpers

Удалить неиспользуемые функции (`toLowerCase`, `toStdString`, `endsWith`, `toArduinoString`, `escapeJson`), оставить только `generateRandomString()`.

**Файлы**: [lib/helpers/StringHelpers.h](lib/helpers/StringHelpers.h), [lib/helpers/StringHelpers.cpp](lib/helpers/StringHelpers.cpp)

### Анализ StreamingSubFileParser и StreamingPulsePayload

**Текущая ситуация:**

1. **StreamingSubFileParser**:

   - Используется только для `parseHeader()` - чтения заголовка файла (frequency, preset, protocol)
   - Имеет метод `streamRawData()` с callback, но он **НЕ используется** в коде
   - Парсит RAW данные построчно через callback

2. **StreamingPulsePayload**:

   - Используется для чтения RAW данных во время передачи в `CC1101Worker::transmitSub()`
   - Имеет iterator-based подход (`next()`) - более удобен для передачи
   - Поддерживает repeat (возврат к началу RAW_Data)
   - **Дублирует функциональность** парсинга RAW данных из `StreamingSubFileParser::streamRawData()`

3. **PulsePayload**:

   - Старый класс, который хранит все данные в памяти (std::vector)
   - Используется в `SubFileParser::getPayload()` (старый парсер)
   - Не используется в `CC1101Worker::transmitSub()` (там используется `StreamingPulsePayload`)

**Проблема**: Дублирование кода парсинга RAW данных между `StreamingSubFileParser::streamRawData()` и `StreamingPulsePayload`.

### Решение

#### 2.1. Удалить неиспользуемый метод streamRawData из StreamingSubFileParser

**Файл**: [include/StreamingSubFileParser.h](include/StreamingSubFileParser.h)

**Удалить** метод `streamRawData()` (строки 47-108), так как он не используется и дублирует функциональность `StreamingPulsePayload`.

**Обоснование**: `StreamingPulsePayload` имеет более удобный интерфейс для передачи (`next()`) и поддерживает repeat, что необходимо для передачи сигналов.

#### 2.2. Расширить StreamingPulsePayload для поддержки режима памяти (опционально)

Если в будущем понадобится работа с данными в памяти (не из файла), можно добавить режим памяти:

```cpp
// Режим файла (текущий)
bool init(const char* filePath, uint32_t repeatCount);

// Режим памяти (новый)
bool init(const std::vector<std::pair<uint32_t, bool>>& pulses, uint32_t repeatCount);
```

**Примечание**: Это опционально, так как текущая реализация работает только с файлами, что оптимально для ESP32.

#### 2.3. PulsePayload

`PulsePayload` используется только в `SubFileParser::getPayload()`, но так как `SubFileParser` планируется удалить (раздел 2.1), `PulsePayload` также можно удалить, если он больше нигде не используется.

**Файлы**: [include/StreamingSubFileParser.h](include/StreamingSubFileParser.h), [src/StreamingSubFileParser.cpp](src/StreamingSubFileParser.cpp), [lib/subghz/StreamingPulsePayload.h](lib/subghz/StreamingPulsePayload.h), [lib/subghz/StreamingPulsePayload.cpp](lib/subghz/StreamingPulsePayload.cpp)

### Преимущества

1. **Меньше кода**: Удаление неиспользуемого метода уменьшает размер кода
2. **Нет дублирования**: Один класс (`StreamingPulsePayload`) отвечает за чтение RAW данных
3. **Чище архитектура**: Разделение ответственности: `StreamingSubFileParser` - заголовок, `StreamingPulsePayload` - данные

---

## 2.1. Удаление SubFileParser

### Проблема

`SubFileParser` больше не используется в коде:

1. **Класс SubFileParser** - не создается нигде в коде
2. **Методы парсинга** - заменены на `StreamingSubFileParser` и `StreamingPulsePayload`
3. **Preset byte arrays** - используются напрямую в `CC1101Worker`, но определены в `SubFileParser.h`
4. **ProtocolDecoder** - планируется удаление (раздел 6), который был единственным потенциальным пользователем

### Текущее использование

**Preset byte arrays** (единственное, что реально используется):

- Определены в `SubFileParser.h` (строки 13-35)
- Используются в `CC1101Worker.cpp`:
  - Через функцию `getPresetByteArray()` (строки 18-33) - дублирует `SubFileParser::getByteArrayForPreset()`
  - Прямое использование: `subghz_device_cc1101_preset_ook_650khz_async_regs` (строка 1344)

**Класс SubFileParser**:

- НЕ создается нигде (`SubFileParser(` не найдено)
- Методы `parseFile()`, `getPayload()`, `displayInfo()` не используются
- Используется только для получения preset byte arrays через `#include`

### Решение

#### 2.1.1. Вынести preset byte arrays в отдельный файл

**Создать новый файл**: [include/CC1101Presets.h](include/CC1101Presets.h)

**Содержимое:**

```cpp
#ifndef CC1101_PRESETS_H
#define CC1101_PRESETS_H

#include <cstdint>

// CC1101 preset register arrays (44 bytes each)
extern const uint8_t subghz_device_cc1101_preset_ook_270khz_async_regs[44];
extern const uint8_t subghz_device_cc1101_preset_ook_650khz_async_regs[44];
extern const uint8_t subghz_device_cc1101_preset_2fsk_dev2_38khz_async_regs[44];
extern const uint8_t subghz_device_cc1101_preset_2fsk_dev47_6khz_async_regs[44];
extern const uint8_t subghz_device_cc1101_preset_msk_99_97kb_async_regs[44];
extern const uint8_t subghz_device_cc1101_preset_gfsk_9_99kb_async_regs[44];

// Helper function to get preset byte array by preset name
const uint8_t* getPresetByteArray(const char* presetName);

#endif // CC1101_PRESETS_H
```

**Создать файл реализации**: [src/CC1101Presets.cpp](src/CC1101Presets.cpp)

**Содержимое:**

```cpp
#include "CC1101Presets.h"

const uint8_t subghz_device_cc1101_preset_ook_270khz_async_regs[44] = {
    0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x30, 0x11,
    0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
    0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// ... остальные preset arrays ...

const uint8_t* getPresetByteArray(const char* presetName) {
    if (strcmp(presetName, "FuriHalSubGhzPresetOok270Async") == 0) {
        return subghz_device_cc1101_preset_ook_270khz_async_regs;
    } else if (strcmp(presetName, "FuriHalSubGhzPresetOok650Async") == 0) {
        return subghz_device_cc1101_preset_ook_650khz_async_regs;
    }
    // ... остальные проверки ...
    return nullptr;
}
```

#### 2.1.2. Обновить CC1101Worker для использования нового файла

**Файл**: [src/CC1101Worker.cpp](src/CC1101Worker.cpp)

**Изменения:**

- Удалить `#include "SubFileParser.h"` (строка 10)
- Добавить `#include "CC1101Presets.h"`
- Удалить функцию `getPresetByteArray()` (строки 18-33) - использовать из `CC1101Presets.h`
- Обновить использование: `getPresetByteArray(header.preset.c_str())` вместо локальной функции

#### 2.1.3. Удалить SubFileParser.h

**Файл**: [include/SubFileParser.h](include/SubFileParser.h)

После выноса preset arrays и обновления всех зависимостей, файл можно полностью удалить.

**Файлы**: [include/SubFileParser.h](include/SubFileParser.h), [src/CC1101Worker.cpp](src/CC1101Worker.cpp), [include/CC1101Presets.h](include/CC1101Presets.h) (новый), [src/CC1101Presets.cpp](src/CC1101Presets.cpp) (новый)

### Преимущества

1. **Меньше кода**: Удаление неиспользуемого класса (~300 строк)
2. **Чище архитектура**: Preset arrays в отдельном файле, не связанном с парсингом
3. **Меньше зависимостей**: Удаление зависимостей от `SubGhzProtocol`, `PulsePayload`, `protocols/Princeton.h`
4. **Проще поддержка**: Preset arrays в одном месте, легко обновлять

---

## 3. Улучшение BinaryStatus - указание количества модулей

### Проблема

Структура `BinaryStatus` жёстко закодирована на 2 модуля, что не позволяет поддерживать переменное количество модулей.

### Решение

Добавить поле `numModules` и изменить структуру для поддержки до 4 модулей:

```cpp
struct BinaryStatus {
    uint8_t messageType = MSG_STATUS;
    uint8_t numModules;             // Количество модулей
    uint8_t numRegisters;
    uint32_t freeHeap;
    struct {
        uint8_t mode;
        uint8_t registers[47];
    } modules[4];  // Максимум 4 модуля
};
```

Обновить код создания в [src/main.cpp](src/main.cpp) и [src/CC1101Worker.cpp](src/CC1101Worker.cpp), а также парсер в [mobile_app/lib/services/binary_message_parser.dart](mobile_app/lib/services/binary_message_parser.dart).

**Файлы**: [include/BinaryMessages.h](include/BinaryMessages.h), [src/main.cpp](src/main.cpp), [src/CC1101Worker.cpp](src/CC1101Worker.cpp), [mobile_app/lib/services/binary_message_parser.dart](mobile_app/lib/services/binary_message_parser.dart)

---

## 4. Исправление проблемы перезаписи пакетов в handleGetFilesList

### Проблема

При отправке большого списка файлов все пакеты перезаписываются последним. После перезапуска приложения иногда начинает работать нормально. Признаки указывают на проблему с обработкой больших списков файлов.

### Анализ

**Найденные проблемы:**

1. **Буфер слишком мал**: В структуре `Notification` (в `ClientsManager.h`) буфер `binaryData[128]` слишком мал для файлового списка, который может быть до 500 байт. Данные обрезаются при копировании в очередь.

2. **Статический буфер переиспользуется**: В `FileCommands.h` используется статический буфер `static uint8_t binaryBuffer[BUFFER_SIZE]` (500 байт), который переиспользуется для каждого сообщения. Если отправка через BLE медленная, буфер может быть перезаписан следующим сообщением до того, как предыдущее будет отправлено.

3. **Прямая отправка без копирования**: `notifyAllBinary` не использует очередь для больших сообщений - он сразу отправляет данные. Если отправка асинхронная, статический буфер может быть перезаписан.

### Решение

#### 4.1. Увеличение буфера Notification

**Файл**: [include/ClientsManager.h](include/ClientsManager.h)

**Текущий код (строка 60):**

```cpp
uint8_t binaryData[128];  // Static buffer for binary messages
```

**Изменение:** Увеличить до 512 байт (достаточно для файлового списка):

```cpp
uint8_t binaryData[512];  // Static buffer for binary messages (increased for file lists)
```

#### 4.2. Копирование данных перед отправкой

**Файл**: [include/FileCommands.h](include/FileCommands.h)

**Проблема**: Статический буфер `binaryBuffer` переиспользуется, и данные могут быть перезаписаны до отправки.

**Решение**: Копировать данные в локальный буфер перед отправкой или использовать очередь:

**Вариант 1**: Копировать в локальный буфер перед отправкой:

```cpp
// Вместо прямого использования binaryBuffer
uint8_t sendBuffer[BUFFER_SIZE];
memcpy(sendBuffer, binaryBuffer, bufferOffset);
clients.notifyAllBinary(NotificationType::FileSystem, sendBuffer, bufferOffset);
```

**Вариант 2**: Использовать очередь (если поддерживает большие сообщения):

```cpp
std::string message(reinterpret_cast<const char*>(binaryBuffer), bufferOffset);
clients.enqueueMessage(NotificationType::FileSystem, message);
```

**Рекомендация**: Использовать Вариант 1 (копирование в локальный буфер), так как он проще и не требует изменений в очереди.

#### 4.3. Проверка на стороне приложения

**Файл**: [mobile_app/lib/providers/ble_provider.dart](mobile_app/lib/providers/ble_provider.dart)

**Проверить**: Убедиться, что приложение правильно накапливает файлы в `_streamingFileBuffer` и не перезаписывает данные. Код выглядит корректно, но стоит добавить дополнительное логирование для отладки.

**Файлы**: [include/ClientsManager.h](include/ClientsManager.h), [include/FileCommands.h](include/FileCommands.h)

---

## 5. Оптимизация файловых операций

### Проблемы

1. **Лишнее создание директории**: В `handleGetFilesList` создаётся директория, если она не существует (строки 250-271). Это не нужно для получения списка файлов - достаточно проверить существование и вернуть ошибку.

2. **Дублирование кода копирования файлов**: Код копирования файлов повторяется в трёх местах:

   - `handleCopyFile` (строки 980-982)
   - `handleMoveFile` (строки 1048-1050)
   - `handleSaveToSignalsWithName` (строки 823-825)

Все используют неэффективный byte-by-byte копирование через `destFile.write(sourceFile.read())`.

3. **Повторяющееся построение FATFS путей**: Код построения путей с `/sd` префиксом повторяется в нескольких местах:

   - `handleGetFilesList` (строки 278-283)
   - `buildDirectoryTreeBinaryRecursive` (строки 112-120)
   - `collectDirectoryPaths` (строки 1065-1076)

4. **Дублирование создания директорий**: Логика создания директорий с проверкой родительских повторяется в:

   - `handleGetFilesList` (строки 250-271) - лишнее!
   - `handleCreateDirectory` (строки 723-729)
   - `handleSaveToSignalsWithName` (строки 802-806)

5. **Неэффективное копирование**: Byte-by-byte копирование вместо буферизованного чтения/записи.

### Решение

#### 5.1. Удалить создание директории из handleGetFilesList

**Файл**: [include/FileCommands.h](include/FileCommands.h)

**Удалить строки 250-271** - создание директории не нужно для получения списка файлов. Если директория не существует, достаточно вернуть ошибку через `sendBinaryFileListError(3)`.

#### 5.2. Вынести повторяющиеся функции

**Файл**: [include/FileCommands.h](include/FileCommands.h)

**Добавить вспомогательные функции:**

```cpp
// Построение FATFS пути с /sd префиксом
static void buildFatfsPath(const char* path, char* fatfsPath, size_t maxLen) {
    snprintf(fatfsPath, maxLen, "/sd%s", path);
}

// Создание директории с родительскими (если нужно)
static bool ensureDirectoryExists(const char* path) {
    if (SD.exists(path)) {
        return true;
    }
    
    // Создать родительские директории
    size_t pathLen = strlen(path);
    static PathBuffer currentPath;
    for (size_t i = 1; i < pathLen; i++) {
        if (path[i] == '/') {
            currentPath.clear();
            currentPath.append(path, i);
            if (!SD.exists(currentPath.c_str())) {
                if (!SD.mkdir(currentPath.c_str())) {
                    return false;
                }
            }
        }
    }
    
    return SD.mkdir(path);
}

// Эффективное копирование файла с буферизацией
static bool copyFileContent(File& sourceFile, File& destFile) {
    const size_t BUFFER_SIZE = 512;  // Оптимальный размер для SD карт
    static uint8_t buffer[BUFFER_SIZE];
    
    while (sourceFile.available()) {
        size_t bytesRead = sourceFile.read(buffer, BUFFER_SIZE);
        if (bytesRead == 0) break;
        
        size_t bytesWritten = destFile.write(buffer, bytesRead);
        if (bytesWritten != bytesRead) {
            return false;
        }
    }
    
    return true;
}
```

#### 5.3. Оптимизировать копирование файлов

**Заменить** во всех трёх местах:

```cpp
// Старый код (неэффективный)
while (sourceFile.available()) {
    destFile.write(sourceFile.read());
}
```

**На:**

```cpp
// Новый код (эффективный)
if (!copyFileContent(sourceFile, destFile)) {
    // Обработка ошибки
}
```

#### 5.4. Использовать вспомогательные функции

- Заменить построение FATFS путей на `buildFatfsPath()`
- Заменить создание директорий на `ensureDirectoryExists()` (где нужно)
- Заменить копирование файлов на `copyFileContent()`

**Файлы**: [include/FileCommands.h](include/FileCommands.h)

### Преимущества

1. **Производительность**: Буферизованное копирование файлов в 10-50 раз быстрее byte-by-byte
2. **Меньше кода**: Удаление дублирования уменьшает размер кода
3. **Проще поддержка**: Изменения в одном месте вместо трёх
4. **Быстрее получение списка**: Удаление лишнего создания директории ускоряет `handleGetFilesList`

---

## 6. Удаление ProtocolDecoder

### Проблема

`ProtocolDecoder` не работает и не нужен на ESP32. Планируется реализация декодирования протоколов в мобильном приложении.

### Текущее использование

`ProtocolDecoder` используется только в `CC1101Worker::checkAndSaveRecording()` (строки 629-651) для попытки декодирования записанного сигнала. Результат декодирования практически не используется - сигнал всё равно сохраняется как RAW.

### Решение

#### 6.1. Удалить использование ProtocolDecoder из CC1101Worker

**Файл**: [src/CC1101Worker.cpp](src/CC1101Worker.cpp)

**Удалить строки 629-651** - код попытки декодирования:

```cpp
// Удалить:
ProtocolDecoder::DecodedSignal decoded;
bool decodedSuccess = false;
// ... весь блок декодирования ...
```

**Упростить генерацию имени файла** - убрать проверку `decoded.protocol` (строка 653+), всегда использовать "RAW" или базовое имя.

#### 6.2. Удалить include'ы ProtocolDecoder

**Файлы**:

- [include/CC1101Worker.h](include/CC1101Worker.h) - удалить `#include "ProtocolDecoder.h"`
- [src/CC1101Worker.cpp](src/CC1101Worker.cpp) - удалить `#include "ProtocolDecoder.h"`

#### 6.3. Удалить файлы ProtocolDecoder

**Файлы для удаления**:

- [include/ProtocolDecoder.h](include/ProtocolDecoder.h)
- [src/ProtocolDecoder.cpp](src/ProtocolDecoder.cpp)

**Файлы**: [include/CC1101Worker.h](include/CC1101Worker.h), [src/CC1101Worker.cpp](src/CC1101Worker.cpp), [include/ProtocolDecoder.h](include/ProtocolDecoder.h), [src/ProtocolDecoder.cpp](src/ProtocolDecoder.cpp)

### Преимущества

1. **Меньше кода**: Удаление неиспользуемого функционала
2. **Меньше памяти**: Освобождение памяти, используемой для декодирования
3. **Проще поддержка**: Меньше кода для поддержки
4. **Чище архитектура**: Декодирование будет в приложении, где больше ресурсов

---

## 7. Очистка Request.h и удаление Request.cpp

### Проблема

В `Request.h` определены структуры и функции, которые не используются напрямую в ESP32 коде:

1. **`RequestRecord`** - определена, но не используется. В `RecorderCommands.h` данные парсятся вручную (строки 36-80), структура не применяется.
2. **`TransmitFromFileRequest`** - не используется. В `TransmitterCommands.h` данные парсятся вручную.
3. **`calculateCRC32`** - не используется в ESP32. Реализация есть только в мобильном приложении (Dart).

### Текущее использование

- **`RequestScan`** - используется в `StateCommands.h` (строки 43-44) через `sizeof(RequestScan)` и `memcpy` - **НУЖЕН**
- **`RequestRecord`** - только упоминается в комментарии в `RecorderCommands.h`, но не используется напрямую
- **`TransmitFromFileRequest`** - не используется нигде
- **`calculateCRC32`** - не используется в ESP32 коде

### Решение

#### 7.1. Очистить Request.h

**Файл**: [include/Request.h](include/Request.h)

**Оставить только:**

```cpp
#ifndef Request_h
#define Request_h

struct RequestScan {
    uint8_t module;    // 1 byte for module
    int8_t minRssi;   // 1 byte for minimum RSSI value
};

#endif  // Request_h
```

**Удалить:**

- `#include <string>` (не нужен)
- `struct RequestRecord` (не используется)
- `struct TransmitFromFileRequest` (не используется)
- `uint32_t calculateCRC32(...)` (не используется)

#### 7.2. Удалить Request.cpp

**Файл**: [src/Request.cpp](src/Request.cpp)

Файл содержит только реализацию `calculateCRC32`, которая не используется в ESP32 коде.

#### 7.3. Удалить неиспользуемые include'ы

**Файлы**:

- [src/BleAdapter.cpp](src/BleAdapter.cpp) - удалить `#include "Request.h"` (строка 2, не используется)
- [include/RecorderCommands.h](include/RecorderCommands.h) - удалить `#include "Request.h"` если есть (структура не используется)

**Файлы**: [include/Request.h](include/Request.h), [src/Request.cpp](src/Request.cpp), [src/BleAdapter.cpp](src/BleAdapter.cpp), [include/RecorderCommands.h](include/RecorderCommands.h)

### Преимущества

1. **Меньше кода**: Удаление неиспользуемых структур и функций
2. **Меньше памяти**: Удаление неиспользуемого кода
3. **Проще поддержка**: Меньше кода для поддержки
4. **Чище архитектура**: Остаётся только то, что реально используется

---

## 8. Использование SafeBuffer для предотвращения перезаписи буферов

### Проблема

В `FileCommands.h` используются статические буферы, которые могут быть перезаписаны при медленной отправке через BLE:

1. **`handleGetFilesList`** (строка 302): `static uint8_t binaryBuffer[BUFFER_SIZE]` (500 байт)
2. **`handleGetDirectoryTree`** (строка 1150): `static uint8_t binaryBuffer[BUFFER_SIZE]` (2048 байт)

Эти статические буферы переиспользуются для каждого сообщения. Если отправка через BLE медленная, буфер может быть перезаписан следующим сообщением до того, как предыдущее будет отправлено.

### Решение

Использовать `SafeBuffer` (RAII обертка) вместо статических буферов. Это обеспечит:

1. **Автоматическое освобождение памяти** при выходе из scope
2. **Изоляцию буферов** - каждый вызов функции получает свой буфер
3. **Предотвращение перезаписи** - буфер существует только в scope функции

### Реализация

#### 8.1. Заменить статический буфер в handleGetFilesList

**Файл**: [include/FileCommands.h](include/FileCommands.h)

**Текущий код (строка 302):**

```cpp
const size_t BUFFER_SIZE = 500;
static uint8_t binaryBuffer[BUFFER_SIZE];
```

**Изменение:**

```cpp
#include "SafeBuffer.h"

const size_t BUFFER_SIZE = 500;
ByteBuffer binaryBuffer(BUFFER_SIZE);
if (!binaryBuffer.isValid()) {
    ESP_LOGE("FileCommands", "Failed to allocate buffer for file list");
    sendBinaryFileListError(4); // 4 = out of memory
    return;
}

// Использовать binaryBuffer.get() вместо binaryBuffer
// ...
clients.notifyAllBinary(NotificationType::FileSystem, binaryBuffer.get(), bufferOffset);
```

#### 8.2. Заменить статический буфер в handleGetDirectoryTree

**Файл**: [include/FileCommands.h](include/FileCommands.h)

**Текущий код (строка 1150):**

```cpp
const size_t BUFFER_SIZE = 2048;
static uint8_t binaryBuffer[BUFFER_SIZE];
```

**Изменение:**

```cpp
const size_t BUFFER_SIZE = 2048;
ByteBuffer binaryBuffer(BUFFER_SIZE);
if (!binaryBuffer.isValid()) {
    ESP_LOGE("FileCommands", "Failed to allocate buffer for directory tree");
    // Отправить ошибку
    return;
}

// Использовать binaryBuffer.get() вместо binaryBuffer
// ...
clients.notifyAllBinary(NotificationType::FileSystem, binaryBuffer.get(), bufferOffset);
```

### Альтернатива для небольших буферов

Для небольших буферов (до 512 байт) можно использовать локальный массив вместо SafeBuffer, чтобы избежать динамической аллокации:

```cpp
// Для handleGetFilesList (500 байт)
uint8_t binaryBuffer[BUFFER_SIZE];  // Локальный массив вместо static
```

**Рекомендация**: Использовать локальный массив для `handleGetFilesList` (500 байт) и `SafeBuffer` для `handleGetDirectoryTree` (2048 байт), чтобы избежать переполнения стека.

### Преимущества

1. **Предотвращение перезаписи**: Каждый вызов функции получает свой буфер
2. **Автоматическое управление памятью**: RAII гарантирует освобождение памяти
3. **Безопасность**: Невозможно забыть освободить память
4. **Изоляция**: Буферы не влияют друг на друга между вызовами

### Недостатки

1. **Фрагментация памяти**: Динамическая аллокация может привести к фрагментации на ESP32
2. **Производительность**: malloc/free медленнее статических буферов

**Компромисс**: Использовать локальные массивы для небольших буферов (до 512 байт) и SafeBuffer для больших (2048+ байт).

**Файлы**: [include/FileCommands.h](include/FileCommands.h), [include/SafeBuffer.h](include/SafeBuffer.h)