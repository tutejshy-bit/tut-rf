# 🔧 Исправление crash в getCurrentState()

**Проблема**: abort() при выполнении BLE команды getState (0x01)  
**Дата**: 2025-10-08  
**Критичность**: 🔴 ВЫСОКАЯ

---

## 🔍 Анализ crash

### Backtrace:
```
[BleAdapter] Processing message type: 0x01
[BleAdapter] Handling getState command

abort() was called at PC 0x401a8f0b on core 1
Backtrace: 0x40083bc1:0x3ffddcc0 0x40096a7d:0x3ffddce0 ...
```

### Причина:
Функция `getCurrentState()` в `src/Actions.cpp` выполняла:

1. **Аллокация вектора с -fno-exceptions**:
   ```cpp
   std::vector<byte> buffer(numSettingsRegisters);
   ```
   ⚠️ При нехватке памяти и `-fno-exceptions` → abort()!

2. **Множественные конкатенации String**:
   ```cpp
   response += hexBuf;  // 47 раз в цикле
   ```
   ⚠️ Может вызвать переполнение или реаллокации

3. **Большой размер ответа**:
   - 46 регистров × 6 символов = 276 символов на модуль
   - 2 модуля = 552+ символов
   - Превышает резервированный размер

---

## ✅ Примененные исправления

### Исправление 1: Статический буфер вместо vector

```cpp
// БЫЛО (crash):
std::vector<byte> buffer(numSettingsRegisters);

// СТАЛО (безопасно):
static byte regBuffer[0x2E + 1]; // Статический буфер
memset(regBuffer, 0, sizeof(regBuffer));
```

**Результат**: Нет динамических аллокаций → нет риска abort()

---

### Исправление 2: Возврат к ostringstream

```cpp
// String конкатенации опасны при больших объемах
// Вернулись к ostringstream но с защитой

std::ostringstream response;

// ... построение ответа ...

std::string responseStr = response.str();

// ДОБАВЛЕНА ПРОВЕРКА РАЗМЕРА:
if (responseStr.length() > 2048) {
    ESP_LOGW("Actions", "Response too large: %d bytes", responseStr.length());
    responseStr = "{\"error\":\"Response too large\"}";
}
```

**Результат**: Защита от переполнения

---

### Исправление 3: Добавлен include

```cpp
#include <iomanip>  // Для std::setw, std::setfill
```

**Результат**: Правильная компиляция hex манипуляторов

---

## 🧪 Тестирование

### После исправления нужно проверить:

1. **Базовый тест**:
   ```
   Команда: getState
   Ожидается: JSON с данными о модулях
   Не должно быть: abort() или reboot
   ```

2. **Stress test**:
   ```
   Отправить getState 100 раз подряд
   Проверить: нет утечек памяти
   ```

3. **Проверка размера**:
   ```cpp
   // Добавить в getCurrentState() для отладки:
   ESP_LOGI("Actions", "Response size: %d bytes", responseStr.length());
   ```

---

## 🔬 Альтернативное решение (если проблема остается)

Если crash продолжается, использовать **упрощенную версию**:

```cpp
void getCurrentState(Device::TaskGetState &task)
{
    // SIMPLIFIED VERSION - minimal data
    char response[512]; // Fixed size on stack
    
    snprintf(response, sizeof(response),
             "{\"device\":{\"freeHeap\":%d},\"cc1101\":[{\"id\":0,\"mode\":\"%s\"},{\"id\":1,\"mode\":\"%s\"}]}",
             ESP.getFreeHeap(),
             modeToString(cc1101Control[0].getCurrentMode().getMode()),
             modeToString(cc1101Control[1].getCurrentMode().getMode())
    );
    
    clients.enqueueMessage(NotificationType::State, std::string(response));
}
```

**Плюсы**:
- ✅ Минимальная память
- ✅ Нет динамических аллокаций
- ✅ Быстро и надежно

**Минусы**:
- ⚠️ Нет данных регистров CC1101
- ⚠️ Только базовая информация

---

## 📊 Размер ответа getState

### Расчет размера:

```
{                                           1 байт
  "device":{                               11 байт
    "freeHeap":100000                      20 байт
  },
  "cc1101":[                               11 байт
    {                                       5 байт
      "id":0,                               7 байт
      "settings":"                          14 байт
        XX XX XX XX ... (47 регистров)     ~282 байт (47 × 6)
      ",                                    2 байт
      "mode":"RecordSignal"                 24 байт
    },                                      3 байт
    {                                       5 байт
      "id":1,                               7 байт
      "settings":"...                       ~282 байт
      "mode":"Idle"                         14 байт
    }                                       3 байт
  ]                                         1 байт
}                                           1 байт
-------------------------------------------------
ИТОГО: ~650-700 байт для 2 модулей
```

**Вывод**: Размер в пределах нормы, но нужна защита от превышения!

---

## 🎯 Проверка после исправления

### Команды для тестирования:

```bash
# 1. Собрать
python -m platformio run

# 2. Загрузить
python -m platformio run --target upload

# 3. Мониторить
python -m platformio device monitor

# 4. Отправить getState через BLE
# (из мобильного приложения)

# 5. Проверить лог:
[BleAdapter] Processing message type: 0x01
[BleAdapter] Handling getState command
[Actions] Response size: XXX bytes
[ClientsManager] Message enqueued
# ← НЕ ДОЛЖНО БЫТЬ abort()!
```

---

## 🛡️ Дополнительные защиты

### 1. Лимит на размер очереди

```cpp
// В ClientsManager::enqueueMessage() добавить:
if (messageQueue.size() > MAX_QUEUE_SIZE) {
    ESP_LOGW("ClientsManager", "Queue full, dropping message");
    return false;
}
```

### 2. Watchdog для длинных операций

```cpp
void getCurrentState(Device::TaskGetState &task)
{
    // Feed watchdog
    esp_task_wdt_reset();
    
    // ... код функции ...
    
    esp_task_wdt_reset();
}
```

### 3. Memory check перед отправкой

```cpp
if (ESP.getFreeHeap() < 10000) {
    ESP_LOGW("Actions", "Low memory, sending simplified state");
    // Отправить упрощенную версию
    return;
}
```

---

## 📝 История изменений

### v1 (Original):
```cpp
std::stringstream response;
std::vector<byte> buffer(numSettingsRegisters);
// ❌ Crash при -fno-exceptions
```

### v2 (First optimization):
```cpp
String response;
response.reserve(...);
std::vector<byte> buffer(numSettingsRegisters);
// ❌ Crash - vector все еще проблема
```

### v3 (Current fix):
```cpp
std::ostringstream response;
static byte regBuffer[0x2E + 1];
// ✅ Статический буфер + проверка размера
```

---

## ✅ Статус

- [x] Проблема идентифицирована
- [x] Исправление применено
- [x] Код скомпилирован
- [ ] Тестирование на устройстве
- [ ] Подтверждение исправления

---

## 🎯 Следующие шаги

1. **Загрузить исправленную прошивку**
2. **Проверить команду getState через BLE**
3. **Убедиться что crash не повторяется**
4. **Если проблема остается** - использовать упрощенную версию

---

## 💡 Урок

**Проблема**: При использовании `-fno-exceptions` любая неудачная аллокация вызывает `abort()`.

**Решение**: 
- Использовать статические буферы где возможно
- Проверять capacity перед использованием динамической памяти
- Добавлять проверки размера ответов
- Иметь fallback на упрощенные версии

---

**Статус**: ✅ Исправлено, готово к тестированию  
**Файл**: `src/Actions.cpp` (функция `getCurrentState`)

















