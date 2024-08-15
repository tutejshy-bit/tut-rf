#ifndef Actions_h
#define Actions_h

#include "ClientsManager.h"
#include "Detector.h"
#include "Cc1101Mode.h"
#include "Cc1101Control.h"
#include "FilesManager.h"
#include "ModuleCc1101.h"
#include "Recorder.h"
#include "StringHelpers.h"
#include "DeviceTasks.h"
#include "Transmitter.h"
#include <Arduino.h>
#include <freertos/FreeRTOS.h>

String generateFilename(float frequency, int modulation, float bandwidth);

namespace Handler {
void signalRecordedHandler(bool saved, std::string filename);
void signalDetectedHandler(DetectedSignal detectedSignal);
void onStateChange(int module, OperationMode mode, OperationMode previousMode);
}

namespace Action {
void detectSignal(Device::TaskDetectSignal &task);
void recordSignal(Device::TaskRecord &task);
void transmitFromFile(Device::TaskTransmission &task);
void transmitSignal(Device::TaskTransmission &task);
void idle(Device::TaskIdle &task);
void getCurrentState(Device::TaskGetState &task);
void fileOperator(Device::TaskFilesManager &task);
void fileUpload(Device::TaskFileUpload &task);
}

extern Cc1101Mode deviceModes[];
extern Transmitter transmitter;
extern Recorder recorder;
extern Detector detector;

#endif