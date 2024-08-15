#include "Actions.h"

FilesManager filesManager;

Transmitter transmitter;
Recorder recorder(Handler::signalRecordedHandler);
Detector detector(Handler::signalDetectedHandler);

ClientsManager& clients = ClientsManager::getInstance(); 

Cc1101Mode deviceModes[] = {Cc1101Mode(OperationMode::Idle, nullptr),
                            Cc1101Mode(OperationMode::DetectSignal, Detector::process),
                            Cc1101Mode(OperationMode::RecordSignal, Recorder::process)};


namespace Handler {
void signalRecordedHandler(bool saved, std::string filename)
{
    if (saved) {
        clients.enqueueMessage(NotificationType::SignalRecorded, ("{\"filename\":\"" + filename + "\"}").c_str());
    } else {
        clients.enqueueMessage(NotificationType::FileSystem, ("{\"error\":\"Failed to open the file for writing: " + filename + "\"}").c_str());
    }
}

void signalDetectedHandler(DetectedSignal detectedSignal)
{
    clients.enqueueMessage(NotificationType::SignalDetected, detectedSignal.toJson());
}

void onStateChange(int module, OperationMode mode, OperationMode previousMode)
{
    std::stringstream response;

    // Construct the JSON string
    response << "{\"module\":\"" << module << "\","
             << "\"mode\":\"" << modeToString(mode) << "\","
             << "\"previousMode\":\"" << modeToString(previousMode) << "\"}";
    clients.enqueueMessage(NotificationType::ModeSwitch, response.str().c_str());
}
}  // namespace Handler

