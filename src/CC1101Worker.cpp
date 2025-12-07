#include "CC1101Worker.h"
#include "FlipperSubFile.h"
#include "StreamingSubFileParser.h"
#include "StreamingPulsePayload.h"
#include "ClientsManager.h"
#include "BinaryMessages.h"
#include "ProtocolDecoder.h"
#include "FrequencyAnalyzer.h"
#include "StringHelpers.h"
#include "SubFileParser.h"  // For preset byte arrays
#include "esp_log.h"

static const char* TAG = "CC1101Worker";

// Helper function to get preset byte array by preset name
static const uint8_t* getPresetByteArray(const std::string& presetName) {
    if (presetName == "FuriHalSubGhzPresetOok270Async") {
        return subghz_device_cc1101_preset_ook_270khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetOok650Async") {
        return subghz_device_cc1101_preset_ook_650khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPreset2FSKDev238Async") {
        return subghz_device_cc1101_preset_2fsk_dev2_38khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPreset2FSKDev476Async") {
        return subghz_device_cc1101_preset_2fsk_dev47_6khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetMSK99_97KbAsync") {
        return subghz_device_cc1101_preset_msk_99_97kb_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetGFSK9_99KbAsync") {
        return subghz_device_cc1101_preset_gfsk_9_99kb_async_regs;
    }
    return nullptr;
}

// External references
extern ClientsManager& clients;

// Static member initialization
QueueHandle_t CC1101Worker::taskQueue = nullptr;
TaskHandle_t CC1101Worker::workerTaskHandle = nullptr;
CC1101State CC1101Worker::moduleStates[CC1101_NUM_MODULES] = {CC1101State::Idle, CC1101State::Idle};
int CC1101Worker::detectionMinRssi[CC1101_NUM_MODULES] = {-50, -50};
bool CC1101Worker::detectionIsBackground[CC1101_NUM_MODULES] = {false, false};
CC1101Worker::RecordingConfig CC1101Worker::recordingConfigs[CC1101_NUM_MODULES];
SignalDetectedCallback CC1101Worker::signalDetectedCallback = nullptr;
SignalRecordedCallback CC1101Worker::signalRecordedCallback = nullptr;
SemaphoreHandle_t sdMutex = nullptr;  // SD card mutex for concurrent file operations

float CC1101Worker::signalDetectionFrequencies[] = {
    300.00, 303.87, 304.25, 310.00, 315.00, 318.00, 390.00, 418.00, 433.07,
    433.92, 434.42, 434.77, 438.90, 868.35, 868.865, 868.95, 915.00, 925.00
};

extern ModuleCc1101 moduleCC1101State[CC1101_NUM_MODULES];

// Recording ISR data structures (moved from Recorder.cpp)
portMUX_TYPE CC1101Worker::samplesMuxes[CC1101_NUM_MODULES];
ReceivedSamples CC1101Worker::receivedSamples[CC1101_NUM_MODULES];

void CC1101Worker::init(SignalDetectedCallback detectedCb, SignalRecordedCallback recordedCb) {
    signalDetectedCallback = detectedCb;
    signalRecordedCallback = recordedCb;
    
    // Initialize samples mutexes (moved from Recorder::init)
    for (int i = 0; i < CC1101_NUM_MODULES; ++i) {
        samplesMuxes[i] = portMUX_INITIALIZER_UNLOCKED;
    }
    
    // Create queue for CC1101 tasks
    taskQueue = xQueueCreate(10, sizeof(CC1101Task*));
    if (taskQueue == nullptr) {
        ESP_LOGE(TAG, "Failed to create task queue");
    }
    
    // Create SD card mutex for concurrent file operations
    sdMutex = xSemaphoreCreateMutex();
    if (sdMutex == nullptr) {
        ESP_LOGE(TAG, "Failed to create SD mutex");
    }
}

// ISR and interrupt management functions (moved from Recorder.cpp)
void IRAM_ATTR CC1101Worker::receiver(void* arg)
{
    int module = reinterpret_cast<int>(arg);
    receiveSample(module);
}

void IRAM_ATTR CC1101Worker::receiveSample(int module)
{
    const unsigned long time = micros();
    portENTER_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
    ReceivedSamples &data = getReceivedData(module);

    if (data.lastReceiveTime == 0) {
        data.lastReceiveTime = time;
        portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
        return;
    }

    const unsigned long duration = time - data.lastReceiveTime;
    data.lastReceiveTime = time;

    if (duration > MAX_SIGNAL_DURATION) {
        // Log only occasionally to avoid ISR overhead - use static counter
        static volatile int clearCount[2] = {0, 0};
        clearCount[module]++;
        if ((clearCount[module] % 100) == 0) {
            // Note: ESP_LOG cannot be used in ISR, so we'll track this differently
        }
        data.samples.clear();
        portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
        return;
    }

    if (duration >= MIN_PULSE_DURATION && data.samples.size() < MAX_SAMPLES_BUFFER) {
        try {
            data.samples.push_back(duration);
        } catch (...) {
            // If vector push_back fails, clear and continue
            data.samples.clear();
        }
    } else {
        // Track rejected samples for debugging
        static volatile int rejectedCount[2] = {0, 0};
        rejectedCount[module]++;
    }

    portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
}

