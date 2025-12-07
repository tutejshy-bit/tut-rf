# Руководство по измерению использования стека задач ESP32

## 🎯 Зачем измерять стек?

При выделении слишком большого стека задачам:
- ❌ Расходуется драгоценная RAM напрасно
- ❌ Меньше памяти для других задач
- ❌ Может не хватить памяти для новых задач

При недостаточном стеке:
- 🔥 **Stack overflow** → crash устройства
- 🔥 Непредсказуемое поведение
- 🔥 Повреждение данных других задач

**Цель:** Найти оптимальный размер стека для каждой задачи.

## 📊 Как работает измерение

### Принцип работы

FreeRTOS использует **"stack painting"**:
1. При создании задачи весь стек заполняется паттерном `0xA5A5A5A5`
2. Во время работы задачи стек перезаписывается реальными данными
3. `uxTaskGetStackHighWaterMark()` сканирует стек и находит "самую глубокую" точку использования

```
Стек задачи (растет вниз):
┌─────────────────┐ ← Начало стека (высокий адрес)
│ 0xA5A5A5A5     │ ← Никогда не использовалось
│ 0xA5A5A5A5     │
│ 0xA5A5A5A5     │ ← "High water mark" - самое глубокое использование
├─────────────────┤
│ Real data      │ ← Использовано задачей
│ Local vars     │
│ Call stack     │
└─────────────────┘ ← Текущая позиция SP (низкий адрес)
```

### Что измеряется

**High Water Mark** - минимальное количество **неиспользованного** стека:
- Если HWM = 2000 байт → осталось 2000 байт свободного стека
- Чем меньше HWM, тем больше стек использовался

**Peak Stack Used** (в нашем коде):
```cpp
peakStackUsed = ALLOCATED_STACK - (minStackRemaining * sizeof(StackType_t))
```

## 🔬 Измерения в нашем коде

### Detector Task (DetectTask)

**Текущая аллокация:** 3072 байта

**Что мониторится:**
```cpp
void Detector::process(int module) {
    // 1. Измеряем начальное состояние
    UBaseType_t stackAtStart = uxTaskGetStackHighWaterMark(NULL);
    
    // 2. Отслеживаем минимум во время работы
    UBaseType_t minStackRemaining = stackAtStart;
    
    while (true) {
        // Каждые 10 итераций проверяем
        if (iterations % 10 == 0) {
            UBaseType_t current = uxTaskGetStackHighWaterMark(NULL);
            if (current < minStackRemaining) {
                minStackRemaining = current;  // Запоминаем новый минимум
            }
        }
        
        // Основная работа...
        detector.detectSignal(...);
    }
    
    // 3. Финальный отчет при завершении
    ESP_LOGI("Detector", "Peak used: %d bytes (%.1f%%)", ...);
}
```

**Пример вывода:**
```
[Detector] DetectTask started for module 0 - Stack allocated: 3072 bytes, unused at start: 3012 bytes
[Detector] Signal found, stopping DetectTask for module 0
[Detector] ===== DetectTask STACK USAGE REPORT (Module 0) =====
[Detector]   Allocated:     3072 bytes
[Detector]   Peak used:     856 bytes (27.9%)    ← Реальное использование!
[Detector]   Min remaining: 2216 bytes
[Detector]   Iterations:    15
[Detector]   💡 RECOMMENDATION: Stack usage is low (27.9%). Can reduce to ~1368 bytes
[Detector] =====================================================
```

### Recorder Task (RecordTask)

**Текущая аллокация:** 4096 байта

**Особенности:**
- Проверка каждые 100 итераций (реже, т.к. задача работает дольше)
- Больший safety margin (+768 байт вместо +512)
- Отслеживает пиковое использование при записи сигнала

**Пример вывода:**
```
[Recorder] RecordTask started for module 0 - Stack allocated: 4096 bytes
[Recorder] Module 0 signal complete: 150 samples collected, saving to file
[Recorder] ===== RecordTask STACK USAGE REPORT (Module 0) =====
[Recorder]   Allocated:     4096 bytes
[Recorder]   Peak used:     2340 bytes (57.1%)    ← Использовано больше
[Recorder]   Min remaining: 1756 bytes
[Recorder]   Iterations:    523
[Recorder]   ✅ Stack size is optimal (57.1% used)
[Recorder] =====================================================
```

## 📋 Как использовать для оптимизации

### Шаг 1: Соберите статистику

Запустите каждую задачу несколько раз в разных сценариях:

**Для DetectTask:**
- Запустите поиск сигнала на разных частотах
- С разными уровнями RSSI
- В background и single-shot режимах
- **Соберите 5-10 измерений**

**Для RecordTask:**
- Запишите сигналы разной длины (короткие и длинные)
- С разными модуляциями (ASK/OOK, FSK)
- При разных нагрузках системы
- **Соберите 10-15 измерений**

### Шаг 2: Найдите максимальное использование

Из всех измерений возьмите **наибольшее** значение "Peak used":

```
DetectTask измерения:
  Run 1: 856 bytes
  Run 2: 912 bytes  ← МАКСИМУМ
  Run 3: 784 bytes
  Run 4: 891 bytes
  Run 5: 823 bytes
```

### Шаг 3: Добавьте safety margin

**Рекомендованные margins:**
- Для простых задач (Detector): +512 байт (25-50% запас)
- Для сложных задач (Recorder): +768 байт (30-50% запас)
- Для задач с рекурсией: +1024 байт (50-100% запас)

**Расчет:**
```
DetectTask:
  Peak measured: 912 bytes
  Safety margin: 512 bytes
  Recommended:   1424 bytes
  
  Round up to:   1536 bytes (1.5 KB) ✅
```

