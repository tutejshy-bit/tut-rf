#include "Recorder.h"

portMUX_TYPE Recorder::muxes[CC1101_NUM_MODULES];
ReceivedSamples receivedSamples[CC1101_NUM_MODULES];

ReceivedSamples &getReceivedData(int module)
{
    return receivedSamples[module];
}

void Recorder::removeModuleReceiver(int module)
{
    detachInterrupt(digitalPinToInterrupt(moduleCC1101State[module].getInputPin()));
}

void IRAM_ATTR Recorder::receiver(void* arg)
{
    int module = reinterpret_cast<int>(arg);
    receiveSample(module);
}

void Recorder::receiveSample(int module)
{
    const long time = micros();
    portENTER_CRITICAL(&Recorder::muxes[module]);
    ReceivedSamples &data = getReceivedData(module);

    if (data.lastReceiveTime == 0) {
        data.lastReceiveTime = time;
        portEXIT_CRITICAL(&Recorder::muxes[module]);
        return;
    }

    const unsigned int duration = time - data.lastReceiveTime;
    data.lastReceiveTime = time;

    if (duration > MAX_SIGNAL_DURATION) {
        data.samples.clear();
        portEXIT_CRITICAL(&Recorder::muxes[module]);
        return;
    }

    if (duration >= MIN_PULSE_DURATION) {
        data.samples.push_back(duration);
    }

    portEXIT_CRITICAL(&Recorder::muxes[module]);

    if (data.samples.size() >= samplesize) {
        removeModuleReceiver(module);
    }
}

void Recorder::addModuleReceiver(int module)
{
    attachInterruptArg(moduleCC1101State[module].getInputPin(), receiver, reinterpret_cast<void*>(module), CHANGE);
}

std::string Recorder::generateFilename(int module, float frequency, int modulation, float bandwidth)
{
    char filenameBuffer[100];

    sprintf(filenameBuffer, "m%d_%d_%s_%d_%s.sub", module, static_cast<int>(frequency * 100), modulation == MODULATION_ASK_OOK ? "AM" : "FM", static_cast<int>(bandwidth),
            helpers::string::generateRandomString(8).c_str());

    return std::string(filenameBuffer);
}

Recorder::Recorder(RecorderCallback recorderCallback)
{
    this->recorderCallback = recorderCallback;
}

void Recorder::init()
{
    for (int i = 0; i < CC1101_NUM_MODULES; ++i) {
        Recorder::muxes[i] = portMUX_INITIALIZER_UNLOCKED;
    }
}

void Recorder::start(int module)
{
    moduleCC1101State[module]
        .setReceiveConfig(
            recorder.recordConfig[module].frequency,
            recorder.recordConfig[module].modulation == MODULATION_2_FSK ? true : false,
            recorder.recordConfig[module].modulation,
            recorder.recordConfig[module].rxBandwidth,
            recorder.recordConfig[module].deviation,
            recorder.recordConfig[module].dataRate
        ).initConfig();

    recorder.clearReceivedSamples(module);
    addModuleReceiver(module);
}

void Recorder::stop(int module)
{
    removeModuleReceiver(module);
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
}

