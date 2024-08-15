#ifndef Transmitter_h
#define Transmitter_h

#include "config.h"
#include <SimpleCLI.h>
#include "ModuleCc1101.h"
#include <vector>
#include <sstream>
#include "FilesManager.h"
#include "SubFileParser.h"
#include "PulsePayload.h"

class Transmitter
{
private:
    std::vector<int> getCountOfOnOffBits(const std::string& bits);
    boolean transmitRawData(const std::vector<int> &rawData, int module);
public:
    boolean transmitBinary(float frequency, int pulseDuration, const std::string& bits, int module, int modulation, float deviation, int repeatCount, int wait);
    boolean transmitRaw(int module, float frequency, int modulation, float deviation, std::string& data, int repeat);
    bool transmitSub(const std::string& filename, int module, int repeat);
    boolean transmitData(PulsePayload& payload, int module);

};

#endif // Transmitter_h