void CC1101Worker::addModuleReceiver(int module)
{
    // First remove any existing interrupt to avoid conflicts
    removeModuleReceiver(module);
    // Use busy wait instead of vTaskDelay to avoid context issues
    delayMicroseconds(1000); // 1ms delay
    attachInterruptArg(moduleCC1101State[module].getInputPin(), receiver, reinterpret_cast<void*>(module), CHANGE);
}

void CC1101Worker::removeModuleReceiver(int module)
{
    // Check if interrupt is actually attached before removing
    // This prevents "GPIO isr service is not installed" error
    int pin = moduleCC1101State[module].getInputPin();
    if (digitalPinToInterrupt(pin) != NOT_AN_INTERRUPT) {
        detachInterrupt(digitalPinToInterrupt(pin));
        ESP_LOGD(TAG, "ISR detached for module %d (pin %d)", module, pin);
    }
}

void CC1101Worker::clearReceivedSamples(int module)
{
    portENTER_CRITICAL(&CC1101Worker::samplesMuxes[module]);
    getReceivedData(module).samples.clear();
    getReceivedData(module).lastReceiveTime = 0;
    portEXIT_CRITICAL(&CC1101Worker::samplesMuxes[module]);
}

ReceivedSamples& CC1101Worker::getReceivedData(int module)
{
    return receivedSamples[module];
}

void CC1101Worker::start() {
    // Create worker task with static allocation
    // Stack usage optimized:
    // - StreamingPulsePayload (~100 bytes - reads from file on-demand!)
    // - checkAndSaveRecording() chunk buffer (~2KB)
    // - Stack frames and local variables (~1KB)
    // Total: ~3.5KB (was 6KB before streaming optimization!)
    static StackType_t workerStack[4096 / sizeof(StackType_t)];
    static StaticTask_t workerBuffer;
    
    workerTaskHandle = xTaskCreateStatic(
        workerTask,
        "CC1101Worker",
        4096 / sizeof(StackType_t),
        nullptr,
        3,  // Priority 3 (higher priority for time-sensitive RF operations)
        workerStack,
        &workerBuffer
    );
    
    if (workerTaskHandle == nullptr) {
        ESP_LOGE(TAG, "Failed to create worker task");
    } else {
        ESP_LOGI(TAG, "CC1101Worker started successfully");
    }
}

void CC1101Worker::workerTask(void* parameter) {
    ESP_LOGI(TAG, "CC1101Worker task running");
    
    CC1101Task* taskPtr;
    TickType_t lastWakeTime = xTaskGetTickCount();
    TickType_t lastHeartbeat = xTaskGetTickCount();
    
    while (true) {
        // Monitor stack usage periodically
        static int iterationCount = 0;
        if (++iterationCount % 1000 == 0) {
            UBaseType_t stackHighWaterMark = uxTaskGetStackHighWaterMark(NULL);
            ESP_LOGI(TAG, "Stack usage: %d bytes used, %d bytes remaining", 
                     4096 - stackHighWaterMark * sizeof(StackType_t),
                     stackHighWaterMark * sizeof(StackType_t));
            
            if (stackHighWaterMark < 512) {
                ESP_LOGW(TAG, "Low stack: %d bytes remaining", stackHighWaterMark * sizeof(StackType_t));
            }
        }
        
        // Send periodic heartbeat for widget updates (every 5 seconds)
        TickType_t now = xTaskGetTickCount();
        if ((now - lastHeartbeat) > pdMS_TO_TICKS(5000)) {
            sendHeartbeat();
            lastHeartbeat = now;
        }
        
        // Check for new commands (non-blocking)
        if (xQueueReceive(taskQueue, &taskPtr, 0) == pdTRUE) {
            if (taskPtr != nullptr) {
                processTask(*taskPtr);
                delete taskPtr;
            }
        }
        
        // Process ongoing operations for both modules
        for (int module = 0; module < CC1101_NUM_MODULES; module++) {
            switch (moduleStates[module]) {
                case CC1101State::Detecting:
                    processDetecting(module);
                    break;
                    
                case CC1101State::Recording:
                    processRecording(module);
                    break;
                    
                case CC1101State::Analyzing:
                    processAnalyzing(module);
                    break;
                    
                case CC1101State::Idle:
                case CC1101State::Transmitting:
                default:
                    // Nothing to do in these states
                    break;
            }
        }
        
        // Small delay to prevent busy-waiting
        vTaskDelayUntil(&lastWakeTime, pdMS_TO_TICKS(10));
    }
}

