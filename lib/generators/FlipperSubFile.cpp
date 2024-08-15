#include "FlipperSubFile.h"

const std::map<std::string, std::string> FlipperSubFile::presetMapping = {
    {"Ook270", "FuriHalSubGhzPresetOok270Async"},
    {"Ook650", "FuriHalSubGhzPresetOok650Async"},
    {"2FSKDev238", "FuriHalSubGhzPreset2FSKDev238Async"},
    {"2FSKDev476", "FuriHalSubGhzPreset2FSKDev476Async"},
    {"Custom", "FuriHalSubGhzPresetCustom"}
};

void FlipperSubFile::generateRaw(
    File& file,
    const std::string& presetName,
    const std::vector<byte>& customPresetData,
    std::stringstream& samples,
    float frequency
) {
    // Write the header, preset info, and protocol data
    writeHeader(file, frequency);
    writePresetInfo(file, presetName, customPresetData);
    writeRawProtocolData(file, samples);
}

void FlipperSubFile::writeHeader(File& file, float frequency) {
    file.println("Filetype: Flipper SubGhz RAW File");
    file.println("Version: 1");
    file.print("Frequency: ");
    file.print(frequency * 1e6, 0);
    file.println();
}

void FlipperSubFile::writePresetInfo(File& file, const std::string& presetName, const std::vector<byte>& customPresetData) {
    file.print("Preset: ");
    file.println(getPresetName(presetName).c_str());

    if (presetName == "Custom") {
        file.println("Custom_preset_module: CC1101");
        file.print("Custom_preset_data: ");
        for (size_t i = 0; i < customPresetData.size(); ++i) {
            char hexStr[3];
            sprintf(hexStr, "%02X", customPresetData[i]);
            file.print(hexStr);
            if (i < customPresetData.size() - 1) {
                file.print(" ");
            }
        }
        file.println();
    }
}

void FlipperSubFile::writeRawProtocolData(File& file, std::stringstream& samples) {
    file.println("Protocol: RAW");
    file.print("RAW_Data: ");

    std::string sample;
    int wordCount = 0;

    while (getline(samples, sample, ' ')) {
        if (wordCount > 0 && wordCount % 512 == 0) {
            file.println();
            file.print("RAW_Data: ");
        }
        file.print(sample.c_str());
        file.print(' ');
        wordCount++;
    }

    file.println();
}

std::string FlipperSubFile::getPresetName(const std::string& preset) {
    auto it = presetMapping.find(preset);
    if (it != presetMapping.end()) {
        return it->second;
    } else {
        return "FuriHalSubGhzPresetCustom";
    }
}