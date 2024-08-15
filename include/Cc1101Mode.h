#ifndef Cc1101_Mode_h
#define Cc1101_Mode_h

#include <Arduino.h>

typedef void (*CallbackFunction)(int);

enum class OperationMode
{
    Idle,
    DetectSignal,
    RecordSignal,
    TransmitSignal,
    Unknown
};

enum class OperationEvent
{
    GoIdle,
    StartRecord,
    StartDetect
};

inline const char* modeToString(OperationMode v)
{
    switch (v)
    {
        case OperationMode::Idle: return "Idle";
        case OperationMode::DetectSignal: return "DetectSignal";
        case OperationMode::RecordSignal: return "RecordSignal";
        case OperationMode::TransmitSignal: return "TransmitSignal";
        default: return "Unknown";
    }
}

class Cc1101Mode
{
    friend class Cc1101Control;

public:
    Cc1101Mode();
    Cc1101Mode(OperationMode mode, CallbackFunction onState = nullptr);

    void setup(OperationMode mode, CallbackFunction onState = nullptr);
    void setMode(OperationMode mode);

    static void onModeProcess(void *taskParameters);

    OperationMode getMode() const;
    bool isMode(OperationMode mode);

    CallbackFunction onMode = nullptr;
protected:
    OperationMode mode;
};

struct ModeTaskParameters
{
    int module;
    Cc1101Mode mode;
};

#endif