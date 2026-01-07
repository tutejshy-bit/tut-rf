#include <Arduino.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h>
#include <sstream>
#include "CommandHandler.h"
#include "FileCommands.h"
#include "TransmitterCommands.h"
#include "RecorderCommands.h"
#include "StateCommands.h"
#include "AllProtocols.h"
#include "ClientsManager.h"
#include "ConfigManager.h"
#include "DeviceControls.h"
#include "FS.h"
#include "SD.h"
#include "SPI.h"
#include "ServiceMode.h"
#include "BleAdapter.h"
#include "config.h"
#include "esp_log.h"
#include "ModuleCc1101.h"
#include "BinaryMessages.h"
#include "CC1101Worker.h"

static const char* TAG = "Setup";

// Constants
const int MAX_RETRIES = 5;

// Global variables
bool bleAdapterStarted = false;
BleAdapter bleAdapter;

// Device time (Unix timestamp in seconds, updated by time sync task)
uint32_t deviceTime = 0;

SPIClass sdspi(VSPI);

// REMOVED - old static task buffers (no longer needed with worker architecture)
// CC1101Worker uses its own static allocation

// Forward declarations
void signalRecordedHandler(bool saved, const std::string& filename);
void timeSyncTask(void* pvParameters);

// Heap monitoring helper
void logHeapStats(const char* context) {
    size_t freeHeap = ESP.getFreeHeap();
    size_t largestBlock = heap_caps_get_largest_free_block(MALLOC_CAP_DEFAULT);
    size_t minFreeHeap = ESP.getMinFreeHeap();
    
    // Calculate fragmentation percentage
    float fragmentation = 0.0f;
    if (freeHeap > 0) {
        fragmentation = 100.0f * (1.0f - (float)largestBlock / (float)freeHeap);
    }
    
    ESP_LOGI("Heap", "[%s] Free: %d, Largest: %d, MinFree: %d, Frag: %.1f%%",
             context, freeHeap, largestBlock, minFreeHeap, fragmentation);
    
    // Warning if fragmentation is high
    if (fragmentation > 30.0f) {
        ESP_LOGW("Heap", "High fragmentation detected: %.1f%%", fragmentation);
    }
    
    // Warning if largest block is smaller than task stack sizes
    if (largestBlock < 4096) {
        ESP_LOGW("Heap", "Largest block (%d) < RecordTask stack (4096) - would fail with dynamic allocation!", largestBlock);
    }
    if (largestBlock < 3072) {
        ESP_LOGW("Heap", "Largest block (%d) < DetectTask stack (3072) - would fail with dynamic allocation!", largestBlock);
    }
}

// Global objects (moved from Actions.cpp)
ClientsManager& clients = ClientsManager::getInstance();

// REMOVED: deviceModes - no longer needed with worker architecture
// Cc1101Mode deviceModes[] = {...};

// Handler functions (moved from Actions.cpp)
void signalRecordedHandler(bool saved, const std::string& filename)
{
    if (saved) {
        BinarySignalRecorded msg;
        msg.module = 0; // Default
        msg.filenameLength = (uint8_t)std::min((size_t)255, filename.length());
        
        static uint8_t buffer[260];
        memcpy(buffer, &msg, sizeof(BinarySignalRecorded));
        memcpy(buffer + sizeof(BinarySignalRecorded), filename.c_str(), msg.filenameLength);
        
        clients.notifyAllBinary(NotificationType::SignalRecorded, buffer, sizeof(BinarySignalRecorded) + msg.filenameLength);
    } else {
        // Send as binary error
        static uint8_t errBuffer[260];
        errBuffer[0] = MSG_ERROR;
        errBuffer[1] = 10; // Error code for record failed
        std::string errMsg = "Failed to save file: " + filename;
        uint8_t msgLen = (uint8_t)std::min((size_t)255, errMsg.length());
        memcpy(errBuffer + 2, errMsg.c_str(), msgLen);
        clients.notifyAllBinary(NotificationType::FileSystem, errBuffer, 2 + msgLen);
    }
}

// Adapter for CC1101Worker detected signal callback
void cc1101WorkerSignalDetectedHandler(const CC1101DetectedSignal& signal)
{
    ESP_LOGI("Main", "Signal detected: rssi=%d, freq=%.2f, module=%d", 
             signal.rssi, signal.frequency, signal.module);
    
    BinarySignalDetected msg;
    msg.module = signal.module;
    msg.frequency = (uint32_t)(signal.frequency * 1000000); // MHz to Hz
    msg.rssi = signal.rssi;
    msg.samples = 0;
    
    clients.notifyAllBinary(NotificationType::SignalDetected, reinterpret_cast<const uint8_t*>(&msg), sizeof(BinarySignalDetected));
}