namespace Action {

void detectSignal(Device::TaskDetectSignal &task)
{
    int minRssi = task.minRssi ? *task.minRssi : -65;
    detector.setSignalDetectionMinRssi(minRssi);
    int module = task.module ? *task.module : MODULE_1;
    cc1101Control[module].switchMode(OperationMode::DetectSignal);
}

void recordSignal(Device::TaskRecord &task)
{
    std::ostringstream message;
    std::ostringstream errorMessage;

    int module = task.module ? *task.module : MODULE_1;

    if (task.config.preset) {
        const std::string& preset = *task.config.preset;
        if (preset == "Ook270") {
            recorder.setRecordConfig(module, task.config.frequency, MODULATION_ASK_OOK, 2.380371, 270.833333, 3.79372, "Ook270");
        } else if (preset == "Ook650") {
            recorder.setRecordConfig(module, task.config.frequency, MODULATION_ASK_OOK, 2.380371, 650, 3.79372, "Ook650");
        } else if (preset == "2FSKDev238") {
            recorder.setRecordConfig(module, task.config.frequency, MODULATION_2_FSK, 2.380371, 270.833333, 4.79794, "2FSKDev238");
        } else if (preset == "2FSKDev476") {
            recorder.setRecordConfig(module, task.config.frequency, MODULATION_2_FSK, 47.60742, 270.833333, 4.79794, "2FSKDev476");
        } else {
            errorMessage << "{\"error\":\"Can not apply record configuration. Unsupported preset " << preset << "\"}";
        }
    } else {
        int modulation = task.config.modulation ? *task.config.modulation : MODULATION_ASK_OOK;
        float bandwidth = task.config.rxBandwidth ? *task.config.rxBandwidth : 650;
        float deviation = task.config.deviation ? *task.config.deviation : 47.60742;
        float dataRate = task.config.dataRate ? *task.config.dataRate : 4.79794;
        recorder.setRecordConfig(module, task.config.frequency, modulation, deviation, bandwidth, dataRate, "Custom");
    }

    if (errorMessage.str().empty()) {
        cc1101Control[module].switchMode(OperationMode::RecordSignal);
    } else {
        clients.enqueueMessage(NotificationType::SignalRecordError,  errorMessage.str());
    }
}

void transmitFromFile(Device::TaskTransmission &task)
{
    std::ostringstream message;
    std::ostringstream errorMessage;

    boolean signalTransmitted = false;

    if (!task.filename) {
        errorMessage << "{\"error\":\"No filename provided\"}";
    } else if (task.transmissionType == Device::TransmissionType::File) {
        const std::string filename = *task.filename;
        std::string lowerFilename = helpers::string::toLowerCase(filename);
        if (helpers::string::endsWith(filename, ".sub")) {
            signalTransmitted = transmitter.transmitSub(filename, task.module, task.repeat ? *task.repeat : 1);
            if (signalTransmitted) {
                message << "{\"file\":\"" << lowerFilename << "\"}";
            } else {
                errorMessage << "{\"error\":\"Failed to transmit signal from file\",\"file\":\"" << filename << "\"}";
            }
        } else {
            errorMessage << "{\"error\":\"Unsupported file format " << filename << "\"}";
        }
    }

    if (!errorMessage.str().empty()) {
        clients.enqueueMessage(NotificationType::SignalSendingError, errorMessage.str());
    }

    if (!message.str().empty()) {
        clients.enqueueMessage(NotificationType::SignalSent, message.str());
    }
}

void transmitSignal(Device::TaskTransmission &task)
{
    if (task.transmissionType == Device::TransmissionType::File) {
        transmitFromFile(task);
        return;
    }

    std::ostringstream message;
    std::ostringstream errorMessage;
    boolean signalTransmitted = false;

    int modulation = MODULATION_ASK_OOK;
    float deviation = 0;

    if (task.config.preset) {
        const std::string& preset = *task.config.preset;
        if (preset == "Ook270" || preset == "Ook650") {
            modulation = MODULATION_ASK_OOK;
        } else if (preset == "2FSKDev238") {
            modulation = MODULATION_2_FSK;
            deviation = 2.380371;
        } else if (preset == "2FSKDev476") {
            modulation = MODULATION_2_FSK;
            deviation = 47.60742;
        } else {
            errorMessage << "{\"error\":\"Can not apply transmission configuration. Unsupported preset " << preset << "\"}";
        }
    } else {
        if (task.config.modulation) {
            modulation = *task.config.modulation;
        }
        if (task.config.deviation) {
            deviation = *task.config.deviation;
        }
    }

    if (errorMessage.str().empty()) {
        if (task.transmissionType == Device::TransmissionType::Raw) {
            signalTransmitted = transmitter.transmitRaw(task.module, *task.config.frequency, modulation, deviation, *task.data, task.repeat ? *task.repeat : 1);
            if (signalTransmitted) {
                message << "{\"message\":\"Signal transmitted\"}";
            } else {
                errorMessage << "{\"error\":\"Failed to transmit signal\"}";
            }
        } else {
            errorMessage << "{\"error\":\"Unsupported transmission type\"}";
        }
    }

    if (!errorMessage.str().empty()) {
        clients.enqueueMessage(NotificationType::SignalSendingError, errorMessage.str());
    }

    if (!message.str().empty()) {
        clients.enqueueMessage(NotificationType::SignalSent, message.str());
    }
}

void idle(Device::TaskIdle &task)
{
    cc1101Control[task.module].switchMode(OperationMode::Idle);
}

void getCurrentState(Device::TaskGetState &task)
{
    std::stringstream response;
    response << "{";
    
    // Add device information
    response << "\"device\":{";
    response << "\"freeHeap\":" << ESP.getFreeHeap();
    response << "},";

    // Add CC1101 modules information
    response << "\"cc1101\":[";
    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        const byte numSettingsRegisters = 0x2E; // Number of configuration registers as per datasheet
        std::vector<byte> buffer(numSettingsRegisters); // Using std::vector for better memory management
        std::fill(buffer.begin(), buffer.end(), 0);
        moduleCC1101State[i].readAllConfigRegisters(buffer.data(), numSettingsRegisters);

        response << "{";
        response << "\"id\":" << i << ",";

        response << "\"settings\":\"";
        for (byte j = 0; j <= numSettingsRegisters; ++j) {
            response << std::hex << std::uppercase 
                     << std::setw(2) << std::setfill('0') << (int)(j) << " " 
                     << std::setw(2) << std::setfill('0') << (int)buffer[j];
            if (j < numSettingsRegisters) {
                response << " ";
            }
        }
        response << "\",";

        response << "\"mode\":\"" << modeToString(cc1101Control[i].getCurrentMode().getMode()) << "\"";
        response << "}";
        if (i < CC1101_NUM_MODULES - 1) {
            response << ",";
        }
    }
    response << "]}";

    clients.enqueueMessage(NotificationType::State, response.str());
}

