# Быстрая проверка стека - Шпаргалка

## 🚀 Что нужно сделать

### 1. Прошить код (уже содержит мониторинг)

Код уже обновлен и автоматически измеряет использование стека!

### 2. Запустить задачи несколько раз

**DetectTask:**
```
1. Откройте Serial Monitor (115200 baud)
2. Запустите детектор сигнала 5-10 раз
3. После каждого запуска смотрите отчет в логах
```

**RecordTask:**
```
1. Запишите несколько сигналов разной длины
2. После каждой записи смотрите отчет
3. Соберите 10-15 измерений
```

### 3. Найти в логах строки вида:

```
[Detector] ===== DetectTask STACK USAGE REPORT (Module 0) =====
[Detector]   Allocated:     3072 bytes
[Detector]   Peak used:     856 bytes (27.9%)    ← ЭТО ВАЖНО!
[Detector]   Min remaining: 2216 bytes
[Detector]   💡 RECOMMENDATION: Stack usage is low. Can reduce to ~1368 bytes
[Detector] =====================================================
```

### 4. Записать максимальное значение "Peak used"

Из 10 запусков DetectTask:
```
Run  1: Peak used: 856 bytes
Run  2: Peak used: 912 bytes  ← МАКСИМУМ
Run  3: Peak used: 784 bytes
Run  4: Peak used: 891 bytes
Run  5: Peak used: 823 bytes
Run  6: Peak used: 876 bytes
Run  7: Peak used: 901 bytes
Run  8: Peak used: 834 bytes
Run  9: Peak used: 867 bytes
Run 10: Peak used: 889 bytes

MAX = 912 bytes
```

### 5. Рассчитать новый размер

```
Формула: 
  New size = MAX(Peak used) + Safety margin
  
  Safety margin:
    - Простые задачи (Detector): +512 bytes
    - Сложные задачи (Recorder): +768 bytes

DetectTask:
  Peak:   912 bytes
  Margin: 512 bytes
  Total:  1424 bytes
  
  Round up to: 1536 bytes (для выравнивания)
```

### 6. Обновить код

**main.cpp** (строка ~65-69):
```cpp
// БЫЛО:
static StackType_t detectTaskStacks[CC1101_NUM_MODULES][3072 / sizeof(StackType_t)];

// СТАЛО:
static StackType_t detectTaskStacks[CC1101_NUM_MODULES][1536 / sizeof(StackType_t)];
```

**Detector.cpp** (строка ~24):
```cpp
const size_t ALLOCATED_STACK = 1536;  // Было 3072
```

**main.cpp** (строка ~189-197 в xTaskCreateStatic):
```cpp
cc1101Control->detectTaskHandle = xTaskCreateStatic(
    cc1101Control->getCurrentMode().onModeProcess,
    "DetectTask",
    1536 / sizeof(StackType_t),  // ← Изменить здесь
    // ...
);
```

### 7. Проверить после изменений

Запустить задачи снова и убедиться:
- ✅ "Peak usage" < 80%
- ✅ "Min remaining" > 256 bytes
- ✅ Нет ошибок или падений

## 📊 Интерпретация результатов

| Peak Usage % | Оценка | Действие |
|--------------|--------|----------|
| < 50% | 💚 Можно уменьшить | Отлично для оптимизации |
| 50-70% | 💚 Оптимально | Идеальный баланс |
| 70-80% | 💛 Приемлемо | Можно оставить так |
| 80-90% | 🟠 Высоко | Добавить +512 bytes |
| > 90% | 🔴 ОПАСНО | Увеличить на 50-100% |

| Min Remaining | Оценка | Действие |
|---------------|--------|----------|
| > 1024 bytes | 💚 Отлично | Запас большой |
| 512-1024 bytes | 💚 Хорошо | Нормальный запас |
| 256-512 bytes | 💛 Минимум | Осторожно, на грани |
| < 256 bytes | 🔴 КРИТИЧНО | Срочно увеличить! |

## 🎯 Ожидаемые результаты

**DetectTask:**
- Текущий размер: 3072 bytes
- Ожидаемое использование: ~800-1200 bytes
- Рекомендуемый размер: **1536 bytes** (экономия 1.5 KB на модуль)

**RecordTask:**
- Текущий размер: 4096 bytes  
- Ожидаемое использование: ~2000-2800 bytes
- Рекомендуемый размер: **2560-3072 bytes** (экономия 1-1.5 KB на модуль)

**Общая экономия:** ~5-7 KB статической RAM (35-50%)

## ⚠️ Важные напоминания

1. **Всегда используйте MAX из всех измерений**, не среднее!
2. **Обязательно добавляйте safety margin** (+512 или +768 bytes)
3. **Тестируйте все сценарии** (разные модуляции, частоты, длины сигнала)
4. **После изменений проверяйте** что задачи работают корректно
5. **В случае сомнений** лучше оставить больший стек

## 💡 Быстрые команды

**Фильтр логов для DetectTask:**
```bash
# На Linux/Mac
cat serial.log | grep "DetectTask STACK"

# На Windows PowerShell  
Select-String -Path serial.log -Pattern "DetectTask STACK"
```

**Найти максимум в логах:**
```bash
# Linux/Mac
grep "Peak used:" serial.log | grep "DetectTask" | sort -n -k4 | tail -1

# Вручную - просто найти наибольшее число :)
```

## 📝 Шаблон для записи результатов

```
=== DetectTask Measurements ===
Run  1: Peak used: ___ bytes
Run  2: Peak used: ___ bytes
Run  3: Peak used: ___ bytes
Run  4: Peak used: ___ bytes
Run  5: Peak used: ___ bytes
...
Run 10: Peak used: ___ bytes

MAX: ___ bytes
New size: MAX + 512 = ___ bytes
Rounded: ___ bytes

=== RecordTask Measurements ===
Run  1: Peak used: ___ bytes
Run  2: Peak used: ___ bytes
...
Run 15: Peak used: ___ bytes

MAX: ___ bytes
New size: MAX + 768 = ___ bytes
Rounded: ___ bytes

=== Total Savings ===
Before: 14 KB (3072×2 + 4096×2)
After:  ___ KB
Saved:  ___ KB
```

---

**Время на все:** ~30 минут  
**Результат:** Экономия 5-7 KB RAM + понимание реальных требований задач!

