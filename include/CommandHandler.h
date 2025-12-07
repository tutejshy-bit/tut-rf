#ifndef CommandHandler_h
#define CommandHandler_h

#include <Arduino.h>
#include <map>
#include <functional>
#include <stdint.h>

class CommandHandler {
public:
    using CommandFunc = std::function<bool(const uint8_t*, size_t)>;
    
    // Регистрация команды
    void registerCommand(uint8_t id, CommandFunc func) {
        commands_[id] = func;
        ESP_LOGI("CommandHandler", "Registered command: 0x%02X", id);
    }
    
    // Выполнение команды
    bool executeCommand(uint8_t id, const uint8_t* data, size_t len) {
        auto it = commands_.find(id);
        if (it != commands_.end()) {
            ESP_LOGD("CommandHandler", "Executing command: 0x%02X", id);
            return it->second(data, len);
        }
        ESP_LOGW("CommandHandler", "Command not found: 0x%02X", id);
        return false;
    }
    
    // Проверка существования команды
    bool hasCommand(uint8_t id) const {
        return commands_.find(id) != commands_.end();
    }
    
    // Получение количества зарегистрированных команд
    size_t getCommandCount() const {
        return commands_.size();
    }
    
    // Отключение команды (для модульности)
    void disableCommand(uint8_t id) {
        commands_.erase(id);
        ESP_LOGI("CommandHandler", "Disabled command: 0x%02X", id);
    }

private:
    std::map<uint8_t, CommandFunc> commands_;
};

// Глобальный экземпляр
extern CommandHandler commandHandler;

#endif