// REMOVED - signalDetectedHandler (Detector functionality moved to CC1101Worker)

// REMOVED - old state machine callback
// void onStateChange(int module, OperationMode mode, OperationMode previousMode) { }

// BLE parameters - no longer needed

// Device settings
struct DeviceConfig
{
    bool powerBlink;
} deviceConfig;

// REMOVED - old state machine task (all code deleted, now using CC1101Worker)

void taskProcessor(void* pvParameters)
{
    if (ControllerAdapter::xTaskQueue == nullptr) {
        ESP_LOGE(TAG, "Task queue not found");
        vTaskDelete(nullptr);  // Remove task
    }
    QueueItem* item;
    while (true) {
        if (xQueueReceive(ControllerAdapter::xTaskQueue, &item, portMAX_DELAY)) {
            switch (item->type) {
                case Device::TaskType::Transmission: {
                    Device::TaskTransmission& task = item->transmissionTask;
                    ESP_LOGI(TAG, "Processing transmission task for module %d", task.module);
                    
                    if (task.filename) {
                        // Send command to CC1101Worker
                        int repeat = task.repeat ? *task.repeat : 1;
                        if (CC1101Worker::transmit(task.module, *task.filename, repeat, task.pathType)) {
                            BinarySignalSent msg;
                            msg.module = task.module;
                            msg.filenameLength = (uint8_t)std::min((size_t)255, task.filename->length());
                            
                            static uint8_t buffer[260];
                            memcpy(buffer, &msg, sizeof(BinarySignalSent));
                            memcpy(buffer + sizeof(BinarySignalSent), task.filename->c_str(), msg.filenameLength);
                            clients.notifyAllBinary(NotificationType::SignalSent, buffer, sizeof(BinarySignalSent) + msg.filenameLength);
                        } else {
                            BinarySignalSendError msg;
                            msg.module = task.module;
                            msg.errorCode = 1; // Failed to queue
                            msg.filenameLength = (uint8_t)std::min((size_t)255, task.filename->length());
                            
                            static uint8_t buffer[260];
                            memcpy(buffer, &msg, sizeof(BinarySignalSendError));
                            memcpy(buffer + sizeof(BinarySignalSendError), task.filename->c_str(), msg.filenameLength);
                            clients.notifyAllBinary(NotificationType::SignalSendingError, buffer, sizeof(BinarySignalSendError) + msg.filenameLength);
                        }
                    } else {
                        // Raw transmission
                        ESP_LOGI(TAG, "Raw transmission not implemented yet");
                    }
                } break;
                
                case Device::TaskType::Record: {
                    Device::TaskRecord& task = item->recordTask;
                    ESP_LOGI(TAG, "Processing record task for module %d", task.module ? *task.module : 0);
                    
                    if (task.module) {
                        int module = *task.module;
                        std::string errorMessage;
                        
                        float frequency = task.config.frequency;
                        int modulation = MODULATION_ASK_OOK;
                        float deviation = 2.380371;
                        float bandwidth = 650;
                        float dataRate = 3.79372;
                        std::string preset = "Ook650";
                        
                        // Check if preset is provided
                        if (task.config.preset) {
                            preset = *task.config.preset;
                            ESP_LOGI(TAG, "Applying preset: '%s' (length=%zu)", preset.c_str(), preset.length());
                            
                            // Match presets exactly as sent from Flutter app
                            // Expected values: "Ook270", "Ook650", "2FSKDev238", "2FSKDev476"
                            if (preset == "Ook270") {
                                modulation = MODULATION_ASK_OOK;
                                deviation = 2.380371;
                                bandwidth = 270.833333;
                                dataRate = 3.79372;
                            } else if (preset == "Ook650") {
                                modulation = MODULATION_ASK_OOK;
                                deviation = 2.380371;
                                bandwidth = 650;
                                dataRate = 3.79372;
                            } else if (preset == "2FSKDev238") {
                                modulation = MODULATION_2_FSK;
                                deviation = 2.380371;
                                bandwidth = 270.833333;
                                dataRate = 4.79794;
                            } else if (preset == "2FSKDev476") {
                                modulation = MODULATION_2_FSK;
                                deviation = 47.60742;
                                bandwidth = 270.833333;
                                dataRate = 4.79794;
                            } else {
                                errorMessage = "{\"error\":\"Can not apply record configuration. Unsupported preset " + preset + "\"}";
                                ESP_LOGE(TAG, "Unsupported preset: %s", preset.c_str());
                            }
                        } else {
                            // Use custom parameters
                            modulation = task.config.modulation ? *task.config.modulation : MODULATION_ASK_OOK;
                            bandwidth = task.config.rxBandwidth ? *task.config.rxBandwidth : 650;
                            deviation = task.config.deviation ? *task.config.deviation : 47.60742;
                            dataRate = task.config.dataRate ? *task.config.dataRate : 4.79794;
                            preset = "Custom";
                        }
                        
                        if (errorMessage.empty()) {
                            // Send command to CC1101Worker
                            if (CC1101Worker::startRecord(module, frequency, modulation, deviation, bandwidth, dataRate, preset)) {
                                ESP_LOGI(TAG, "Recording started on module %d", module);
                            } else {
                                static uint8_t errBuffer[2];
                                errBuffer[0] = MSG_ERROR;
                                errBuffer[1] = 11; // Error code for record start failed
                                clients.notifyAllBinary(NotificationType::SignalRecordError, errBuffer, 2);
                            }
                        } else {
                            static uint8_t errBuffer[260];
                            errBuffer[0] = MSG_ERROR;
                            errBuffer[1] = 12; // Error code for preset application failed
                            uint8_t msgLen = (uint8_t)std::min((size_t)255, errorMessage.length());
                            memcpy(errBuffer + 2, errorMessage.c_str(), msgLen);
                            clients.notifyAllBinary(NotificationType::SignalRecordError, errBuffer, 2 + msgLen);
                        }
                    }
                } break;
                
                case Device::TaskType::DetectSignal: {
                    Device::TaskDetectSignal& task = item->detectSignalTask;
                    
                    if (task.module && task.minRssi) {
                        int minRssi = *task.minRssi;
                        int module = *task.module;
                        bool isBackground = task.background ? *task.background : false;
                        
                        // Send command to CC1101Worker
                        if (CC1101Worker::startDetect(module, minRssi, isBackground)) {
                            ESP_LOGI(TAG, "Detection started on module %d", module);
                        } else {
                            ESP_LOGE(TAG, "Failed to start detection on module %d", module);
                        }
                    }
                } break;
                
                case Device::TaskType::GetState: {
                    Device::TaskGetState& task = item->getStateTask;
                    ESP_LOGI(TAG, "Processing get state task");
                    
                    const byte numRegs = 0x2E;

                    // Create BinaryStatus structure with CC1101 registers
                    BinaryStatus status;
                    status.messageType = MSG_STATUS;
                    status.module0Mode = static_cast<uint8_t>(CC1101Worker::getState(0));
                    status.module1Mode = static_cast<uint8_t>(CC1101Worker::getState(1));
                    status.numRegisters = numRegs; // 0x00 to 0x2E (46 registers)
                    status.freeHeap = ESP.getFreeHeap();
                    
                    // Read all CC1101 registers for both modules
                    moduleCC1101State[0].readAllConfigRegisters(status.module0Registers, numRegs);
                    moduleCC1101State[1].readAllConfigRegisters(status.module1Registers, numRegs);
                    
                    // Send binary status
                    clients.notifyAllBinary(NotificationType::State, reinterpret_cast<const uint8_t*>(&status), sizeof(BinaryStatus));
                } break;
                
                case Device::TaskType::Jam: {
                    Device::TaskJam& task = item->jamTask;
                    ESP_LOGI(TAG, "Processing jam task for module %d", task.module);
                    
                    const std::vector<uint8_t>* customPatternPtr = task.customPattern ? task.customPattern.get() : nullptr;
                    
                    // Send command to CC1101Worker (power is already 0-7, no conversion needed)
                    if (CC1101Worker::startJam(task.module, task.frequency, task.power, 
                                               task.patternType, customPatternPtr, 
                                               task.maxDurationMs, task.cooldownMs)) {
                        ESP_LOGI(TAG, "Jam started on module %d", task.module);
                    } else {
                        ESP_LOGE(TAG, "Failed to start jam on module %d", task.module);
                    }
                } break;
                
                case Device::TaskType::Idle: {
                    Device::TaskIdle& task = item->idleTask;
                    ESP_LOGI(TAG, "Processing idle task for module %d", task.module);
                    
                    // Send command to CC1101Worker (it will handle jamming state internally)
                    if (CC1101Worker::goIdle(task.module)) {
                        ESP_LOGI(TAG, "Module %d set to idle", task.module);
                    } else {
                        ESP_LOGE(TAG, "Failed to set module %d to idle", task.module);
                    }
                } break;
                default:
                    break;
            }
            
            // CRITICAL: Delete the QueueItem after processing to prevent memory leak
            delete item;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void setup()
{
    ESP_LOGD(TAG, "Starting SPIFFS");
    if (!SPIFFS.begin(false)) {
        ESP_LOGW(TAG, "SPIFFS mount failed, attempting to format...");
        if (!SPIFFS.begin(true)) {
            ESP_LOGE(TAG, "SPIFFS format failed!");
            return;
        }
        ESP_LOGI(TAG, "SPIFFS formatted successfully");
    } else {
        ESP_LOGI(TAG, "SPIFFS mounted successfully");
    }

    String baudRate = ConfigManager::getConfigParam("serial_baud_rate");
    Serial.begin(baudRate.isEmpty() ? SERIAL_BAUDRATE : baudRate.toInt());

    ConfigManager::createDefaultConfig();

    DeviceControls::setup();
    DeviceControls::onLoadPowerManagement();
    DeviceControls::onLoadServiceMode();

    if (ConfigManager::isServiceMode()) {
        ServiceMode::serviceModeStart();
        return;
    }

    ESP_LOGD(TAG, "Starting setup...");

    sdspi.begin(SD_SCLK, SD_MISO, SD_MOSI, SD_SS);
    if (!SD.begin(SD_SS, sdspi)) {
        ESP_LOGE(TAG, "Card Mount Failed");
        return;
    }

    ESP_LOGD(TAG, "SD card initialized.");

    ControllerAdapter::initializeQueue();

    ESP_LOGD(TAG, "Device controls setup completed.");

    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        ESP_LOGD(TAG, "Initializing CC1101 module #%d\n", i);
        moduleCC1101State[i].init();
        ESP_LOGD(TAG, "Initializing CC1101 module #%d end \n", i);
        // cc1101Control initialization removed - using workers now
        ESP_LOGD(TAG, "CC1101 module #%d initialized.\n", i);
    }

    deviceConfig.powerBlink = true;

    // Initialize CC1101Worker (includes recording functionality moved from Recorder)
    CC1101Worker::init(cc1101WorkerSignalDetectedHandler, signalRecordedHandler);
    CC1101Worker::start();
    ESP_LOGI(TAG, "CC1101Worker initialized and started");

    // Old state machine initialization REMOVED
    // Workers are now responsible for CC1101 operations

    // BALANCED: TaskProcessor needs more stack for fileOperator ostringstream
    xTaskCreate(taskProcessor, "TaskProcessor", 8192, NULL, 1, NULL);  // 8KB - баланс между памятью и надежностью
    ESP_LOGD(TAG, "TaskProcessor task created.");

    ClientsManager& clients = ClientsManager::getInstance();
    clients.initializeQueue(NOTIFICATIONS_QUEUE);
    ESP_LOGD(TAG, "ClientsManager initialized.");
    
    // Инициализация CommandHandler и регистрация команд
    ESP_LOGI(TAG, "Initializing CommandHandler...");
    
    // Регистрируем все команды
    StateCommands::registerCommands(commandHandler);
    FileCommands::registerCommands(commandHandler);
    TransmitterCommands::registerCommands(commandHandler);
    RecorderCommands::registerCommands(commandHandler);
    
    ESP_LOGI(TAG, "CommandHandler initialized with %zu commands", commandHandler.getCommandCount());

    xTaskCreate(ClientsManager::processMessageQueue, "SendNotifications", 3072, NULL, 1, NULL); // 3KB
    ESP_LOGD(TAG, "SendNotifications task created.");
    
    // Create time synchronization task (updates deviceTime every second)
    xTaskCreate(timeSyncTask, "TimeSync", 2048, NULL, 1, NULL); // 2KB
    ESP_LOGD(TAG, "TimeSync task created.");
    
    // Initialize BLE adapter instead of WiFi
    bleAdapter.begin();
    bleAdapter.setCommandHandler(&commandHandler);  // Устанавливаем CommandHandler
    clients.addAdapter(&bleAdapter);
    bleAdapterStarted = true;
    ESP_LOGD(TAG, "BLE adapter initialized and added to clients.");

    // Log initial heap state - baseline for comparison
    ESP_LOGI(TAG, "===== INITIAL HEAP STATE (using static task allocation) =====");
    logHeapStats("Setup complete");
    ESP_LOGI(TAG, "NOTE: Heap stats should remain stable even after many task create/delete cycles!");

    ESP_LOGD(TAG, "Starting scheduler...");
    vTaskStartScheduler();
}

// Time synchronization task - updates deviceTime every second
void timeSyncTask(void* pvParameters) {
    const TickType_t delay = pdMS_TO_TICKS(1000); // 1 second
    
    while (true) {
        vTaskDelay(delay);
        
        // Only increment if time has been set (deviceTime > 0)
        if (deviceTime > 0) {
            deviceTime++;
        }
    }
}

void loop()
{
    if (deviceConfig.powerBlink) {
        DeviceControls::poweronBlink();
    }
}
