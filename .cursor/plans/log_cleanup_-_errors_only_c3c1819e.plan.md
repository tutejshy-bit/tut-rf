---
name: Log Cleanup - Errors Only
overview: Удаление всех логов кроме критических ошибок (ESP_LOGE) для упрощения кода и уменьшения размера прошивки
todos:
  - id: cleanup_cc1101worker
    content: Удалить все ESP_LOGI, ESP_LOGW, ESP_LOGD из CC1101Worker.cpp, оставить только критические ESP_LOGE
    status: pending
  - id: cleanup_bleadapter
    content: Удалить все ESP_LOGI, ESP_LOGD из BleAdapter.cpp, оставить только критические ESP_LOGE
    status: pending
  - id: cleanup_filecommands
    content: Удалить все ESP_LOGI, ESP_LOGW, ESP_LOGD из FileCommands.h
    status: pending
  - id: cleanup_main
    content: Удалить все не-ESP_LOGE логи из main.cpp
    status: pending
  - id: cleanup_command_handlers
    content: Удалить все не-ESP_LOGE логи из StateCommands.h, RecorderCommands.h, TransmitterCommands.h
    status: pending
  - id: cleanup_other_files
    content: Удалить все не-ESP_LOGE логи из остальных файлов (FrequencyAnalyzer, StreamingSubFileParser, FlipperSubFile, CommandHandler, ModuleCc1101, ServiceMode, SubGhzProtocol)
    status: pending
  - id: verify_critical_logs
    content: Проверить, что оставшиеся ESP_LOGE действительно критичны и необходимы
    status: pending
    dependencies:
      - cleanup_cc1101worker
      - cleanup_bleadapter
      - cleanup_filecommands
      - cleanup_main
      - cleanup_command_handlers
      - cleanup_other_files
  - id: check_compilation
    content: Убедиться, что код компилируется после удаления логов
    status: pending
    dependencies:
      - verify_critical_logs
---

# Очистка логов - только критические ошибки

## Цель

Удалить все логи кроме критических ошибок (ESP_LOGE), чтобы:

- Упростить код
- Уменьшить размер прошивки
- Оставить только необходимые логи для диагностики критических проблем

## Стратегия

**Оставить:**

- `ESP_LOGE` - только критические ошибки (инициализация, сбои операций, которые требуют внимания)

**Удалить:**

- `ESP_LOGI` - информационные логи (все)
- `ESP_LOGW` - предупреждения (все)
- `ESP_LOGD` - отладочные логи (все)
- `Serial.print*` - если есть (проверить)

## Файлы для обработки

### Основные файлы (высокий приоритет)

1. **[src/CC1101Worker.cpp](src/CC1101Worker.cpp)**

   - Удалить: ~29 ESP_LOGI, ESP_LOGW, ESP_LOGD
   - Оставить: ~17 ESP_LOGE (критические ошибки инициализации и операций)

2. **[src/BleAdapter.cpp](src/BleAdapter.cpp)**

   - Удалить: ~7 ESP_LOGI, ESP_LOGD
   - Оставить: ~12 ESP_LOGE (ошибки инициализации BLE, сбои операций)

3. **[include/FileCommands.h](include/FileCommands.h)**

   - Удалить: ~19 ESP_LOGI, ESP_LOGW, ESP_LOGD
   - ESP_LOGE нет - все логи можно удалить

4. **[src/main.cpp](src/main.cpp)**

   - Проверить и удалить все ESP_LOGI, ESP_LOGW, ESP_LOGD
   - Оставить только критические ESP_LOGE

### Вспомогательные файлы

5. **[include/StateCommands.h](include/StateCommands.h)**

   - Удалить все ESP_LOGI, ESP_LOGW
   - Оставить ESP_LOGE если есть

6. **[include/RecorderCommands.h](include/RecorderCommands.h)**

   - Удалить все ESP_LOGI, ESP_LOGW
   - Оставить ESP_LOGE если есть

7. **[include/TransmitterCommands.h](include/TransmitterCommands.h)**

   - Удалить все ESP_LOGI, ESP_LOGW, ESP_LOGD
   - Оставить ESP_LOGE если есть

8. **[src/FrequencyAnalyzer.cpp](src/FrequencyAnalyzer.cpp)**

   - Удалить все логи кроме ESP_LOGE

9. **[src/StreamingSubFileParser.cpp](src/StreamingSubFileParser.cpp)**

   - Удалить все логи кроме ESP_LOGE

10. **[lib/generators/FlipperSubFile.cpp](lib/generators/FlipperSubFile.cpp)**

    - Удалить все логи кроме ESP_LOGE

11. **[include/CommandHandler.h](include/CommandHandler.h)**

    - Проверить и удалить все логи кроме ESP_LOGE

12. **[src/ModuleCc1101.cpp](src/ModuleCc1101.cpp)**

    - Проверить и удалить все логи кроме ESP_LOGE

13. **[src/ServiceMode.cpp](src/ServiceMode.cpp)**

    - Проверить и удалить все логи кроме ESP_LOGE

14. **[src/ProtocolDecoder.cpp](src/ProtocolDecoder.cpp)**

    - Удалить все логи (ProtocolDecoder планируется удалить)

15. **[lib/subghz/SubGhzProtocol.cpp](lib/subghz/SubGhzProtocol.cpp)**

    - Проверить и удалить все логи кроме ESP_LOGE

## Критерии для оставления ESP_LOGE

Оставить ESP_LOGE только для:

- Ошибок инициализации (task queue, mutex, BLE, SD card)
- Критических сбоев операций (открытие файлов, отправка данных)
- Ошибок, которые требуют немедленного внимания

Удалить ESP_LOGE для:

- Информационных сообщений об ошибках (можно заменить на return false)
- Повторяющихся ошибок в циклах (оставить только первую или последнюю)

## Проверка после очистки

1. Убедиться, что все ESP_LOGI, ESP_LOGW, ESP_LOGD удалены
2. Проверить, что оставшиеся ESP_LOGE действительно критичны
3. Убедиться, что код компилируется
4. Проверить, что нет неиспользуемых переменных после удаления логов

## Примеры изменений

### До:

```cpp
ESP_LOGI(TAG, "Starting detection on module %d", module);
ESP_LOGD(TAG, "Processing command %d", command);
ESP_LOGW(TAG, "Low stack: %d bytes", stack);
ESP_LOGE(TAG, "Failed to create task queue");
```

### После:

```cpp
// ESP_LOGI удален
// ESP_LOGD удален
// ESP_LOGW удален
ESP_LOGE(TAG, "Failed to create task queue"); // Оставлен
```