void CC1101Worker::processTask(const CC1101Task& task) {
    ESP_LOGD(TAG, "Processing command %d for module %d", (int)task.command, task.module);
    
    switch (task.command) {
        case CC1101Command::StartDetect:
            handleStartDetect(task.module, task.minRssi, task.isBackground);
            break;
            
        case CC1101Command::StopDetect:
            handleStopDetect(task.module);
            break;
            
        case CC1101Command::StartRecord:
            handleStartRecord(task.module, task);
            break;
            
        case CC1101Command::StopRecord:
            handleStopRecord(task.module);
            break;
            
        case CC1101Command::Transmit:
            handleTransmit(task.module, task.filename, task.repeat, task.pathType);
            break;
            
        case CC1101Command::StartAnalyzer:
            // frequency=startFreq, rxBandwidth=endFreq, deviation=step, dataRate=dwellTime
            handleStartAnalyzer(task.module, task.frequency, task.rxBandwidth, task.deviation, 
                               static_cast<uint32_t>(task.dataRate));
            break;
            
        case CC1101Command::StopAnalyzer:
            handleStopAnalyzer(task.module);
            break;
            
        case CC1101Command::GoIdle:
            handleGoIdle(task.module);
            break;
            
        default:
            ESP_LOGW(TAG, "Unknown command: %d", (int)task.command);
            break;
    }
}

void CC1101Worker::handleStartDetect(int module, int minRssi, bool isBackground) {
    ESP_LOGI(TAG, "Starting detection on module %d (minRssi=%d, background=%d)", 
             module, minRssi, isBackground);
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // Configure CC1101 for detection
    moduleCC1101State[module].setReceiveConfig(
        signalDetectionFrequencies[SIGNAL_DETECTION_FREQUENCIES_LENGTH - 1],
        false, 
        MODULATION_ASK_OOK, 
        256, 
        0, 
        512
    ).initConfig();
    
    // Update state
    moduleStates[module] = CC1101State::Detecting;
    detectionMinRssi[module] = minRssi;
    detectionIsBackground[module] = isBackground;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Detecting);
    
    ESP_LOGI(TAG, "Detection started on module %d", module);
}

void CC1101Worker::handleStopDetect(int module) {
    ESP_LOGI(TAG, "Stopping detection on module %d", module);
    
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
    moduleStates[module] = CC1101State::Idle;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Idle);
}

void CC1101Worker::handleStartRecord(int module, const CC1101Task& config) {
    ESP_LOGI(TAG, "Starting recording on module %d (freq=%.2f, mod=%d, preset=%s)", 
             module, config.frequency, config.modulation, config.preset.c_str());
    
    // Log other module state for debugging concurrent operations
    int otherModule = (module == 0) ? 1 : 0;
    ESP_LOGI(TAG, "Module %d state before start: %d, Module %d state: %d", 
             module, static_cast<int>(moduleStates[module]),
             otherModule, static_cast<int>(moduleStates[otherModule]));
    
    // Stop any ongoing operation first (ONLY on this module!)
    handleGoIdle(module);
    
    // Save recording config
    recordingConfigs[module].frequency = config.frequency;
    recordingConfigs[module].modulation = config.modulation;
    recordingConfigs[module].deviation = config.deviation;
    recordingConfigs[module].rxBandwidth = config.rxBandwidth;
    recordingConfigs[module].dataRate = config.dataRate;
    recordingConfigs[module].preset = config.preset;
    
    // Update state FIRST (before starting actual recording)
    moduleStates[module] = CC1101State::Recording;
    
    // Send mode switch notification IMMEDIATELY
    sendModeNotification(module, CC1101State::Recording);
    
    // Verify other module state unchanged
    ESP_LOGI(TAG, "After start - Module %d: Recording, Module %d: %d (should be unchanged!)", 
             module, otherModule, static_cast<int>(moduleStates[otherModule]));
    
    // Configure CC1101
    moduleCC1101State[module].setReceiveConfig(
        config.frequency,
        config.modulation == MODULATION_2_FSK ? true : false,
        config.modulation,
        config.rxBandwidth,
        config.deviation,
        config.dataRate
    ).initConfig();
    
    // Clear any previous samples and start ISR
    clearReceivedSamples(module);
    
    // Get GDO0 pin for this module
    int gdo0Pin = moduleCC1101State[module].getInputPin();
    ESP_LOGI(TAG, "Setting up ISR for module %d on pin %d (frequency=%.2f, modulation=%d, deviation=%.2f)", 
             module, gdo0Pin, config.frequency, config.modulation, config.deviation);
    
    addModuleReceiver(module);
    
    // Verify interrupt was attached
    if (digitalPinToInterrupt(gdo0Pin) != NOT_AN_INTERRUPT) {
        ESP_LOGI(TAG, "ISR successfully attached for module %d on pin %d", module, gdo0Pin);
    } else {
        ESP_LOGE(TAG, "Failed to attach ISR for module %d on pin %d!", module, gdo0Pin);
    }
    
    ESP_LOGI(TAG, "Recording started on module %d", module);
}

void CC1101Worker::handleStopRecord(int module) {
    ESP_LOGI(TAG, "Stopping recording on module %d", module);
    
    removeModuleReceiver(module);
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
    clearReceivedSamples(module);
    moduleStates[module] = CC1101State::Idle;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Idle);
}

