#ifndef TransmitterCommands_h
#define TransmitterCommands_h

#include "StringBuffer.h"
#include "CommandHandler.h"
#include "ControllerAdapter.h"
#include "DeviceTasks.h"
#include "StringHelpers.h"
#include "ClientsManager.h"
#include "config.h"
#include "cstring"

/**
 * Команды передачи с использованием статических буферов
 */
class TransmitterCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x06, handleTransmitBinary);
        handler.registerCommand(0x07, handleTransmitFromFile);
        handler.registerCommand(0x11, handleFrequencySearch);
    }
    
private:
    // Статические буферы
    static JsonBuffer jsonBuffer;
    static PathBuffer pathBuffer;
    static CommandBuffer commandBuffer;
    
    // Передача из файла
    static bool handleTransmitFromFile(const uint8_t* data, size_t len) {
        ESP_LOGD("TransmitterCommands", "handleTransmitFromFile START, len=%zu", len);
        if (len < 2) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\\\"type\\\":\\\"SignalSendingError\\\",\\\"error\\\":\\\"Insufficient data\\\"}");
            ClientsManager::getInstance().enqueueMessage(NotificationType::SignalSendingError, jsonBuffer.c_str());
            return false;
        }
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\\\"type\\\":\\\"SignalSendingError\\\",\\\"error\\\":\\\"Data too short for path\\\"}");
            ClientsManager::getInstance().enqueueMessage(NotificationType::SignalSendingError, jsonBuffer.c_str());
            return false;
        }
        std::string filename(reinterpret_cast<const char*>(data + 2), pathLength);
        int module = -1;
        if (len > 2 + pathLength) {
            module = static_cast<int>(data[2 + pathLength]);
        }
        ESP_LOGD("TransmitterCommands", "Parsed filename='%s', pathType=%d, module=%d", filename.c_str(), pathType, module);
        Device::TaskTransmissionBuilder builder(Device::TransmissionType::File);
        builder.setFilename(filename);
        if (module >= 0 && module < CC1101_NUM_MODULES) {
            builder.setModule(module);
        }
        builder.setRepeat(1);
        builder.setPathType(pathType);
        Device::TaskTransmission task = builder.build();
        ESP_LOGD("TransmitterCommands", "Queue Device::TaskTransmission: file=%s, module=%d, pathType=%d", filename.c_str(), module, pathType);
        bool sent = ControllerAdapter::sendTask(std::move(task));
        if (!sent) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\\\"type\\\":\\\"SignalSendingError\\\",\\\"error\\\":\\\"Failed to post transmission task\\\",\\\"file\\\":\\\"%s\\\"}", filename.c_str());
            ClientsManager::getInstance().enqueueMessage(NotificationType::SignalSendingError, jsonBuffer.c_str());
        }
        return sent;
    }
    
    // Поиск частоты
    static bool handleFrequencySearch(const uint8_t* data, size_t len) {
        if (len < 3) {
            return false;
        }
        
        uint8_t module = data[0];
        uint8_t minRssiRaw = data[1];
        uint8_t isBackgroundRaw = data[2];
        
        // Конвертируем RSSI
        int16_t minRssi = minRssiRaw > 100 ? minRssiRaw - 256 : minRssiRaw;
        bool isBackground = isBackgroundRaw == 1;
        
        // Создаем задачу
        Device::TaskDetectSignal task = Device::TaskDetectSignalBuilder()
            .setModule(module)
            .setMinRssi(minRssi)
            .setIsBackground(isBackground)
            .build();
        
        ControllerAdapter::sendTask(std::move(task));
        return true;
    }
    
    // Передача бинарных данных
    static bool handleTransmitBinary(const uint8_t* data, size_t len) {
        // TODO: Implement binary transmission
        return true;
    }
};

// Статические буферы
JsonBuffer TransmitterCommands::jsonBuffer;
PathBuffer TransmitterCommands::pathBuffer;
CommandBuffer TransmitterCommands::commandBuffer;

#endif // TransmitterCommands_h
