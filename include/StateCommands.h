#ifndef StateCommands_h
#define StateCommands_h

#include "CommandHandler.h"
#include "DeviceTasks.h"
#include "ControllerAdapter.h"
#include "Request.h"
#include "esp_log.h"
#include "config.h"

class StateCommands {
public:
    // Регистрация всех команд состояния
    static void registerCommands(CommandHandler& handler) {
        ESP_LOGI("StateCommands", "Registering state commands");
        
        handler.registerCommand(0x01, handleGetState);
        handler.registerCommand(0x02, handleRequestScan);
        handler.registerCommand(0x03, handleRequestIdle);
        handler.registerCommand(0x13, handleSetTime);
        
        ESP_LOGI("StateCommands", "State commands registered successfully");
    }
    
private:
    // Получение состояния
    static bool handleGetState(const uint8_t* data, size_t len) {
        ESP_LOGI("StateCommands", "GetState");
        
        Device::TaskGetState task(true);
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Запрос сканирования
    static bool handleRequestScan(const uint8_t* data, size_t len) {
        if (len != sizeof(RequestScan)) {
            ESP_LOGW("StateCommands", "Invalid payload size for requestScan");
            return false;
        }
        
        RequestScan request;
        memcpy(&request, data, sizeof(RequestScan));
        
        if (!moduleExists(request.module)) {
            ESP_LOGE("StateCommands", "Invalid module number: %d", request.module);
            return false;
        }
        
        ESP_LOGI("StateCommands", "RequestScan: module=%d, minRssi=%d", request.module, request.minRssi);
        
        Device::TaskDetectSignalBuilder taskBuilder;
        taskBuilder.setModule(request.module);
        taskBuilder.setMinRssi(request.minRssi);
        
        Device::TaskDetectSignal task = taskBuilder.build();
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Запрос перехода в режим ожидания
    static bool handleRequestIdle(const uint8_t* data, size_t len) {
        if (len < 1) {
            ESP_LOGW("StateCommands", "Insufficient data for requestIdle");
            return false;
        }
        
        uint8_t module = data[0];
        
        if (!moduleExists(module)) {
            ESP_LOGE("StateCommands", "Invalid module number: %d", module);
            return false;
        }
        
        ESP_LOGI("StateCommands", "RequestIdle: module=%d", module);
        
        Device::TaskIdle task(module);
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Установка времени (Unix timestamp в секундах, 4 байта little-endian)
    static bool handleSetTime(const uint8_t* data, size_t len) {
        if (len < 4) {
            ESP_LOGW("StateCommands", "Insufficient data for setTime");
            return false;
        }
        
        // Читаем Unix timestamp (little-endian)
        uint32_t timestamp = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        
        // Устанавливаем глобальное время
        extern uint32_t deviceTime;
        deviceTime = timestamp;
        
        ESP_LOGI("StateCommands", "Time set to: %lu (Unix timestamp)", (unsigned long)timestamp);
        
        return true;
    }
    
    // Проверка существования модуля
    static bool moduleExists(uint8_t module) {
        return module < CC1101_NUM_MODULES;
    }
};

#endif
