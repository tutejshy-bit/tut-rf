# 🔧 Оптимизация размера прошивки ESP32 CC1101

**Текущий размер**: 1,553,765 байт (98.8% Flash)  
**Цель**: Уменьшить до ~1,200,000 байт (76% Flash)  
**Экономия**: ~350 KB (22%)

---

## 📊 Анализ текущего размера

### Размеры секций:
```
text:  1,276,445 байт (~1.22 MB) - код программы
data:    283,857 байт (~277 KB)  - инициализированные данные  
bss:      24,272 байт (~24 KB)   - неинициализированные данные
-------------------------------------------
Итого: 1,584,574 байт (~1.51 MB) в ELF
Flash: 1,553,765 байт (~1.48 MB) сжато
```

### "Тяжелые" компоненты (по приоритету):

1. **ESP32 BLE Arduino** (~200-300 KB) - САМАЯ ТЯЖЕЛАЯ
2. **SimpleCLI** (~30-50 KB) - Парсинг команд для Serial
3. **Arduino Framework** (~400 KB) - Базовые функции
4. **STL (std::vector, std::string)** (~100 KB) - C++ стандартная библиотека
5. **Update/OTA** (~50 KB) - Если не используется
6. **EEPROM** (~10 KB) - Если не используется

---

## 🎯 План оптимизации (по приоритету)

### ⚡ Фаза 1: Быстрые победы (Экономия: ~100 KB)

#### 1. Изменить флаги компиляции
**Файл**: `platformio.ini`

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
board_build.partitions = custom_partitions.csv

lib_deps = 
    spacehuhn/SimpleCLI@^1.1.4
    ESP32 BLE Arduino@^2.0.0

# ОПТИМИЗАЦИЯ РАЗМЕРА
build_flags = 
    -DCORE_DEBUG_LEVEL=2                    # Уменьшить с 4 до 2 (экономия ~20KB)
    -Os                                     # Оптимизация размера вместо скорости
    -ffunction-sections                     # Удалять неиспользуемые функции
    -fdata-sections
    -Wl,--gc-sections                       # Сборщик мусора линкера
    -DARDUINO_USB_MODE=0                    # Отключить USB CDC (экономия ~15KB)
    -DARDUINO_USB_CDC_ON_BOOT=0
    -DDISABLE_ALL_LIBRARY_WARNINGS
    -fno-exceptions                         # Отключить C++ исключения (экономия ~30KB)
    -fno-rtti                               # Отключить RTTI (экономия ~10KB)
    
build_unflags = 
    -fexceptions
    -frtti
```

**Экономия**: ~75-100 KB  
**Риски**: Минимальные (отключены неиспользуемые функции)

---

#### 2. Убрать неиспользуемые библиотеки

**Проверить использование EEPROM:**
```bash
# Поиск использования EEPROM
grep -r "EEPROM\." src/
```

Если не используется - удалить из `src/main.cpp`:
```cpp
// УДАЛИТЬ:
#include <EEPROM.h>

// И в setup() удалить инициализацию если есть
```

**Экономия**: ~10 KB

---

#### 3. Упростить SimpleCLI (если Serial команды не критичны)

**Вариант А**: Оставить только базовые команды
**Вариант Б**: Заменить на простой парсер

```cpp
// Вместо SimpleCLI (30-50 KB)
// Свой легкий парсер (5-10 KB)

void parseCommand(String cmd) {
    cmd.trim();
    if (cmd.startsWith("help")) {
        Serial.println("Commands: status, reset, scan");
    } else if (cmd.startsWith("status")) {
        printStatus();
    } else if (cmd.startsWith("reset")) {
        ESP.restart();
    }
    // ... и т.д.
}
```

**Экономия**: ~20-40 KB  
**Риски**: Потеря расширенных функций CLI

---

### 🔥 Фаза 2: Замена тяжелых библиотек (Экономия: ~150-200 KB)

#### 4. Облегченная альтернатива BLE (САМОЕ ВАЖНОЕ!)

**Проблема**: ESP32 BLE Arduino - очень тяжелая (~200-300 KB)

**Решение**: Использовать только необходимые части ESP-IDF BLE API

**Новый файл**: `include/LightBleAdapter.h`
```cpp
#ifndef LightBleAdapter_h
#define LightBleAdapter_h

// Вместо полной библиотеки ESP32 BLE Arduino
// Использовать напрямую ESP-IDF BLE API (в 2-3 раза легче)

#include "esp_bt.h"
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_bt_main.h"
#include "esp_gatt_common_api.h"

class LightBleAdapter {
private:
    uint16_t conn_id = 0;
    uint16_t service_handle = 0;
    uint16_t char_handle = 0;
    bool connected = false;
    
