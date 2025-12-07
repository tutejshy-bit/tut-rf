#ifndef MemoryConfig_h
#define MemoryConfig_h

#include <cstddef>

/**
 * @brief Централизованные константы для управления памятью и ресурсами ESP32
 * 
 * Этот файл содержит все магические числа вынесенные в именованные константы
 * для улучшения читаемости и упрощения настройки параметров системы.
 */

namespace Memory {
    // Минимальные уровни свободной памяти (в байтах)
    constexpr size_t MIN_FREE_HEAP_FOR_FILE_OPS = 3000;   // 3KB - для операций с файлами
    constexpr size_t MIN_SAFE_HEAP = 8000;                // 8KB - безопасный минимум
    constexpr size_t CRITICAL_HEAP_LEVEL = 2000;          // 2KB - критический уровень
    constexpr size_t MIN_HEAP_FOR_BINARY_LISTING = 5000;  // 5KB - для бинарного листинга
    constexpr size_t MIN_HEAP_FOR_FILE_LISTING = 4000;    // 4KB - для листинга файлов
}

namespace FileSystem {
    // Лимиты файловой системы
    constexpr size_t MAX_FILES_PER_LISTING = 100;         // Максимум файлов в листинге
    constexpr size_t MAX_FILES_PER_DIR = 30;              // Максимум файлов на директорию
    constexpr size_t MAX_PATH_LENGTH = 256;               // Максимальная длина пути
    constexpr size_t MAX_FILENAME_LENGTH = 255;           // Максимальная длина имени файла
    constexpr int MAX_RECURSION_DEPTH = 5;                // Глубина рекурсии для директорий
    constexpr size_t MAX_FILES_BINARY_LISTING = 1000;     // Максимум для бинарного формата
}

namespace BLE {
    // Константы BLE протокола
    constexpr uint8_t MAGIC_BYTE = 0xAA;                  // Магический байт для валидации
    constexpr uint8_t MAX_CHUNK_SIZE = 100;               // Максимальный размер чанка (байт)
    constexpr uint8_t PACKET_HEADER_SIZE = 6;             // Размер заголовка пакета
    constexpr size_t MAX_RESPONSE_SIZE = 2048;            // Максимальный размер ответа
    constexpr size_t MAX_PACKET_SIZE = PACKET_HEADER_SIZE + MAX_CHUNK_SIZE + 1; // +1 для checksum
    constexpr size_t MAX_FILES_PER_BLE_PACKET = 15;       // Файлов на BLE пакет
}

namespace Recording {
    // Константы для записи сигналов
    constexpr unsigned long MAX_SIGNAL_DURATION = 100000; // 100ms - максимальная длительность
    constexpr unsigned long MIN_PULSE_DURATION = 50;      // 50µs - минимальная длительность импульса
    constexpr size_t MIN_SAMPLE = 10;                     // Минимум сэмплов для валидного сигнала
    constexpr size_t MAX_SAMPLES = 10000;                 // Максимум сэмплов для предотвращения overflow
    constexpr unsigned long CLEANUP_INTERVAL = 30000;     // 30 секунд - интервал очистки памяти
    constexpr size_t SAMPLE_SIZE = 2048;                  // Размер буфера сэмплов
}

namespace Tasks {
    // Размеры стеков для FreeRTOS задач (в байтах)
    constexpr size_t STACK_SIZE_CC1101_STATE = 8192;      // 8KB для задачи состояния CC1101
    constexpr size_t STACK_SIZE_TASK_PROCESSOR = 25600;   // 25KB для процессора задач
    constexpr size_t STACK_SIZE_NOTIFICATIONS = 8192;     // 8KB для уведомлений
    constexpr size_t STACK_SIZE_SERIAL = 4096;            // 4KB для Serial
    constexpr size_t STACK_SIZE_DETECT = 4096;            // 4KB для детектирования
    constexpr size_t STACK_SIZE_RECORD = 8192;            // 8KB для записи
}

namespace Buffers {
    // Размеры буферов для различных операций
    constexpr size_t SMALL_BUFFER_SIZE = 256;             // Малый буфер (пути, имена)
    constexpr size_t MEDIUM_BUFFER_SIZE = 512;            // Средний буфер
    constexpr size_t LARGE_BUFFER_SIZE = 2048;            // Большой буфер
    constexpr size_t JSON_RESPONSE_SIZE = 256;            // Буфер для JSON ответов
    constexpr size_t HEX_FORMAT_BUFFER = 8;               // Буфер для hex форматирования
}

namespace Timing {
    // Таймауты и задержки (в миллисекундах)
    constexpr unsigned long BLE_CHUNK_DELAY = 10;         // Задержка между BLE чанками
    constexpr unsigned long BLE_RECONNECT_DELAY = 500;    // Задержка перед переподключением
    constexpr unsigned long TASK_DELAY_SHORT = 10;        // Короткая задержка задачи
    constexpr unsigned long TASK_DELAY_MEDIUM = 100;      // Средняя задержка задачи
    constexpr unsigned long FILE_RETRY_DELAY = 100;       // Задержка перед повтором файловой операции
    constexpr int MAX_FILE_RETRIES = 3;                   // Максимум попыток файловых операций
}

#endif // MemoryConfig_h

















