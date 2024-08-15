#include "Cc1101Mode.h"

Cc1101Mode::Cc1101Mode()
{
}

Cc1101Mode::Cc1101Mode(OperationMode mode, CallbackFunction onMode)
{
    setup(mode, onMode);
}

void Cc1101Mode::setup(OperationMode mode, CallbackFunction onMode)
{
    this->mode = mode;
    this->onMode = onMode;
}

bool Cc1101Mode::isMode(OperationMode mode)
{
    return mode == this->mode;
}

OperationMode Cc1101Mode::getMode() const
{
    return mode;
}

void Cc1101Mode::setMode(OperationMode mode)
{
    this->mode = mode;
}

void Cc1101Mode::onModeProcess(void *taskParameters)
{
    ModeTaskParameters *parameters = static_cast<ModeTaskParameters *>(taskParameters);
    parameters->mode.onMode(parameters->module);
}