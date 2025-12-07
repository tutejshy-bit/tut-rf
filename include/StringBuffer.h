#ifndef StringBuffer_h
#define StringBuffer_h

#include <cstring>
#include <cstdio>
#include <cstdarg>

/**
 * Оптимизированный буфер для работы со строками на микроконтроллере
 * Использует статическую память вместо динамических аллокаций
 */
template<size_t MaxSize = 512>
class StringBuffer {
private:
    char buffer[MaxSize];
    size_t length;
    
public:
    StringBuffer() : length(0) {
        buffer[0] = '\0';
    }
    
    // Очистка буфера
    void clear() {
        length = 0;
        buffer[0] = '\0';
        // Очищаем весь буфер для безопасности (избегаем остатков старых данных)
        memset(buffer, 0, MaxSize);
    }
    
    // Добавление строки
    bool append(const char* str) {
        size_t strLen = strlen(str);
        if (length + strLen >= MaxSize) {
            return false; // Переполнение
        }
        strcpy(buffer + length, str);
        length += strLen;
        return true;
    }
    
    // Добавление строки с указанной длиной
    bool append(const char* str, size_t len) {
        if (length + len >= MaxSize) {
            return false; // Переполнение
        }
        strncpy(buffer + length, str, len);
        length += len;
        buffer[length] = '\0';
        return true;
    }
    
    // Добавление символа
    bool append(char c) {
        if (length + 1 >= MaxSize) {
            return false; // Переполнение
        }
        buffer[length] = c;
        buffer[length + 1] = '\0';
        length++;
        return true;
    }
    
    // Форматированный вывод
    bool printf(const char* format, ...) {
        va_list args;
        va_start(args, format);
        int result = vsnprintf(buffer + length, MaxSize - length, format, args);
        va_end(args);
        
        if (result < 0 || length + result >= MaxSize) {
            return false; // Переполнение
        }
        length += result;
        return true;
    }
    
    // Получение данных
    const char* c_str() const { return buffer; }
    size_t size() const { return length; }
    size_t capacity() const { return MaxSize; }
    bool empty() const { return length == 0; }
    
    // Операторы для совместимости
    operator const char*() const { return buffer; }
};

/**
 * Специализированные буферы для разных задач
 * ОПТИМИЗИРОВАНО: Уменьшены размеры для экономии памяти
 */
using JsonBuffer = StringBuffer<2048>;      // Для JSON ответов (уменьшено с 16KB до 2KB - достаточно для большинства ответов)
using PathBuffer = StringBuffer<128>;       // Для путей файлов
using LogBuffer = StringBuffer<256>;        // Для логов
using CommandBuffer = StringBuffer<64>;     // Для команд
using ChunkBuffer = StringBuffer<800>;      // Для streaming chunking (800B для CHUNK_SEND_SIZE)

#endif // StringBuffer_h

