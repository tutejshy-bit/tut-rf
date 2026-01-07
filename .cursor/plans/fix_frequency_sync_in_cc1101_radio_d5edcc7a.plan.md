---
name: Fix frequency sync in CC1101_Radio
overview: "Исправление проблемы рассинхронизации частоты в библиотеке CC1101_Radio: методы Calibrate() и setPA() используют устаревшее значение MHz[currentModule] вместо реальной частоты из регистров чипа."
todos:
  - id: optimize_getfrequency
    content: Оптимизировать getFrequency() для использования SpiReadBurstReg вместо трёх отдельных SpiReadReg
    status: completed
  - id: fix_calibrate
    content: Изменить Calibrate() для чтения частоты из регистров через getFrequency() вместо MHz[currentModule]
    status: completed
    dependencies:
      - optimize_getfrequency
  - id: fix_setpa
    content: Изменить setPA() для чтения частоты из регистров через getFrequency() вместо MHz[currentModule]
    status: completed
    dependencies:
      - optimize_getfrequency
---

# Исправление синхронизации частоты в CC1101_Radio

## Проблема

В библиотеке `CC1101_Radio` методы `Calibrate()` и `setPA()` используют переменную `MHz[currentModule] `для определения частоты. Если частота задаётся напрямую через регистры (например, при применении пресетов в `setTxWithPreset()`), эта переменная не обновляется, что приводит к:

- Неверной калибровке частоты
- Неправильному выбору PA таблицы

## Решение

Использовать метод `getFrequency()`, который читает реальную частоту из регистров `FREQ2`, `FREQ1`, `FREQ0`, вместо переменной `MHz[currentModule]`.

## Изменения

### 1. Оптимизация `getFrequency()` в [lib/cc1101/CC1101_Radio.cpp](lib/cc1101/CC1101_Radio.cpp)

**Текущий код (строки 1394-1402):**

```1394:1402:lib/cc1101/CC1101_Radio.cpp
float CC1101_Radio::getFrequency()
{
    byte freq2 = SpiReadReg(CC1101_FREQ2);
    byte freq1 = SpiReadReg(CC1101_FREQ1);
    byte freq0 = SpiReadReg(CC1101_FREQ0);

    unsigned long freq = ((unsigned long)freq2 << 16) | ((unsigned long)freq1 << 8) | (unsigned long)freq0;
    return (float)freq * 26.0 / (1 << 16);
}
```

**Изменение:** Использовать `SpiReadBurstReg` для чтения всех трёх регистров за одну транзакцию:

```cpp
float CC1101_Radio::getFrequency()
{
    byte freqBytes[3];
    SpiReadBurstReg(CC1101_FREQ2, freqBytes, 3);  // Читаем FREQ2, FREQ1, FREQ0 за одну транзакцию
    
    unsigned long freq = ((unsigned long)freqBytes[0] << 16) | ((unsigned long)freqBytes[1] << 8) | (unsigned long)freqBytes[2];
    return (float)freq * 26.0 / (1 << 16);
}
```

**Преимущества оптимизации:**

- Меньше SPI транзакций (1 вместо 3)
- Быстрее выполнение
- Меньше накладных расходов на управление SPI

### 2. Исправление `Calibrate()` в [lib/cc1101/CC1101_Radio.cpp](lib/cc1101/CC1101_Radio.cpp)

**Текущий код (строка 544):**

```542:544:lib/cc1101/CC1101_Radio.cpp
void CC1101_Radio::Calibrate(void){

float mhz = MHz[currentModule];
```

**Изменение:** Заменить чтение из переменной на чтение из регистров:

```cpp
void CC1101_Radio::Calibrate(void){
    float mhz = getFrequency();  // Читаем реальную частоту из регистров
```

### 3. Исправление `setPA()` в [lib/cc1101/CC1101_Radio.cpp](lib/cc1101/CC1101_Radio.cpp)

**Текущий код (строка 454):**

```450:454:lib/cc1101/CC1101_Radio.cpp
void CC1101_Radio::setPA(int p)
{
int a;
pa[currentModule] = p;
float mhz = MHz[currentModule];
```

**Изменение:** Заменить чтение из переменной на чтение из регистров:

```cpp
void CC1101_Radio::setPA(int p)
{
    int a;
    pa[currentModule] = p;
    float mhz = getFrequency();  // Читаем реальную частоту из регистров
```

## Преимущества

1. **Точность**: Всегда используется актуальная частота из чипа
2. **Надёжность**: Работает корректно даже при прямом изменении регистров
3. **Минимальные изменения**: Используется существующий метод `getFrequency()`
4. **Обратная совместимость**: Не ломает существующий код, использующий `setMHZ()`

## Дополнительные соображения

- Оптимизация `getFrequency()` с использованием `SpiReadBurstReg` улучшает производительность (1 транзакция вместо 3)
- Регистры FREQ2, FREQ1, FREQ0 идут подряд (0x0D, 0x0E, 0x0F), что позволяет использовать burst read
- Переменная `MHz[currentModule]` остаётся для обратной совместимости, но не используется в критических методах
- Все изменения сохраняют обратную совместимость с существующим кодом