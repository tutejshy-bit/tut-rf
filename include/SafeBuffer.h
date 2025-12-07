#ifndef SafeBuffer_h
#define SafeBuffer_h

#include <cstddef>
#include <cstdlib>

/**
 * @brief RAII обертка для динамических буферов
 * 
 * Автоматически освобождает память при выходе из scope.
 * Предотвращает утечки памяти при исключениях или ранних return.
 * 
 * @tparam T Тип элементов буфера (по умолчанию uint8_t)
 * 
 * @example
 * void processData(size_t dataSize) {
 *     SafeBuffer<uint8_t> buffer(dataSize);
 *     if (!buffer.isValid()) {
 *         // Не хватило памяти
 *         return;
 *     }
 *     
 *     // Используем буфер
 *     memcpy(buffer.get(), source, dataSize);
 *     
 *     // Память автоматически освободится при выходе
 * }
 */
template<typename T = uint8_t>
class SafeBuffer {
private:
    T* buffer;
    size_t size;
    
public:
    /**
     * @brief Конструктор - выделяет память для буфера
     * @param count Количество элементов типа T
     */
    explicit SafeBuffer(size_t count) 
        : size(count), buffer(nullptr) {
        if (count > 0) {
            buffer = static_cast<T*>(malloc(count * sizeof(T)));
        }
    }
    
    /**
     * @brief Деструктор - автоматически освобождает память
     */
    ~SafeBuffer() {
        if (buffer) {
            free(buffer);
            buffer = nullptr;
        }
    }
    
    // Геттеры
    
    /**
     * @brief Получить указатель на буфер
     * @return Указатель на буфер или nullptr если аллокация не удалась
     */
    T* get() { return buffer; }
    
    /**
     * @brief Получить константный указатель на буфер
     * @return Константный указатель на буфер
     */
    const T* get() const { return buffer; }
    
    /**
     * @brief Получить размер буфера в элементах
     * @return Размер в элементах типа T
     */
    size_t getSize() const { return size; }
    
    /**
     * @brief Получить размер буфера в байтах
     * @return Размер в байтах
     */
    size_t getSizeBytes() const { return size * sizeof(T); }
    
    /**
     * @brief Проверить успешность аллокации
     * @return true если буфер выделен, false если нет памяти
     */
    bool isValid() const { return buffer != nullptr; }
    
    // Операторы доступа
    
    /**
     * @brief Оператор доступа по индексу
     * @param index Индекс элемента
     * @return Ссылка на элемент
     */
    T& operator[](size_t index) { 
        return buffer[index]; 
    }
    
    /**
     * @brief Константный оператор доступа по индексу
     * @param index Индекс элемента
     * @return Константная ссылка на элемент
     */
    const T& operator[](size_t index) const { 
        return buffer[index]; 
    }
    
    // Запрет копирования (только move)
    
    /**
     * @brief Удаленный конструктор копирования
     * 
     * Копирование запрещено для предотвращения двойного освобождения памяти.
     * Используйте move семантику если нужно передать владение.
     */
    SafeBuffer(const SafeBuffer&) = delete;
    
    /**
     * @brief Удаленный оператор присваивания
     */
    SafeBuffer& operator=(const SafeBuffer&) = delete;
    
    // Move семантика
    
    /**
     * @brief Move конструктор
     * 
     * Передает владение буфером от other к this.
     * После операции other становится пустым.
     * 
     * @param other Буфер для перемещения
     */
    SafeBuffer(SafeBuffer&& other) noexcept 
        : buffer(other.buffer), size(other.size) {
        other.buffer = nullptr;
        other.size = 0;
    }
    
    /**
     * @brief Move оператор присваивания
     * 
     * Передает владение буфером от other к this.
     * Текущий буфер освобождается, other становится пустым.
     * 
     * @param other Буфер для перемещения
     * @return Ссылка на this
     */
    SafeBuffer& operator=(SafeBuffer&& other) noexcept {
        if (this != &other) {
            // Освобождаем текущий буфер
            if (buffer) {
                free(buffer);
            }
            
            // Перемещаем от other
            buffer = other.buffer;
            size = other.size;
            
            // Очищаем other
            other.buffer = nullptr;
            other.size = 0;
        }
        return *this;
    }
    
    /**
     * @brief Вручную освободить буфер до выхода из scope
     * 
     * Полезно если нужно освободить память раньше времени.
     * После вызова isValid() вернет false.
     */
    void release() {
        if (buffer) {
            free(buffer);
            buffer = nullptr;
            size = 0;
        }
    }
};

/**
 * @brief Специализация для char* (удобно для строковых буферов)
 */
using CharBuffer = SafeBuffer<char>;

/**
 * @brief Специализация для uint8_t* (стандартные байтовые буферы)
 */
using ByteBuffer = SafeBuffer<uint8_t>;

#endif // SafeBuffer_h

