    // Callbacks
    static void gap_event_handler(esp_gap_ble_cb_event_t event, 
                                  esp_ble_gap_cb_param_t *param);
    static void gatts_event_handler(esp_gatts_cb_event_t event, 
                                    esp_gatt_if_t gatts_if, 
                                    esp_ble_gatts_cb_param_t *param);
    
public:
    void begin();
    void notify(const uint8_t* data, size_t len);
    bool isConnected() { return connected; }
};

#endif
```

**Экономия**: ~150-200 KB  
**Риски**: Нужно переписать BleAdapter.cpp (2-3 часа работы)  
**Приоритет**: ВЫСОКИЙ - самая большая экономия

---

#### 5. Оптимизировать использование STL

**Проблема**: `std::vector`, `std::string`, `std::stringstream` - тяжелые

**Решение**: Использовать C-style массивы и Arduino String где возможно

**Пример оптимизации в Recorder.cpp:**

```cpp
// БЫЛО (тяжело):
std::vector<unsigned long> samplesCopy;
samplesCopy.reserve(samplesSize);

// СТАЛО (легче):
#define MAX_SAMPLES_STATIC 2048
static unsigned long samplesBuffer[MAX_SAMPLES_STATIC];
size_t samplesCount = 0;

// Копируем напрямую в статический буфер
if (samplesSize <= MAX_SAMPLES_STATIC) {
    memcpy(samplesBuffer, data.samples.data(), 
           samplesSize * sizeof(unsigned long));
    samplesCount = samplesSize;
}
```

**Экономия**: ~30-50 KB  
**Риски**: Ограничение на максимальное количество сэмплов  
**Приоритет**: СРЕДНИЙ

---

#### 6. Убрать Update/OTA если не используется

**Проверить использование:**
```bash
grep -r "Update\." src/
grep -r "OTA" src/
```

Если не используется OTA обновление - удалить:
```cpp
// В main.cpp удалить:
#include "Update.h"
```

**И в platformio.ini исключить:**
```ini
lib_ignore = Update
```

**Экономия**: ~40-50 KB  
**Риски**: Нельзя будет делать OTA updates  
**Приоритет**: ВЫСОКИЙ если OTA не нужен

---

### 🚀 Фаза 3: Агрессивная оптимизация (Экономия: ~100 KB)

#### 7. Перейти на ESP-IDF вместо Arduino Framework

**Самая радикальная оптимизация!**

**Преимущества**:
- Arduino Framework: ~400 KB
- Чистый ESP-IDF: ~150-200 KB
- **Экономия**: ~200 KB

**Недостатки**:
- Нужно переписать весь код
- Нет удобных функций Arduino (Serial.print, String, etc)
- Требует 1-2 недели работы

**platformio.ini для ESP-IDF:**
```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = espidf  # Вместо arduino

build_flags = 
    -DCONFIG_BT_ENABLED=1
    -DCONFIG_BLUEDROID_ENABLED=1
```

**Приоритет**: НИЗКИЙ (слишком много работы)

---

#### 8. Минимизировать String литералы

**Проблема**: Каждая строка в коде занимает место в Flash

**Решение**: Объединить похожие сообщения, использовать коды ошибок

```cpp
// БЫЛО:
ESP_LOGE(TAG, "Failed to allocate memory for taskParameters");
ESP_LOGE(TAG, "Failed to allocate memory for BLE callbacks");
ESP_LOGE(TAG, "Failed to allocate BLE2902 descriptor");

