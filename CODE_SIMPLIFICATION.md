# Упрощение кода после исправления пресетов

## Проблема

Ранее мы пытались исправить проблему с модуляцией, добавляя перезапись регистров PKTCTRL0 и MDMCFG2 после применения PA таблицы. Это было избыточно, так как проблема была в **неправильных значениях пресетов**, а не в порядке применения регистров.

## Что было исправлено

### До упрощения (`setTxWithPreset`):

1. Сохраняли значения PKTCTRL0 и MDMCFG2
2. Применяли пресет (записывали все регистры, включая PKTCTRL0 и MDMCFG2)
3. Применяли PA таблицу
4. **ПЕРЕЗАПИСЫВАЛИ** PKTCTRL0 и MDMCFG2 еще раз (избыточно!)

### После упрощения:

1. Применяем пресет (записываем все регистры один раз)
2. Применяем PA таблицу
3. Готово!

## Упрощенный код

```cpp
void ModuleCc1101::setTxWithPreset(float frequency, const uint8_t *presetBytes, int presetLength)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    delay(10);
    cc1101.Init();  // Reset all registers to defaults
    delay(10);
    
    // Set frequency first (before applying preset)
    cc1101.setMHZ(frequency);
    delay(10);
    
    // Apply preset configuration - presets now contain correct values
    if (presetBytes != nullptr && presetLength > 0) {
        int index = 0;
        
        // Apply all registers from preset
        while (index < presetLength) {
            uint8_t addr = presetBytes[index++];
            uint8_t value = presetBytes[index++];
            
            if (addr == 0x00 && value == 0x00) {
                break;
            }
            
            cc1101.SpiWriteReg(addr, value);
        }
        
        // Apply PA table (last 8 bytes)
        std::array<uint8_t, 8> paValue;
        std::copy(presetBytes + index, presetBytes + index + paValue.size(), paValue.begin());
        cc1101.SpiWriteBurstReg(CC1101_PATABLE, paValue.data(), paValue.size());
    }
    
    delay(10);
    cc1101.SetTx();
    xSemaphoreGive(rwSemaphore);
}
```

## Преимущества упрощения

1. **Меньше кода** - убрали ~20 строк избыточной логики
2. **Меньше операций записи** - регистры записываются один раз вместо двух
3. **Проще понять** - нет сложной логики сохранения и перезаписи
4. **Быстрее выполнение** - меньше SPI операций

## Вывод

Перезапись регистров после PA таблицы была **не нужна**. Проблема была в неправильных значениях MDMCFG2 в пресетах (все были 0x30 вместо правильных значений для 2FSK/MSK/GFSK). После исправления пресетов, достаточно просто применить их один раз.