### Шаг 4: Обновите код

**В main.cpp:**
```cpp
// Было:
static StackType_t detectTaskStacks[CC1101_NUM_MODULES][3072 / sizeof(StackType_t)];

// Стало (оптимизировано):
static StackType_t detectTaskStacks[CC1101_NUM_MODULES][1536 / sizeof(StackType_t)];
```

**В Detector.cpp:**
```cpp
// Обновить константу для отчетов:
const size_t ALLOCATED_STACK = 1536;  // Было 3072
```

### Шаг 5: Проверьте после изменений

После уменьшения стека **обязательно** проверьте:
1. ✅ Задача работает без ошибок
2. ✅ "Min remaining" > 256 байт (безопасный минимум)
3. ✅ Нет предупреждений "LOW STACK"
4. ✅ Peak usage < 80%

## ⚠️ Предупреждения и рекомендации

### Красные флаги 🚨

| Показатель | Значение | Что делать |
|------------|----------|------------|
| **Peak usage** | > 85% | 🔴 Увеличить стек на 50% |
| **Min remaining** | < 256 байт | 🔴 КРИТИЧНО! Увеличить немедленно |
| **LOW STACK warning** | Появляется | 🔴 Увеличить стек |
| **Stack overflow** | Crash | 🔴🔴🔴 Удвоить стек |

### Желтые флаги ⚠️

| Показатель | Значение | Что делать |
|------------|----------|------------|
| **Peak usage** | 70-85% | ⚠️ Добавить +512 байт |
| **Min remaining** | 256-512 байт | ⚠️ Добавить safety margin |
| **Разброс измерений** | > 30% | ⚠️ Тестировать больше сценариев |

### Зеленые показатели ✅

| Показатель | Значение | Оценка |
|------------|----------|--------|
| **Peak usage** | 50-70% | ✅ Оптимально |
| **Min remaining** | > 1024 байт | ✅ Отличный запас |
| **Стабильность** | Разброс < 20% | ✅ Предсказуемо |

### Общие правила

1. **Никогда не урезайте стек ниже измеренного пика!**
   ```
   Peak measured: 912 bytes
   New allocation: 800 bytes  ← ❌ ОПАСНО!
   ```

2. **Всегда оставляйте запас минимум 25%**
   ```
   Peak measured: 912 bytes
   Minimum safe:  1140 bytes (912 × 1.25)
   Recommended:   1424 bytes (912 + 512)
   ```

3. **Учитывайте worst-case сценарий**
   - Глубокая вложенность вызовов функций
   - Большие локальные переменные
   - Callbacks и прерывания
   - Рекурсия

4. **Тестируйте в реальных условиях**
   - При высокой загрузке системы
   - При низком уровне свободной памяти
   - При одновременной работе нескольких задач
   - В граничных случаях (максимум данных, ошибки и т.д.)

## 🔍 Расширенная диагностика

### Добавить проверку в runtime

Для production можно добавить периодическую проверку:

```cpp
// В main loop или отдельной задаче
void monitorAllTasks() {
    TaskHandle_t tasks[20];
    UBaseType_t taskCount = uxTaskGetNumberOfTasks();
    uxTaskGetSystemState(tasks, taskCount, NULL);
    
    for (int i = 0; i < taskCount; i++) {
        UBaseType_t hwm = uxTaskGetStackHighWaterMark(tasks[i]);
        if (hwm < 256) {
            ESP_LOGE("Monitor", "Task %s critically low stack: %d bytes!",
                     pcTaskGetName(tasks[i]), hwm * sizeof(StackType_t));
        }
    }
}
```

### Stack canary для debug builds

В `platformio.ini`:
```ini
build_flags =
    -DCONFIG_FREERTOS_CHECK_STACKOVERFLOW_CANARY
```

ESP32 автоматически обнаружит stack overflow и вызовет `vApplicationStackOverflowHook`.

## 📊 Ожидаемые результаты оптимизации

### Было (текущее состояние):
```
RecordTask: 4096 bytes × 2 modules = 8192 bytes
DetectTask: 3072 bytes × 2 modules = 6144 bytes
Total:                               14336 bytes (14 KB)
```

### Прогноз после измерений:

**Консервативная оценка:**
```
RecordTask: ~2560 bytes × 2 = 5120 bytes  (сохранил 3 KB)
DetectTask: ~1536 bytes × 2 = 3072 bytes  (сохранил 3 KB)
Total:                        8192 bytes   (8 KB)

Экономия: ~6 KB статической RAM (43%)
```

**Агрессивная оптимизация (если измерения позволят):**
```
RecordTask: ~2048 bytes × 2 = 4096 bytes  (сохранил 4 KB)
DetectTask: ~1280 bytes × 2 = 2560 bytes  (сохранил 3.5 KB)
Total:                        6656 bytes   (6.5 KB)

Экономия: ~7.7 KB статической RAM (54%)
```

## ✅ Чеклист оптимизации

- [ ] Собрать 5-10 измерений для DetectTask
- [ ] Собрать 10-15 измерений для RecordTask  
- [ ] Найти максимальное "Peak used" для каждой задачи
- [ ] Рассчитать новые размеры стеков с safety margin
- [ ] Обновить размеры в `main.cpp` и константы в задачах
- [ ] Протестировать все сценарии использования
- [ ] Убедиться что "Min remaining" > 256 байт
- [ ] Убедиться что "Peak usage" < 80%
- [ ] Задокументировать финальные размеры и причины
- [ ] Удалить отладочный код мониторинга (опционально)

---

**Важно:** Лучше иметь немного лишней RAM в стеке, чем рисковать stack overflow!

**Правило большого пальца:** Если сомневаешься - добавь +512 байт и спи спокойно 😴