void CC1101Worker::handleTransmit(int module, const std::string& filename, int repeat, int pathType) {
    ESP_LOGI(TAG, "Transmitting on module %d: %s (repeat=%d)", module, filename.c_str(), repeat);
    
    // Remember previous state for proper restoration
    CC1101State previousState = moduleStates[module];
    ESP_LOGI(TAG, "Module %d previous state: %d", module, static_cast<int>(previousState));
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // IMPORTANT: Give more time after stopping operation to ensure notification is sent
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Update state
    moduleStates[module] = CC1101State::Transmitting;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Transmitting);
    
    // CRITICAL: Give BLE time to send notification before blocking transmission
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Perform transmission (this is blocking)
    std::string error = transmitSub(filename, module, repeat, pathType);
    
    // Back to idle
    moduleStates[module] = CC1101State::Idle;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Idle);
    
    // CRITICAL: Give BLE time to send notification
    vTaskDelay(pdMS_TO_TICKS(100));
    
    if (error.empty()) {
        ESP_LOGI(TAG, "Transmission completed successfully on module %d", module);
    } else {
        ESP_LOGE(TAG, "Transmission failed on module %d: %s", module, error.c_str());
    }
}

void CC1101Worker::handleStartAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime) {
    ESP_LOGI(TAG, "Starting analyzer on module %d (%.2f - %.2f MHz, step=%.2f, dwell=%u ms)", 
             module, startFreq, endFreq, step, dwellTime);
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // Validate and set defaults
    if (step <= 0 || step > 1.0f) {
        step = 0.1f;  // Default step 0.1 MHz
    }
    
    if (dwellTime == 0) {
        dwellTime = 50;  // 50ms default dwell time
    }
    
    frequencyAnalyzer.startScan(module, startFreq, endFreq, step, dwellTime);
    moduleStates[module] = CC1101State::Analyzing;
    
    sendModeNotification(module, CC1101State::Analyzing);
}

void CC1101Worker::handleStopAnalyzer(int module) {
    ESP_LOGI(TAG, "Stopping analyzer on module %d", module);
    
    frequencyAnalyzer.stopScan();
    moduleStates[module] = CC1101State::Idle;
    
    sendModeNotification(module, CC1101State::Idle);
}

void CC1101Worker::processAnalyzing(int module) {
    frequencyAnalyzer.process();
    
    // Check if analyzer finished
    if (!frequencyAnalyzer.isActive() && moduleStates[module] == CC1101State::Analyzing) {
        handleStopAnalyzer(module);
    }
}

void CC1101Worker::handleGoIdle(int module) {
    ESP_LOGD(TAG, "Setting module %d to idle", module);
    
    switch (moduleStates[module]) {
        case CC1101State::Detecting:
            handleStopDetect(module);
            break;
            
        case CC1101State::Recording:
            handleStopRecord(module);
            break;
            
        case CC1101State::Analyzing:
            handleStopAnalyzer(module);
            break;
            
        case CC1101State::Transmitting:
        case CC1101State::Idle:
        default:
            moduleCC1101State[module].setSidle();
            moduleCC1101State[module].unlock();
            moduleStates[module] = CC1101State::Idle;
            break;
    }
}

void CC1101Worker::processDetecting(int module) {
    // Perform detection
    bool signalFound = detectSignal(module, detectionMinRssi[module], detectionIsBackground[module]);
    
    if (signalFound && !detectionIsBackground[module]) {
        // Single-shot detection found signal, stop automatically
        ESP_LOGI(TAG, "Single-shot detection complete, switching to Idle");
        handleStopDetect(module);  // This will send Idle notification
    }
}

bool CC1101Worker::detectSignal(int module, int minRssi, bool isBackground) {
    int detectedRssi = -100;
    float detectedFrequency = 0.0;
    
    const int batchSize = 5;
    
    // Scan frequencies in batches
    for (int i = 0; i < SIGNAL_DETECTION_FREQUENCIES_LENGTH; i += batchSize) {
        int endIdx = min(i + batchSize, SIGNAL_DETECTION_FREQUENCIES_LENGTH);
        
        for (int j = i; j < endIdx; j++) {
            float fMhz = signalDetectionFrequencies[j];
            moduleCC1101State[module].changeFrequency(fMhz);
            vTaskDelay(pdMS_TO_TICKS(1));
            int rssi = moduleCC1101State[module].getRssi();
            
            if (rssi >= detectedRssi) {
                detectedRssi = rssi;
                detectedFrequency = fMhz;
            }
        }
        
        // Check if signal found after each batch
        if (detectedRssi >= minRssi) {
            CC1101DetectedSignal signal;
            signal.rssi = detectedRssi;
            signal.lqi = moduleCC1101State[module].getLqi();
            signal.frequency = detectedFrequency;
            signal.module = module;
            signal.isBackgroundScanner = isBackground;
            
            ESP_LOGI(TAG, "Signal detected: rssi=%d, lqi=%u, freq=%.2f, module=%d", 
                     signal.rssi, signal.lqi, signal.frequency, signal.module);
            
            // Call callback
            if (signalDetectedCallback) {
                signalDetectedCallback(signal);
            }
            
            vTaskDelay(pdMS_TO_TICKS(400));
            return true;
        }
    }
    
    return false;
}

void CC1101Worker::processRecording(int module) {
    // Check if recording is complete
    checkAndSaveRecording(module);
}

