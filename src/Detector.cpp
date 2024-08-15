#include "Detector.h"

float Detector::signalDetectionFrequencies[] = {300.00, 303.87, 304.25, 310.00, 315.00, 318.00,  390.00, 418.00, 433.07,
                                                433.92, 434.42, 434.77, 438.90, 868.35, 868.865, 868.95, 915.00, 925.00};

Detector::Detector(DetectorCallback detectorCallback)
{
    this->detectorCallback = detectorCallback;
}

void Detector::start(int module)
{
    moduleCC1101State[module].setReceiveConfig(Detector::signalDetectionFrequencies[SIGNAL_DETECTION_FREQUENCIES_LENGTH - 1], false, MODULATION_ASK_OOK, 256, 0, 512).initConfig();
}

void Detector::stop(int module)
{
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
}

void Detector::process(int module)
{
    Detector::start(module);
    while (true) {
        if (ulTaskNotifyTake(pdTRUE, 0) == 1) {
            break;
        }
        detector.detectSignal(module, detector.signalDetectionMinRssi);
        vTaskDelay(pdMS_TO_TICKS(10));  //
    }
    Detector::stop(module);
    vTaskDelete(NULL);  // Delete the task itself
}

void Detector::detectSignal(int module, int minRssi)
{
    int detectedRssi = -100;
    float detectedFrequency = 0.0;

    int tries = 0;
    while (tries < 2) {
        for (float fMhz : Detector::signalDetectionFrequencies) {
            moduleCC1101State[module].changeFrequency(fMhz);
            vTaskDelay(pdMS_TO_TICKS(1));
            int rssi = moduleCC1101State[module].getRssi();

            if (rssi >= detectedRssi) {
                detectedRssi = rssi;
                detectedFrequency = fMhz;
            }
        }
        if (detectedRssi >= minRssi) {
            detectorCallback(DetectedSignal{detectedRssi, detectedFrequency, module});
            vTaskDelay(pdMS_TO_TICKS(400));
            return;
        }
        tries++;
    }
}