void fileOperator(Device::TaskFilesManager &task)
{
    std::string fullPath = FILES_RECORDS_PATH;
    std::ostringstream result;
    std::string fileContent;
    std::string path = task.path;
    std::string pathTo = task.pathTo;

    switch (task.actionType) {
        case Device::TaskFilesManagerAction::List:
            if (!path.empty()) {
                fullPath += std::string("/") + path;
            }
            result << "{\"action\":\"list\",\"files\":" << filesManager.listAllFiles(fullPath) << "}";
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;

        case Device::TaskFilesManagerAction::Delete:
            if (path.empty()) {
                result << "{\"action\":\"delete\",\"error\":\"Path is not provided to delete\"}";
                clients.enqueueMessage(NotificationType::FileSystem, result.str());
                return;
            }
            if (filesManager.remove(std::string(FILES_RECORDS_PATH) + "/" + path)) {
                result << "{\"action\":\"delete\",\"success\":true,\"path\":\"" << path << "\"}";
            } else {
                result << "{\"action\":\"delete\",\"error\":\"Failed to delete file\",\"path\":\"" << path << "\"}";
            }
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;

        case Device::TaskFilesManagerAction::Rename:
            if (path.empty() || pathTo.empty()) {
                result << "{\"action\":\"rename\",\"error\":\"Path from or to is not provided for rename\"}";
                clients.enqueueMessage(NotificationType::FileSystem, result.str());
                return;
            }
            if (filesManager.rename(std::string(FILES_RECORDS_PATH) + "/" + path, std::string(FILES_RECORDS_PATH) + "/" + pathTo)) {
                result << "{\"action\":\"rename\",\"success\":true,\"from\":\"" << path << "\",\"to\":\"" << pathTo << "\"}";
            } else {
                result << "{\"action\":\"rename\",\"error\":\"Failed to rename file\",\"from\":\"" << path << "\",\"to\":\"" << pathTo << "\"}";
            }
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;

        case Device::TaskFilesManagerAction::CreateDirectory:
            if (path.empty()) {
                result << "{\"action\":\"create-directory\",\"error\":\"Path is not provided to create directory\"}";
                clients.enqueueMessage(NotificationType::FileSystem, result.str());
                return;
            }
            if (filesManager.createDirectory(std::string(FILES_RECORDS_PATH) + "/" + path)) {
                result << "{\"action\":\"create-directory\",\"success\":true,\"path\":\"" << path << "\"}";
            } else {
                result << "{\"action\":\"create-directory\",\"error\":\"Failed to create directory\",\"path\":\"" << path << "\"}";
            }
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;

        case Device::TaskFilesManagerAction::Load:
            if (path.empty()) {
                result << "{\"action\":\"load\",\"error\":\"File is not provided\"}";
                clients.enqueueMessage(NotificationType::FileSystem, result.str());
                return;
            }
            fileContent = filesManager.getFile(path);
            result << "{\"action\":\"load\",\"path\":\"" << path << "\",\"success\":true,\"content\":\"" << helpers::string::escapeJson(fileContent) << "\"}";
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;

        default:
            result << "{\"error\":\"Unknown action\"}";
            clients.enqueueMessage(NotificationType::FileSystem, result.str());
            break;
    }
}

void fileUpload(Device::TaskFileUpload &task)
{
    std::string path;

    switch (task.uploadType) {
        case Device::FileUploadType::File:
            path = std::string(FILES_RECORDS_PATH);
            break;

        default:
            clients.enqueueMessage(NotificationType::FileUpload, "{\"error\": \"Unsupported upload type\"}");
            return;
    }

    File outputFile;
    path = path + "/" + task.filename;

    outputFile = filesManager.open(path, !task.index ? FILE_WRITE : FILE_APPEND);

    if (!outputFile) {
        clients.enqueueMessage(NotificationType::FileUpload, "{\"error\": \"Failed to open the file for writing\"}");
        return;
    }

    if (outputFile.write(task.data.data(), task.data.size()) != task.data.size()) {
        outputFile.close();
        clients.enqueueMessage(NotificationType::FileUpload, "{\"error\": \"Failed to write to the file\"}");
        return;
    }

    outputFile.close();

    if (task.final) {
        clients.enqueueMessage(NotificationType::FileUpload, "{\"success\": true, \"filename\": \"" + task.filename + "\"}");
        return;
    }

    return;
}

}  // namespace Action