// СТАЛО:
const char* ERR_ALLOC = "Alloc fail:";
ESP_LOGE(TAG, "%s taskParams", ERR_ALLOC);
ESP_LOGE(TAG, "%s BLE cb", ERR_ALLOC);
ESP_LOGE(TAG, "%s BLE2902", ERR_ALLOC);
```

**Экономия**: ~10-20 KB  
**Приоритет**: НИЗКИЙ (много работы, мало выигрыша)

---

## 📋 Конкретный план действий

### Немедленно (1-2 часа):

1. ✅ **Изменить build_flags в platformio.ini**
   - Добавить `-Os`, `-fno-exceptions`, `-fno-rtti`
   - Экономия: ~75-100 KB
   
2. ✅ **Отключить CORE_DEBUG_LEVEL**
   - Изменить с 4 на 2
   - Экономия: ~20 KB
   
3. ✅ **Проверить и удалить неиспользуемые библиотеки**
   - EEPROM, Update
   - Экономия: ~50 KB

**Итого за 2 часа**: ~145-170 KB экономии

---

### В течение недели (8-10 часов):

4. ✅ **Упростить SimpleCLI**
   - Заменить на легкий парсер
   - Экономия: ~30 KB
   
5. ✅ **Оптимизировать STL использование**
   - Заменить std::vector на статические массивы где возможно
   - Экономия: ~30-50 KB

**Итого за неделю**: +60-80 KB (Всего: ~205-250 KB)

---

### Если нужно больше (2-3 недели):

6. ⚠️ **Переписать BleAdapter на ESP-IDF API**
   - Отказаться от ESP32 BLE Arduino
   - Экономия: ~150-200 KB
   
**Итого максимум**: ~355-450 KB экономии

---

## 🎯 Рекомендуемая конфигурация

### platformio.ini (оптимизированный):

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
board_build.partitions = custom_partitions.csv

lib_deps = 
    spacehuhn/SimpleCLI@^1.1.4
    ESP32 BLE Arduino@^2.0.0

# МАКСИМАЛЬНАЯ ОПТИМИЗАЦИЯ РАЗМЕРА
build_flags = 
    # Debug level
    -DCORE_DEBUG_LEVEL=2                    # Только errors и warnings
    
    # Оптимизация размера
    -Os                                     # Size optimization
    -ffunction-sections
    -fdata-sections
    -Wl,--gc-sections
    
    # Отключить неиспользуемое
    -DARDUINO_USB_MODE=0
    -DARDUINO_USB_CDC_ON_BOOT=0
    -DDISABLE_ALL_LIBRARY_WARNINGS
    
    # C++ оптимизации
    -fno-exceptions                         # Нет C++ exceptions
    -fno-rtti                               # Нет RTTI
    -fno-threadsafe-statics                # Нет thread-safe статиков
    -fno-unwind-tables                      # Нет unwind tables
    -fno-asynchronous-unwind-tables
    
    # Дополнительно
    -fmerge-all-constants                   # Объединить константы
    -ffast-math                             # Быстрая математика
    
build_unflags = 
    -fexceptions
    -frtti
    -funwind-tables

# Отключить неиспользуемые библиотеки
lib_ignore = 
    Update                                  # Если OTA не нужен

monitor_speed = 115200
```

**Ожидаемый размер**: ~1,200,000 байт (76% Flash)  
**Экономия**: ~350 KB (22%)

---

## 📊 Сравнение вариантов

| Вариант | Размер | % Flash | Экономия | Сложность | Время |
|---------|--------|---------|----------|-----------|-------|
| **Текущий** | 1,554 KB | 98.8% | - | - | - |
| **Быстрая оптимизация** | 1,400 KB | 89% | 154 KB | Легко | 2 часа |
| **Средняя оптимизация** | 1,300 KB | 83% | 254 KB | Средне | 1 неделя |
| **Полная оптимизация** | 1,150 KB | 73% | 404 KB | Сложно | 3 недели |
| **ESP-IDF (максимум)** | 950 KB | 60% | 604 KB | Очень сложно | 2 месяца |

---

## ⚠️ Что НЕ рекомендуется трогать

1. **CC1101 библиотеку** - критична для работы
2. **SubGhz протоколы** - основной функционал
3. **SD/SPIFFS** - нужны для файлов
4. **FreeRTOS** - часть системы

---

## 🎓 Альтернативные решения

### Если оптимизация недостаточна:

#### 1. Изменить партиции (увеличить app0/app1):

**custom_partitions.csv**:
```csv
# Name,   Type, SubType, Offset,  Size, Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x1E0000,  # +384 KB (было 0x180000)
app1,     app,  ota_1,   0x1F0000,0x1E0000,  # +384 KB
coredump, data, coredump,0x3D0000,0x10000,
spiffs,   data, spiffs,  0x3E0000,0x20000,   # -384 KB (было 0x80000)
```

**Результат**: 
- app0/app1: по 1.9 MB (вместо 1.5 MB)
- SPIFFS: 128 KB (вместо 512 KB)

---

#### 2. Разделить прошивку на модули:

- **Core** (базовая функциональность): ~800 KB
- **Protocols** (SubGhz протоколы): ~300 KB (загружать с SD)
- **Advanced** (расширенные функции): ~200 KB (опционально)

---

## 💡 Практический пример

### Быстрая оптимизация (делаем СЕЙЧАС):

1. Открыть `platformio.ini`
2. Заменить `build_flags`:
```ini
build_flags = 
    -DCORE_DEBUG_LEVEL=2
    -Os
    -ffunction-sections
    -fdata-sections
    -Wl,--gc-sections
    -fno-exceptions
    -fno-rtti
```
3. Пересобрать: `python -m platformio run`
4. Проверить размер

**Ожидаемый результат**: ~1,400 KB (экономия 150 KB)

---

## 🎯 Заключение

### Рекомендуемый путь:

1. **Сегодня**: Применить быстрые оптимизации (build_flags) → **-150 KB**
2. **Эта неделя**: Упростить SimpleCLI, оптимизировать STL → **-80 KB**
3. **При необходимости**: Переписать BleAdapter → **-200 KB**

**Итого**: можно освободить **230-430 KB** без радикальных изменений.

---

**Следующий шаг**: Применить быстрые оптимизации? 🚀

