void CC1101Worker::checkAndSaveRecording(int module) {
    // Get samples from ISR buffer
    portENTER_CRITICAL(&samplesMuxes[module]);
    ReceivedSamples &data = getReceivedData(module);
    size_t sampleCount = data.samples.size();
    unsigned long lastReceiveTime = data.lastReceiveTime;
    portEXIT_CRITICAL(&samplesMuxes[module]);
    
    if (sampleCount < MIN_SAMPLE) {
        return;  // Not enough samples yet
    }
    
    unsigned long timeSinceLast = micros() - lastReceiveTime;
    if (timeSinceLast <= MAX_SIGNAL_DURATION) {
        return;  // Signal still coming in
    }
    
    ESP_LOGI(TAG, "Signal complete on module %d: %zu samples", module, sampleCount);
    
    // Stop recording
    removeModuleReceiver(module);
    
    // Limit samples
    if (sampleCount > 10000) {
        sampleCount = 10000;
    }
    
    // Try to decode protocol in real-time
    ProtocolDecoder::DecodedSignal decoded;
    bool decodedSuccess = false;
    
    // Get samples copy for decoding (must be done outside critical section)
    std::vector<unsigned long> samplesCopy;
    samplesCopy.reserve(sampleCount);
    
    portENTER_CRITICAL(&samplesMuxes[module]);
    samplesCopy.assign(data.samples.begin(), data.samples.begin() + sampleCount);
    int currentRssi = moduleCC1101State[module].getRssi();
    portEXIT_CRITICAL(&samplesMuxes[module]);
    
    // Attempt decoding
    decodedSuccess = ProtocolDecoder::decode(samplesCopy, 
                                            recordingConfigs[module].frequency,
                                            currentRssi,
                                            decoded);
    
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        ESP_LOGI(TAG, "Signal decoded as %s protocol", decoded.protocol.c_str());
    } else {
        ESP_LOGD(TAG, "Signal could not be decoded to specific protocol, saving as RAW");
    }
    
    // Generate filename (include protocol if decoded)
    RecordingConfig& config = recordingConfigs[module];
    char filenameBuffer[100];
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        sprintf(filenameBuffer, "m%d_%s_%d_%s.sub", 
                module, 
                decoded.protocol.c_str(),
                static_cast<int>(config.frequency * 100),
                helpers::string::generateRandomString(8).c_str());
    } else {
        sprintf(filenameBuffer, "m%d_%d_%s_%d_%s.sub", 
                module, 
                static_cast<int>(config.frequency * 100), 
                config.modulation == MODULATION_ASK_OOK ? "AM" : "FM",
                static_cast<int>(config.rxBandwidth),
                helpers::string::generateRandomString(8).c_str());
    }
    std::string filename = filenameBuffer;
    std::string fullPath = "/DATA/SIGNALS/" + filename;
    
    // Prepare custom preset data if needed
    std::vector<byte> customPresetData;
    if (config.preset == "Custom") {
        ModuleCc1101& m = moduleCC1101State[module];
        customPresetData.insert(customPresetData.end(), {
            CC1101_MDMCFG4, m.getRegisterValue(CC1101_MDMCFG4),
            CC1101_MDMCFG3, m.getRegisterValue(CC1101_MDMCFG3),
            CC1101_MDMCFG2, m.getRegisterValue(CC1101_MDMCFG2),
            CC1101_DEVIATN, m.getRegisterValue(CC1101_DEVIATN),
            CC1101_FREND0,  m.getRegisterValue(CC1101_FREND0),
            0x00, 0x00
        });
        
        std::array<byte, 8> paTable = m.getPATableValues();
        customPresetData.insert(customPresetData.end(), paTable.begin(), paTable.end());
    }
    
    // CRITICAL OPTIMIZATION: Write chunks directly to file
    // CRITICAL: Lock SD mutex for concurrent file operations from multiple modules
    if (xSemaphoreTake(sdMutex, pdMS_TO_TICKS(1000)) != pdTRUE) {
        ESP_LOGE(TAG, "Failed to acquire SD mutex for module %d", module);
        if (signalRecordedCallback) {
            signalRecordedCallback(false, filename);
        }
        clearReceivedSamples(module);
        addModuleReceiver(module);
        return;
    }
    
    // Create directory if needed
    if (!SD.exists("/DATA/SIGNALS")) {
        SD.mkdir("/DATA/SIGNALS");
    }
    
    File file = SD.open(fullPath.c_str(), FILE_WRITE);
    if (!file) {
        ESP_LOGE(TAG, "Failed to open file: %s", fullPath.c_str());
        xSemaphoreGive(sdMutex);  // Release mutex!
        if (signalRecordedCallback) {
            signalRecordedCallback(false, filename);
        }
        clearReceivedSamples(module);
        addModuleReceiver(module);  // Restart recording
        return;
    }
    
    // Write header and preset info
    file.println("Filetype: Flipper SubGhz RAW File");
    file.println("Version: 1");
    file.print("Frequency: ");
    file.print(config.frequency * 1e6, 0);
    file.println();
    
    // Write preset
    file.print("Preset: ");
    std::string presetName = config.preset.empty() ? "Custom" : config.preset;
    if (presetName == "Ook270") file.println("FuriHalSubGhzPresetOok270Async");
    else if (presetName == "Ook650") file.println("FuriHalSubGhzPresetOok650Async");
    else if (presetName == "2FSKDev238") file.println("FuriHalSubGhzPreset2FSKDev238Async");
    else if (presetName == "2FSKDev476") file.println("FuriHalSubGhzPreset2FSKDev476Async");
    else if (presetName == "MSK") file.println("FuriHalSubGhzPresetMSK99_97KbAsync");
    else if (presetName == "GFSK") file.println("FuriHalSubGhzPresetGFSK9_99KbAsync");
    else file.println("FuriHalSubGhzPresetCustom");
    
    if (presetName == "Custom" && !customPresetData.empty()) {
        file.println("Custom_preset_module: CC1101");
        file.print("Custom_preset_data: ");
        for (size_t i = 0; i < customPresetData.size(); ++i) {
            char hexStr[3];
            sprintf(hexStr, "%02X", customPresetData[i]);
            file.print(hexStr);
            if (i < customPresetData.size() - 1) file.print(" ");
        }
        file.println();
    }
    
    // Write protocol (decoded if available, otherwise RAW)
    file.print("Protocol: ");
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        file.println(decoded.protocol.c_str());
        
        // Write protocol-specific data
        if (decoded.protocol == "Princeton") {
            if (!decoded.key.empty()) {
                file.print("Key: ");
                file.println(decoded.key.c_str());
            }
            if (decoded.te > 0) {
                file.print("TE: ");
                file.println(decoded.te);
            }
            if (decoded.bitCount > 0) {
                file.print("Bit: ");
                file.println(decoded.bitCount);
            }
            if (decoded.repeat > 0) {
                file.print("Repeat: ");
                file.println(decoded.repeat);
            }
        }
        
        // Also save RAW data as fallback
        file.println("RAW_Data: ");
        file.print("RAW_Data: ");
    } else {
        file.println("RAW");
        file.print("RAW_Data: ");
    }
    
    // Write samples in chunks directly from ISR buffer
    const size_t CHUNK_SIZE = 256;
    unsigned long chunk[CHUNK_SIZE];
    size_t offset = 0;
    
    while (offset < sampleCount) {
        size_t chunkSize = min(CHUNK_SIZE, sampleCount - offset);
        
        // Copy chunk from ISR buffer
        portENTER_CRITICAL(&samplesMuxes[module]);
        for (size_t i = 0; i < chunkSize; i++) {
            chunk[i] = data.samples[offset + i];
        }
        portEXIT_CRITICAL(&samplesMuxes[module]);
        
        // Write chunk to file
        for (size_t i = 0; i < chunkSize; i++) {
            if (offset + i > 0) {
                file.print((offset + i) % 2 == 1 ? " -" : " ");
            }
            file.print(chunk[i]);
        }
        
        offset += chunkSize;
        
        // Line breaks every 512 numbers
        if (offset % 512 == 0 && offset < sampleCount) {
            file.println();
            file.print("RAW_Data: ");
        }
    }
    
    file.println();
    file.close();
    
    // CRITICAL: Release SD mutex after file operations
    xSemaphoreGive(sdMutex);
    
    ESP_LOGI(TAG, "Signal saved: %s (%zu samples)", filename.c_str(), sampleCount);
    
    // Callback
    if (signalRecordedCallback) {
        signalRecordedCallback(true, filename);
    }
    
    // Clear samples and restart recording
    clearReceivedSamples(module);
    addModuleReceiver(module);
}

