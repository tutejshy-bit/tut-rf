#ifndef cc1101_control_h
#define cc1101_control_h

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include "Cc1101Mode.h"
#include "config.h"

class Cc1101Control
{
private:
    int moduleNumber;
    int registeredModesCount;
    OperationMode previousMode;
    OperationMode currentMode;
    Cc1101Mode* registeredModes;
public:
    QueueHandle_t eventQueue;
    SemaphoreHandle_t stateSemaphore;
    TaskHandle_t recordTaskHandle;
    TaskHandle_t detectTaskHandle;

    Cc1101Control();
    Cc1101Control(int module, Cc1101Mode modesToRegister[], OperationMode *mode);
    Cc1101Control(int module, Cc1101Mode modesToRegister[], OperationMode operationMode);

    bool hasMode(OperationMode operationMode) const;
    int getModule() const;
    Cc1101Mode getMode(OperationMode operationMode) const;
    Cc1101Mode getCurrentMode() const;
    Cc1101Mode getPreviousMode() const;
    bool isPreviousMode(OperationMode mode) const;
    bool isCurrentMode(OperationMode mode) const;

    void init(int module, Cc1101Mode modesToRegister[], OperationMode operationMode);
    void switchMode(OperationMode mode);
};

extern Cc1101Control cc1101Control[CC1101_NUM_MODULES];

#endif