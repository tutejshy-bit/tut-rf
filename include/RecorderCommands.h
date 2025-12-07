#ifndef RecorderCommands_h
#define RecorderCommands_h

#include "CommandHandler.h"
#include "DeviceTasks.h"
#include "ControllerAdapter.h"
#include "esp_log.h"
#include "config.h"
#include <cstring>
#include <sstream>
#include <vector>
#include "ModuleCc1101.h"

// Forward declaration
class Recorder;

class RecorderCommands {
public:
    // Регистрация всех команд записи
    static void registerCommands(CommandHandler& handler) {
        ESP_LOGI("RecorderCommands", "Registering recorder commands");
        
        handler.registerCommand(0x08, handleRequestRecord);
        
        ESP_LOGI("RecorderCommands", "Recorder commands registered successfully");
    }
    
private:
    // Запрос записи
    static bool handleRequestRecord(const uint8_t* data, size_t len) {
        if (len < 68) {
            ESP_LOGW("RecorderCommands", "Insufficient data for requestRecord: %zu bytes", len);
            return false;
        }
        
        // Parse RequestRecord struct (68 bytes)
        int offset = 0;
        
        // frequency (4 bytes)
        float frequency;
        memcpy(&frequency, data + offset, 4);
        offset += 4;
        
        // preset (50 bytes) - null-terminated UTF-8 string
        char presetStr[51];
        memset(presetStr, 0, sizeof(presetStr));
        memcpy(presetStr, data + offset, 50);
        offset += 50;
        
        // Extract preset string (null-terminated, UTF-8)
        // Find null terminator to get actual string length
        size_t presetLen = strnlen(presetStr, 50);
        std::string presetString(presetStr, presetLen);
        
        // Trim whitespace from preset string
        presetString.erase(0, presetString.find_first_not_of(" \t\n\r"));
        presetString.erase(presetString.find_last_not_of(" \t\n\r") + 1);
        
        // module (1 byte)
        uint8_t module = data[offset];
        offset += 1;
        
        // modulation (1 byte)
        uint8_t modulation = data[offset];
        offset += 1;
        
        // deviation (4 bytes)
        float deviation;
        memcpy(&deviation, data + offset, 4);
        offset += 4;
        
        // rxBandwidth (4 bytes)
        float rxBandwidth;
        memcpy(&rxBandwidth, data + offset, 4);
        offset += 4;
        
        // dataRate (4 bytes)
        float dataRate;
        memcpy(&dataRate, data + offset, 4);
        
        ESP_LOGI("RecorderCommands", "RequestRecord: module=%d, freq=%.2f, mod=%d, dev=%.2f, bw=%.2f, rate=%.2f, preset='%s'", 
                 module, frequency, modulation, deviation, rxBandwidth, dataRate, presetStr);
        
        Device::TaskRecordBuilder builder(frequency);
        builder.setModule(module)
               .setModulation(modulation)
               .setDeviation(deviation)
               .setRxBandwidth(rxBandwidth)
               .setDataRate(dataRate);
        
        // Only set preset if it's not empty
        if (!presetString.empty()) {
            builder.setPreset(presetString);
        }
        
        Device::TaskRecord task = builder.build();
        
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Запись сигнала
    static bool handleRecordSignal(const uint8_t* data, size_t len) {
        if (len < 1) {
            ESP_LOGW("RecorderCommands", "Insufficient data for recordSignal");
            return false;
        }
        
        uint8_t module = data[0];
        
        ESP_LOGI("RecorderCommands", "RecordSignal: module=%d", module);
        
        Device::TaskRecord task = Device::TaskRecordBuilder(433.92f)
            .setModule(module)
            .build();
        
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Переход в режим ожидания
    static bool handleIdle(const uint8_t* data, size_t len) {
        if (len < 1) {
            ESP_LOGW("RecorderCommands", "Insufficient data for idle");
            return false;
        }
        
        uint8_t module = data[0];
        
        ESP_LOGI("RecorderCommands", "Idle: module=%d", module);
        
        Device::TaskIdle task(module);
        
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Получение состояния
    static bool handleGetState(const uint8_t* data, size_t len) {
        ESP_LOGI("RecorderCommands", "GetState");
        
        Device::TaskGetState task(true);
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
};

#endif
