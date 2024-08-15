#ifndef Recorder_h
#define Recorder_h

#include "config.h"
#include "ModuleCc1101.h"
#include <vector>
#include <sstream>
#include "StringHelpers.h"
#include "FilesManager.h"
#include <ArduinoJson.h>
#include "FlipperSubFile.h"


typedef void (*RecorderCallback)(bool saved, std::string filename);

// Receive data
typedef struct
{
    std::vector<unsigned long> samples;
    volatile unsigned long lastReceiveTime = 0;
} ReceivedSamples;

ReceivedSamples &getReceivedData(int module);

typedef struct
{
    float frequency = 433.92;
    int modulation = 2;
    float deviation = 0;
    float rxBandwidth = 650;
    float dataRate = 0;
    std::string preset;
} RecordConfig;

class Recorder
{
private:
    RecordConfig recordConfig[CC1101_NUM_MODULES];

    RecorderCallback recorderCallback;
    void clearReceivedSamples(int module);
    static void receiveSample(int module);

    // unsigned int findPulseDuration(const std::vector<unsigned long>& samples);
    // void demodulateAndSmooth(const std::vector<unsigned long>& samples, RecordedSignal& recordedSignal);


public:
    Recorder(RecorderCallback recorderCallback);
    static void start(int module);
    static void stop(int module);
    static void process(int module);
    static void init();
    static std::string generateFilename(int module, float frequency, int modulation, float bandwidth);
    void setRecordConfig(int module, float frequency, int modulation, float deviation, float rxBandwidth, float dataRate, std::string preset);

    static void addModuleReceiver(int module);
    static void removeModuleReceiver(int module);

    static portMUX_TYPE muxes[CC1101_NUM_MODULES];
    static void IRAM_ATTR receiver(void* arg);

};

extern Recorder recorder;

#endif // Recorder_h