#ifndef Detector_h
#define Detector_h

#include "config.h"
#include "ModuleCc1101.h"
#include <vector>
#include <sstream>
#include <iomanip>  

// SINGAL DETECTION
#define SIGNAL_DETECTION_FREQUENCIES_LENGTH 19
#define DELAY_AFTER_SIGNAL_FOUND 300

class DetectedSignal {
  public:
    int rssi;
    float frequency;
    int module;
    bool isBackgroundScanner;

    std::string toJson() const {
        std::stringstream jsonString;
        jsonString << "{\"module\":\"" << module << "\",";
        jsonString << "\"frequency\":\"" << std::fixed << std::setprecision(8) << frequency << "\",";
        jsonString << "\"rssi\":\"" << rssi << "\"}";
        return jsonString.str();
    }
};

typedef void (*DetectorCallback)(DetectedSignal detectedSignal);

class Detector
{
private:
    DetectorCallback detectorCallback;
    static float signalDetectionFrequencies[];
    int signalDetectionMinRssi = -50;
    void detectSignal(int module, int minRssi);
public:
    Detector(DetectorCallback detectorCallback);
    static void start(int module);
    static void stop(int module);
    static void process(int module);
    int getSignalDetectionMinRssi() { return signalDetectionMinRssi; }
    void setSignalDetectionMinRssi(int signalDetectionMinRssi) { this->signalDetectionMinRssi = signalDetectionMinRssi; }
};

extern Detector detector;

#endif // Detector_h