// Transmission functions (moved from Transmitter.cpp)
std::vector<int> CC1101Worker::getCountOfOnOffBits(const std::string &bits)
{
    std::vector<int> counts;
    char currentBit = bits[0];
    int currentCount = 1;

    for (size_t i = 1; i < bits.size(); i++) {
        if (bits[i] == currentBit) {
            currentCount++;
        } else {
            counts.push_back(currentCount);
            currentBit = bits[i];
            currentCount = 1;
        }
    }

    counts.push_back(currentCount);
    return counts;
}

bool CC1101Worker::transmitBinary(float frequency, int pulseDuration, const std::string &bits, int module, int modulation, float deviation, int repeatCount, int wait)
{
    moduleCC1101State[module].backupConfig().setTransmitConfig(frequency, modulation, deviation).init();
    std::vector<int> countOfOnOffBits = getCountOfOnOffBits(bits);

    for (int r = 0; r < repeatCount; r++) {
        for (int i = 0; i < countOfOnOffBits.size(); i++) {
            digitalWrite(moduleCC1101State[module].getOutputPin(), i % 2 == 0 ? HIGH : LOW);
            delayMicroseconds(countOfOnOffBits[i] * pulseDuration);
        }
        delay(wait);
    }

    moduleCC1101State[module].restoreConfig();
    moduleCC1101State[module].setSidle();

    return true;
}