void Recorder::process(int module)
{
    Recorder::start(module);

    while (true) {
        if (ulTaskNotifyTake(pdTRUE, 0) == 1) {
            break;
        }

        std::vector<unsigned long> samplesCopy;
        unsigned long lastReceiveTime;

        portENTER_CRITICAL_ISR(&Recorder::muxes[module]);
        ReceivedSamples &data = getReceivedData(module);
        samplesCopy = data.samples;
        lastReceiveTime = data.lastReceiveTime;
        portEXIT_CRITICAL_ISR(&Recorder::muxes[module]);

        size_t samplecount = samplesCopy.size();

        if (samplecount >= MIN_SAMPLE && micros() - lastReceiveTime > MAX_SIGNAL_DURATION) {
            removeModuleReceiver(module);
            std::stringstream rawSignal;

            for (int i = 0; i < samplecount; i++) {
                rawSignal << (i > 0 ? (i % 2 == 1 ? " -" : " ") : "");
                rawSignal << samplesCopy[i];
            }

            RecordConfig& config = recorder.recordConfig[module];
            std::string filename = Recorder::generateFilename(module, config.frequency, config.modulation, config.rxBandwidth);
            File outputFile;
            std::string fullPath = "/DATA/RECORDS/" + filename;
            outputFile = SD.open(fullPath.c_str(), FILE_WRITE);
            if (outputFile) {
                const std::string preset = config.preset;
                std::vector<byte> customPresetData;
                if (preset == "Custom") {
                    ModuleCc1101& m = moduleCC1101State[module];
                    customPresetData.insert(customPresetData.end(), {
                        CC1101_MDMCFG4, m.getRegisterValue(CC1101_MDMCFG4),
                        CC1101_MDMCFG3, m.getRegisterValue(CC1101_MDMCFG3),
                        CC1101_MDMCFG2, m.getRegisterValue(CC1101_MDMCFG2),
                        CC1101_DEVIATN, m.getRegisterValue(CC1101_DEVIATN),
                        CC1101_FREND0,  m.getRegisterValue(CC1101_FREND0),
                        0x00, 0x00
                    });

                    std::array<byte, 8> paTable = m.getPATableValues();
                    customPresetData.insert(customPresetData.end(), paTable.begin(), paTable.end());
                }
                FlipperSubFile::generateRaw(outputFile, preset.empty() ? "Custom" : preset, customPresetData, rawSignal, config.frequency);
                outputFile.close();
            } else {
                // @todo: Log/send error
            }
            recorder.recorderCallback(true, filename);

            recorder.clearReceivedSamples(module);
            addModuleReceiver(module);
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
    
    Recorder::stop(module);
    recorder.clearReceivedSamples(module); // Clear samples AFTER detaching interrupt handler
    vTaskDelete(NULL);  // Delete the task itself
}

void Recorder::clearReceivedSamples(int module)
{
    portENTER_CRITICAL_ISR(&Recorder::muxes[module]);
    getReceivedData(module).samples.clear();
    // getReceivedData(module).samplesmooth.clear();
    getReceivedData(module).lastReceiveTime = 0;
    portEXIT_CRITICAL(&Recorder::muxes[module]);
}

void Recorder::setRecordConfig(int module, float frequency, int modulation, float deviation, float rxBandwidth, float dataRate, std::string preset)
{
    recordConfig[module].preset = preset;
    recordConfig[module].frequency = frequency;
    recordConfig[module].modulation = modulation;
    recordConfig[module].deviation = deviation;
    recordConfig[module].rxBandwidth = rxBandwidth;
    recordConfig[module].dataRate = dataRate;
}

// unsigned int Recorder::findPulseDuration(const std::vector<unsigned long> &samples)
// {
//     unsigned long minDuration = *std::min_element(samples.begin(), samples.end());
//     unsigned long maxDuration = minDuration;

//     for (unsigned long sample : samples) {
//         if (sample <= minDuration + MIN_PULSE_DURATION) {
//             maxDuration = std::max(maxDuration, sample);
//         }
//     }

//     return round((minDuration + maxDuration) / 2);
// }

// void Recorder::demodulateAndSmooth(const std::vector<unsigned long> &samples, RecordedSignal &recordedSignal)
// {
//     unsigned int pulseDuration = findPulseDuration(samples);

//     std::stringstream demodulated;
//     std::stringstream smoothed;
//     bool lastbin = false;

//     for (int i = 0; i < samples.size(); i++) {
//         int bitCount = static_cast<int>(round(static_cast<float>(samples[i]) / pulseDuration));
//         if (bitCount > 0) {
//             lastbin = !lastbin;
//             demodulated << std::string(bitCount, lastbin ? '1' : '0');
//         }
//         smoothed << (i > 0 ? (i % 2 == 1 ? " -" : " ") : "") << (bitCount * pulseDuration);
//     }
//     recordedSignal.pulseDuration = pulseDuration;
//     recordedSignal.binary = String(demodulated.str().c_str());
//     recordedSignal.smoothed = String(smoothed.str().c_str());
//     return;
// }
