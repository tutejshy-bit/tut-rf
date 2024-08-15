#include "Cc1101Control.h"

Cc1101Control cc1101Control[CC1101_NUM_MODULES];

Cc1101Control::Cc1101Control() : moduleNumber(0), registeredModes(nullptr), registeredModesCount(0),
                                 currentMode(OperationMode::Unknown), previousMode(OperationMode::Unknown),
                                 eventQueue(nullptr), stateSemaphore(nullptr) {}

Cc1101Control::Cc1101Control(int module, Cc1101Mode modesToRegister[], OperationMode *mode)
{
    if (mode == NULL) return;
    Cc1101Control(module, modesToRegister, *mode);
}

Cc1101Control::Cc1101Control(int module, Cc1101Mode modesToRegister[], OperationMode operationMode)
{
    init(module, modesToRegister, operationMode);
}

bool Cc1101Control::hasMode(OperationMode operationMode) const
{
    for (int i = 0; i < registeredModesCount; i++)
    {
        if (registeredModes[i].mode == operationMode)
            return true;
    }
    return false;
}

int Cc1101Control::getModule() const
{
    return moduleNumber;
}

Cc1101Mode Cc1101Control::getMode(OperationMode operationMode) const
{
    for (int i = 0; i < registeredModesCount; i++)
    {
        if (registeredModes[i].mode == operationMode)
            return registeredModes[i];
    }

    return Cc1101Mode(OperationMode::Unknown);
}

Cc1101Mode Cc1101Control::getCurrentMode() const
{
    return getMode(currentMode);
}

Cc1101Mode Cc1101Control::getPreviousMode() const
{
    return getMode(previousMode);
}

bool Cc1101Control::isPreviousMode(OperationMode mode) const
{
    return mode == previousMode;
}

bool Cc1101Control::isCurrentMode(OperationMode mode) const
{
    return mode == currentMode;
}

void Cc1101Control::init(int module, Cc1101Mode modesToRegister[], OperationMode operationMode)
{
    moduleNumber = module;
    registeredModes = modesToRegister;
    registeredModesCount = sizeof(registeredModes);
    if (!hasMode(operationMode))
        return;

    previousMode = operationMode;
    currentMode = operationMode;
    eventQueue = xQueueCreate(10, sizeof(OperationMode));
    stateSemaphore = xSemaphoreCreateMutex();
}

void Cc1101Control::switchMode(OperationMode operationMode)
{
    if (currentMode == operationMode || !hasMode(operationMode))
        return;

    previousMode = currentMode;
    Cc1101Mode newMode = getMode(operationMode);

    if (newMode.getMode() == OperationMode::Unknown) {
        return;
    }

    currentMode = operationMode;

    xQueueSend(eventQueue, &operationMode, portMAX_DELAY);
}