bool CC1101Worker::transmitRaw(int module, float frequency, int modulation, float deviation, std::string& data, int repeat)
{
    std::vector<int> samples;
    std::istringstream stream(data.c_str());
    int sample;

    while (stream >> sample) {
        samples.push_back(sample);
    }

    moduleCC1101State[module].backupConfig().setTransmitConfig(frequency, modulation, deviation).initConfig();
    for (int r = 0; r < repeat; r++) {
        transmitRawData(samples, module);
        delay(1);
    }

    moduleCC1101State[module].restoreConfig();
    moduleCC1101State[module].setSidle();

    return true;
}

std::string CC1101Worker::transmitSub(const std::string& filename, int module, int repeat, int pathType)
{
    std::string fullPath;
    // Если путь уже абсолютный (/DATA/...), используем напрямую
    if (filename.find("/DATA/") == 0) {
        fullPath = filename;
        ESP_LOGD(TAG, "Using full system path: %s", fullPath.c_str());
    } else {
        // Используем pathType для поддиректории
        static const char* DIRS[] = {"/DATA/RECORDS", "/DATA/SIGNALS", "/DATA/PRESETS", "/DATA/TEMP"};
        if (pathType >= 0 && pathType < 4) {
            fullPath = std::string(DIRS[pathType]) + "/" + filename;
            ESP_LOGD(TAG, "Using pathType %d: %s", pathType, DIRS[pathType]);
        } else {
            fullPath = std::string("/DATA/RECORDS/") + filename;
            ESP_LOGW(TAG, "Unknown pathType %d; default RECORDS", pathType);
        }
        ESP_LOGD(TAG, "Added base path, full path: %s", fullPath.c_str());
    }
    ESP_LOGI(TAG, "Opening file: %s", fullPath.c_str());
    if (!SD.exists(fullPath.c_str())) {
        std::string msg = "File does not exist: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    File file = SD.open(fullPath.c_str(), FILE_READ);
    if (!file) {
        std::string msg = "Failed to open file: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    ESP_LOGD(TAG, "File opened successfully, size: %d bytes", file.size());
    file.close(); // Close immediately - will reopen for streaming
    
    // OPTIMIZED: Use StreamingSubFileParser (minimal RAM usage!)
    StreamingSubFileParser streamParser;
    StreamingSubFileParser::SubFileHeader header;
    
    ESP_LOGD(TAG, "Parsing header (pass 1)...");
    if (!streamParser.parseHeader(fullPath.c_str(), header)) {
        std::string msg = "Failed to parse header from .sub: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    // Check if it's a supported protocol (RAW only for now)
    if (header.protocol != "RAW") {
        std::string msg = "Unsupported protocol (only RAW supported in streaming mode): " + header.protocol;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    ESP_LOGD(TAG, "Header parsed, frequency: %.2f MHz", header.frequency / 1000000.0);
    
    // Configure CC1101 with proper order:
    // CRITICAL: Preset must be applied AFTER Init but BEFORE entering TX mode
    // Order: 1) Idle, 2) Init (reset registers), 3) Set frequency, 4) Apply preset, 5) Set TX
    ESP_LOGD(TAG, "Configuring CC1101 module %d", module);
    
    // Get preset bytes
    const uint8_t* presetBytes = nullptr;
    int presetLength = 0;
    
    if (!header.preset.empty()) {
        presetBytes = getPresetByteArray(header.preset);
        if (presetBytes != nullptr) {
            presetLength = 44;  // Standard presets are 44 bytes
            ESP_LOGI(TAG, "Using standard preset: %s", header.preset.c_str());
        }
    }
    
    if (presetBytes == nullptr && header.customPresetDataSize > 0) {
        presetBytes = header.customPresetData;
        presetLength = header.customPresetDataSize;
        ESP_LOGI(TAG, "Using custom preset (%zu bytes)", header.customPresetDataSize);
    }
    
    if (presetBytes == nullptr) {
        ESP_LOGW(TAG, "No preset available - using default CC1101 configuration");
        // Use regular setTx without preset
        moduleCC1101State[module].setTx(header.frequency / 1000000.0);
    } else {
        // Use setTxWithPreset which applies preset in correct order
        moduleCC1101State[module].setTxWithPreset(header.frequency / 1000000.0, presetBytes, presetLength);
    }
    
    delay(10);
    
    // ULTRA-OPTIMIZED: Use StreamingPulsePayload (reads from file on-demand!)
    // RAM usage: ~100 bytes instead of ~2KB for vector!
    ESP_LOGD(TAG, "Initializing streaming transmission (repeat: %d)", repeat);
    
    StreamingPulsePayload streamingPayload;
    if (!streamingPayload.init(fullPath.c_str(), repeat)) {
        std::string msg = "Failed to initialize streaming payload: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    // Transmit directly from file
    ESP_LOGD(TAG, "Starting streaming transmission...");
    bool signalTransmitted = transmitData(streamingPayload, module);
    ESP_LOGD(TAG, "Transmission result: %s", signalTransmitted ? "SUCCESS" : "FAILED");
    
    streamingPayload.close();
    moduleCC1101State[module].restoreConfig().setSidle();
    ESP_LOGI(TAG, "Transmission %s for %s", signalTransmitted ? "SUCCESS" : "FAILED", fullPath.c_str());
    if (!signalTransmitted) {
        return "Transmission routine failed for file: " + fullPath;
    }
    return std::string(); // success
}

bool CC1101Worker::transmitRawData(const std::vector<int> &rawData, int module)
{
    if (rawData.empty()) {
        return false;
    }

    for (const auto &rawValue : rawData) {
        if (rawValue != 0) {
            digitalWrite(moduleCC1101State[module].getOutputPin(), (rawValue > 0));
            delayMicroseconds(abs(rawValue));
        }
    }

    return true;
}

bool CC1101Worker::transmitData(PulsePayload &payload, int module)
{
    uint32_t duration;
    bool pinState;

    while (payload.next(duration, pinState)) {
        digitalWrite(moduleCC1101State[module].getOutputPin(), pinState);
        delayMicroseconds(duration);
        taskYIELD();
    }

    return true;
}

int CC1101Worker::findFirstIdleModule()
{
    for (int i = 0; i < CC1101_NUM_MODULES; ++i) {
        // Check with CC1101Worker instead of direct mode check
        if (CC1101Worker::getState(i) == CC1101State::Idle)
            return i;
    }
    return -1;
}

// Helper functions to send commands
bool CC1101Worker::startDetect(int module, int minRssi, bool isBackground) {
    if (taskQueue == nullptr) {
        ESP_LOGE(TAG, "Task queue not initialized");
        return false;
    }
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartDetect;
    task->module = module;
    task->minRssi = minRssi;
    task->isBackground = isBackground;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        ESP_LOGE(TAG, "Failed to enqueue task");
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopDetect(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopDetect;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::startRecord(int module, float frequency, int modulation, float deviation,
                                float rxBandwidth, float dataRate, const std::string& preset) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartRecord;
    task->module = module;
    task->frequency = frequency;
    task->modulation = modulation;
    task->deviation = deviation;
    task->rxBandwidth = rxBandwidth;
    task->dataRate = dataRate;
    task->preset = preset;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopRecord(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopRecord;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::transmit(int module, const std::string& filename, int repeat, int pathType) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::Transmit;
    task->module = module;
    task->filename = filename;
    task->repeat = repeat;
    task->pathType = pathType;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::goIdle(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::GoIdle;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::startAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartAnalyzer;
    task->module = module;
    task->frequency = startFreq;      // Use frequency field for startFreq
    task->rxBandwidth = endFreq;      // Use rxBandwidth field for endFreq
    task->deviation = step;           // Use deviation field for step
    task->dataRate = dwellTime;       // Use dataRate field for dwellTime
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopAnalyzer(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopAnalyzer;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

CC1101State CC1101Worker::getState(int module) {
    if (module >= 0 && module < CC1101_NUM_MODULES) {
        return moduleStates[module];
    }
    return CC1101State::Idle;
}

void CC1101Worker::sendModeNotification(int module, CC1101State state) {
    // Send binary mode switch notification (compatible with old BinaryModeSwitch format)
    BinaryModeSwitch msg;
    msg.module = static_cast<uint8_t>(module);
    msg.currentMode = static_cast<uint8_t>(state);
    msg.previousMode = static_cast<uint8_t>(moduleStates[module]);  // Previous state
    
    // Send as binary data
    const char* msgPtr = reinterpret_cast<const char*>(&msg);
    bool queued = clients.enqueueMessage(NotificationType::ModeSwitch, std::string(msgPtr, sizeof(BinaryModeSwitch)));
    
    if (queued) {
        ESP_LOGI(TAG, "[NOTIFY] Module=%d: %d → %d (queued at %lu ms)", 
                 module, static_cast<int>(moduleStates[module]), static_cast<int>(state), millis());
    } else {
        ESP_LOGE(TAG, "[NOTIFY] FAILED to queue! Module=%d: %d → %d", 
                 module, static_cast<int>(moduleStates[module]), static_cast<int>(state));
    }
}

void CC1101Worker::sendHeartbeat() {
    // CRITICAL: Only send heartbeat if there are connected clients
    // Check if any adapter has connected clients before sending
    // This prevents unnecessary processing when device is disconnected
    if (clients.getConnectedCount() == 0) {
        return;  // No connected clients, skip heartbeat
    }
    
    // Send full device status for widget updates (same as GetState)
    const byte numRegs = 0x2E;
    
    BinaryStatus status;
    status.messageType = MSG_STATUS;
    status.module0Mode = static_cast<uint8_t>(moduleStates[0]);
    status.module1Mode = static_cast<uint8_t>(moduleStates[1]);
    status.numRegisters = numRegs;
    status.freeHeap = ESP.getFreeHeap();
    
    // Read all CC1101 registers for both modules
    moduleCC1101State[0].readAllConfigRegisters(status.module0Registers, numRegs);
    moduleCC1101State[1].readAllConfigRegisters(status.module1Registers, numRegs);
    
    // Send binary status
    clients.notifyAllBinary(NotificationType::State, 
                           reinterpret_cast<const uint8_t*>(&status), 
                           sizeof(BinaryStatus));
    
    ESP_LOGD(TAG, "Heartbeat sent: Module0=%d, Module1=%d, FreeHeap=%u", 
             static_cast<int>(moduleStates[0]), 
             static_cast<int>(moduleStates[1]), 
             status.freeHeap);
}

