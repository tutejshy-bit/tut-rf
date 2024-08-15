#include "Transmitter.h"

FilesManager fm;

std::vector<int> Transmitter::getCountOfOnOffBits(const std::string &bits)
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

boolean Transmitter::transmitBinary(float frequency, int pulseDuration, const std::string &bits, int module, int modulation, float deviation, int repeatCount, int wait)
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

boolean Transmitter::transmitRaw(int module, float frequency, int modulation, float deviation, std::string& data, int repeat)
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

bool Transmitter::transmitSub(const std::string& filename, int module, int repeat)
{
    std::string fullPath = std::string(FILES_RECORDS_PATH) + "/" + filename;

    File file = fm.open(fullPath.c_str(), FILE_READ);
    if (!file) {
        return false;
    }
    SubFileParser parser(file);
    parser.parseFile();
    file.close();

    if (!parser.isModuleCc1101()) {
        return false;
    }

    PulsePayload payload;
    if (!parser.getPayload(payload)) {
        // Serial.println("Unsupported protocol or failed to create payload");
        return false;
    }

    moduleCC1101State[module].setTx(parser.header.frequency / 1000000.0);
    moduleCC1101State[module].applySubConfiguration(parser.moduleParams, 128);
    delay(10);
    boolean signalTransmitted = false;
    signalTransmitted = transmitData(payload, module);
    // parser.displayInfo();
    parser.clearMemory();

    moduleCC1101State[module].restoreConfig().setSidle();
    return signalTransmitted;
}

boolean Transmitter::transmitRawData(const std::vector<int> &rawData, int module)
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

boolean Transmitter::transmitData(PulsePayload &payload, int module)
{
    uint32_t duration;
    bool pinState;
    // std::vector<std::pair<uint32_t, unsigned long>> timingData;

    // unsigned long previousMicros = micros();

    while (payload.next(duration, pinState)) {
        // unsigned long startMicros = micros();

        digitalWrite(moduleCC1101State[module].getOutputPin(), pinState);
        delayMicroseconds(duration);

        // unsigned long endMicros = micros();
        // unsigned long elapsedTime = endMicros - previousMicros;
        // previousMicros = endMicros;

        // timingData.emplace_back(duration, elapsedTime);
        taskYIELD();
    }

    // for (const auto& data : timingData) {
    //     Serial.print("Duration: ");
    //     Serial.print(data.first);
    //     Serial.print(" - Elapsed Time: ");
    //     Serial.println(data.second);
    // }

    return true;
}