#include <Argument.h>
#include <Command.h>
#include <CommandError.h>
#include <EEPROM.h>
#include <SimpleCLI.h>
#include <StringCLI.h>
#include <WiFi.h>
#include <WiFiAP.h>
#include <WiFiClient.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h>
#include <sstream>
#include "Actions.h"
#include "AllProtocols.h"
#include "ClientsManager.h"
#include "ConfigManager.h"
#include "DeviceControls.h"
#include "FS.h"
#include "SD.h"
#include "SPI.h"
#include "SerialAdapter.h"
#include "ServiceMode.h"
#include "WebAdapter.h"
#include "config.h"
#include "esp_log.h"

static const char* TAG = "Setup";

// Constants
const int WIFI_AP_STARTED_BIT = BIT0;
const int MAX_RETRIES = 5;

// Global variables
EventGroupHandle_t wifiEventGroup;
SemaphoreHandle_t wifiEventMutex;
bool webAdapterStarted = false;
void onWiFiEvent(WiFiEvent_t event);

SimpleCLI cli;
SPIClass sdspi(VSPI);

bool webAdapterStared = false;

// Wifi parameters
const int wifi_channel = 12;

// Device settings
struct DeviceConfig
{
    bool powerBlink;
} deviceConfig;

void cc1101StateTask(void* parameters)
{
    Cc1101Control* cc1101Control = (Cc1101Control*)parameters;
    if (cc1101Control == nullptr) {
        ESP_LOGE(TAG, "cc1101Control is nullptr");
        vTaskDelete(nullptr);
    }

    OperationMode event;
    ModeTaskParameters taskParameters;

    while (true) {
        if (xQueueReceive(cc1101Control->eventQueue, &event, portMAX_DELAY) == pdPASS) {
            if (cc1101Control->stateSemaphore == nullptr) {
                ESP_LOGE(TAG, "stateSemaphore is nullptr");
                vTaskDelete(nullptr);
            }
            xSemaphoreTake(cc1101Control->stateSemaphore, portMAX_DELAY);

            if (cc1101Control->isPreviousMode(OperationMode::RecordSignal) && cc1101Control->recordTaskHandle != nullptr) {
                xTaskNotifyGive(cc1101Control->recordTaskHandle);
                if (xSemaphoreTake(moduleCC1101State[cc1101Control->getModule()].getStateChangeSemaphore(), portMAX_DELAY) == pdTRUE) {
                    cc1101Control->recordTaskHandle = nullptr;
                }
            } else if (cc1101Control->isPreviousMode(OperationMode::DetectSignal) && cc1101Control->detectTaskHandle != nullptr) {
                xTaskNotifyGive(cc1101Control->detectTaskHandle);
                if (xSemaphoreTake(moduleCC1101State[cc1101Control->getModule()].getStateChangeSemaphore(), portMAX_DELAY) == pdTRUE) {
                    cc1101Control->detectTaskHandle = nullptr;
                }
            }

            ModeTaskParameters* taskParameters = new ModeTaskParameters{.module = cc1101Control->getModule(), .mode = cc1101Control->getCurrentMode()};
            if (taskParameters == nullptr) {
                ESP_LOGE(TAG, "Failed to allocate memory for taskParameters");
                vTaskDelete(nullptr);
            }
            Cc1101Mode prevMode = cc1101Control->getPreviousMode();
            Cc1101Mode currentMode = cc1101Control->getCurrentMode();

            switch (event) {
                case OperationMode::RecordSignal:
                    if (xTaskCreate(cc1101Control->getCurrentMode().onModeProcess, "RecordTask", 4096, taskParameters, 1, &cc1101Control->recordTaskHandle) != pdPASS) {
                        ESP_LOGE(TAG, "Failed to create RecordTask");
                        delete taskParameters;
                    }
                    break;

                case OperationMode::DetectSignal:
                    if (xTaskCreate(cc1101Control->getCurrentMode().onModeProcess, "DetectTask", 4096, taskParameters, 1, &cc1101Control->detectTaskHandle) != pdPASS) {
                        ESP_LOGE(TAG, "Failed to create DetectTask");
                        delete taskParameters;
                    }
                    break;

                case OperationMode::Idle:
                    // Stop the active task
                    break;

                default:
                    delete taskParameters;  // Clean up if no task was created
                    break;
            }

            Handler::onStateChange(cc1101Control->getModule(), currentMode.getMode(), prevMode.getMode());

            xSemaphoreGive(cc1101Control->stateSemaphore);
        }

        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void listenSerial(void* parameter)
{
    while (true) {
        SerialAdapter::getInstance().processQueue();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

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
                    Action::transmitSignal(task);
                } break;
                case Device::TaskType::Record: {
                    Device::TaskRecord& task = item->recordTask;
                    Action::recordSignal(task);
                } break;
                case Device::TaskType::DetectSignal: {
                    Device::TaskDetectSignal& task = item->detectSignalTask;
                    Action::detectSignal(task);
                } break;
                case Device::TaskType::FilesManager: {
                    Device::TaskFilesManager& task = item->filesManagerTask;
                    Action::fileOperator(task);
                } break;
                case Device::TaskType::FileUpload: {
                    Device::TaskFileUpload& task = item->fileUploadTask;
                    Action::fileUpload(task);
                } break;
                case Device::TaskType::GetState: {
                    Device::TaskGetState& task = item->getStateTask;
                    Action::getCurrentState(task);
                } break;
                case Device::TaskType::Idle: {
                    Device::TaskIdle& task = item->idleTask;
                    Action::idle(task);
                } break;
                default:
                    break;
            }
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void onWiFiEvent(WiFiEvent_t event)
{
    if (wifiEventGroup == NULL || wifiEventMutex == NULL) {
        ESP_LOGE(TAG, "WiFi event group or mutex is NULL");
        return;
    }

    if (xSemaphoreTake(wifiEventMutex, portMAX_DELAY) == pdTRUE) {
        switch (event) {
            case ARDUINO_EVENT_WIFI_AP_START:
                xEventGroupSetBits(wifiEventGroup, WIFI_AP_STARTED_BIT);
                break;
            case ARDUINO_EVENT_WIFI_STA_CONNECTED:
            case ARDUINO_EVENT_WIFI_AP_STACONNECTED:
                // webAdapter.initStatic(SD);
                break;
            default:
                break;
        }
        xSemaphoreGive(wifiEventMutex);
    } else {
        ESP_LOGE(TAG, "Failed to take mutex");
    }
}

void setup()
{
    ESP_LOGD(TAG, "Starting SPIFFS");
    if (!SPIFFS.begin(false)) {
        ESP_LOGE(TAG, "SPIFFS mount failed!");
        return;
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
        cc1101Control[i].init(i, deviceModes, OperationMode::Idle);
        ESP_LOGD(TAG, "CC1101 module #%d initialized.\n", i);
    }

    deviceConfig.powerBlink = true;

    Recorder::init();
    ESP_LOGD(TAG, "Recorder initialized.");

    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        char taskName[20];
        snprintf(taskName, sizeof(taskName), "cc1101StateTask%d", i);
        if (cc1101Control[i].eventQueue == nullptr || cc1101Control[i].stateSemaphore == nullptr) {
            ESP_LOGE(TAG, "Error: Failed to initialize cc1101Control members");
            return;
        }
        xTaskCreate(cc1101StateTask, taskName, 2048, &cc1101Control[i], 1, NULL);
        ESP_LOGD(TAG, "Task %s created.\n", taskName);
    }

    xTaskCreate(taskProcessor, "TaskProcessor", 25600, NULL, 1, NULL);
    ESP_LOGD(TAG, "TaskProcessor task created.");

    ClientsManager& clients = ClientsManager::getInstance();
    clients.initializeQueue(NOTIFICATIONS_QUEUE);
    ESP_LOGD(TAG, "ClientsManager initialized.");

    xTaskCreate(ClientsManager::processMessageQueue, "SendNotifications", 2048, NULL, 1, NULL);
    ESP_LOGD(TAG, "SendNotifications task created.");

    SerialAdapter& serialAdapter = SerialAdapter::getInstance();
    serialAdapter.setup(cli);
    serialAdapter.begin();
    clients.addAdapter(&serialAdapter);
    ESP_LOGD(TAG, "Serial adapter initialized and added to clients.");

    xTaskCreate(listenSerial, "ListenSerial", 4096, NULL, 1, NULL);
    ESP_LOGD(TAG, "ListenSerial task created.");

    wifiEventGroup = xEventGroupCreate();
    if (wifiEventGroup == NULL) {
        ESP_LOGE(TAG, "Failed to create wifi event group");
        return;
    }

    wifiEventMutex = xSemaphoreCreateMutex();
    if (wifiEventMutex == NULL) {
        ESP_LOGE(TAG, "Failed to create wifi event mutex");
        return;
    }

    WiFi.onEvent(onWiFiEvent);

    String ssid = ConfigManager::getConfigParam("ssid");
    String password = ConfigManager::getConfigParam("password");

    if (ConfigManager::getConfigParam("wifi_mode") == "client") {
        WiFi.mode(WIFI_STA);
        WiFi.begin(ssid, password);

        ESP_LOGI(TAG, "Connecting to Wi-Fi ssid: \"%s\" password: \"%s\"", ssid, password);
        while (WiFi.status() != WL_CONNECTED) {
            delay(1000);
            ESP_LOGI(TAG, ".");
        }
        ESP_LOGI(TAG, "Connected to the Wi-Fi network!");
        ESP_LOGI(TAG, "IP Address: %s", WiFi.localIP().toString());

        webAdapter.begin(SD);
        clients.addAdapter(&webAdapter);
    } else {
        WiFi.mode(WIFI_AP);
        WiFi.setSleep(false);

        int retryCount = 0;
        while (retryCount < MAX_RETRIES) {
            Serial.println(ssid);
            Serial.println(password);
            WiFi.softAP(ssid, password, wifi_channel, 8);
            EventBits_t bits = xEventGroupWaitBits(wifiEventGroup, WIFI_AP_STARTED_BIT, pdFALSE, pdTRUE, pdMS_TO_TICKS(10000));
            if (bits & WIFI_AP_STARTED_BIT) {
                ESP_LOGD(TAG, "WiFi AP successfully started");
                break;
            } else {
                ESP_LOGE(TAG, "Failed to start WiFi AP, retrying...");
                retryCount++;
            }
        }

        if (retryCount == MAX_RETRIES) {
            ESP_LOGE(TAG, "Failed to start WiFi AP after maximum retries");
        } else {
            webAdapter.begin(SD);
            clients.addAdapter(&webAdapter);
        }
    }

    webAdapter.initStatic(SD);
    ESP_LOGD(TAG, "Starting scheduler...");
    vTaskStartScheduler();
}

void loop()
{
    if (deviceConfig.powerBlink) {
        DeviceControls::poweronBlink();
    }
}
