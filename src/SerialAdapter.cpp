#include "SerialAdapter.h"

void SerialAdapter::begin()
{
    if (serialQueue == nullptr) {
        serialQueue = xQueueCreate(10, COMMAND_BUFFER_LENGTH * sizeof(char));
    }
    Serial.onReceive(onSerialData);
}

void SerialAdapter::onSerialData()
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    while (Serial.available()) {
        char data = Serial.read();
        SerialAdapter::getInstance().processCharacter(data);
    }
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void SerialAdapter::processCharacter(char data)
{
    if (data == '\r') {
        seenCR = true;
    } else if (data == '\n') {
        if (seenCR) {  // Check if '\r' was seen before '\n'
            buffer[length] = '\0';
            if (length > 0) {
                xQueueSendFromISR(serialQueue, buffer, NULL);
                memset(buffer, 0, COMMAND_BUFFER_LENGTH);
            }
            length = 0;
        } else {
            // If '\r' was not seen before '\n', treat '\n' as normal character
            if (length < COMMAND_BUFFER_LENGTH) {
                buffer[length++] = data;
            }
        }
        seenCR = false;  // Reset the state variable
    } else {
        if (length < COMMAND_BUFFER_LENGTH) {
            buffer[length++] = data;
        }
        seenCR = false;
    }
}

void SerialAdapter::processQueue()
{
    char commandBuffer[COMMAND_BUFFER_LENGTH];
    while (xQueueReceive(serialQueue, &commandBuffer, portMAX_DELAY)) {
        this->simpleCli->parse(commandBuffer);
    }
}

//==================
// Detect Signal
//==================
void SerialAdapter::registerDetectSignalCommand(SimpleCLI& cli)
{
    Command detectCommand = cli.addCmd("detect", commandDetectSignal);
    detectCommand.addArg("r,minrssi", "");
    detectCommand.addArg("m,module", "");
}

void SerialAdapter::commandDetectSignal(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument minRssiArg = cmd.getArg("r");
    Argument moduleArg = cmd.getArg("m");

    Device::TaskDetectSignalBuilder taskBuilder;

    if (minRssiArg.isSet())
        taskBuilder.setMinRssi(minRssiArg.getValue().toInt());
    if (moduleArg.isSet()) {
        int module = moduleArg.getValue().toInt();
        taskBuilder.setModule(module == 2 ? MODULE_2 : MODULE_1);
    }

    Device::TaskDetectSignal task = taskBuilder.build();
    SerialAdapter::getInstance().sendTask(std::move(task));
}

//==================
// Idle
//==================

void SerialAdapter::registerIdleCommand(SimpleCLI& cli)
{
    Command idleCommand = cli.addCmd("idle", commandIdle);
    idleCommand.addArg("m,module", "");
}

void SerialAdapter::commandIdle(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument moduleArg = cmd.getArg("m");
    int module = MODULE_1;
    if (moduleArg.isSet()) {
        module = moduleArg.getValue().toInt() == 2 ? MODULE_2 : MODULE_1;
    }
    Device::TaskIdle task(module);
    SerialAdapter::getInstance().sendTask(std::move(task));
}

//==================
// Get State
//==================

void SerialAdapter::commandGetState(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Device::TaskGetState task(false);
    SerialAdapter::getInstance().sendTask(std::move(task));
}

void SerialAdapter::registerGetStateCommand(SimpleCLI& cli)
{
    cli.addCmd("state", commandGetState);
}

//==================
// File Management
//==================
void SerialAdapter::registerFilesListCommand(SimpleCLI& cli)
{
    Command cmd = cli.addCmd("files", commandGetFilesList);
    cmd.addPosArg("action", "list");
    cmd.addPosArg("arg1", "");
    cmd.addPosArg("arg2", "");
}

void SerialAdapter::commandGetFilesList(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument actionArg = cmd.getArg("action");
    Argument arg1Arg = cmd.getArg("arg1");
    Argument arg2Arg = cmd.getArg("arg2");

    std::unordered_map<std::string, Device::TaskFilesManagerAction> action = {{"list", Device::TaskFilesManagerAction::List},
                                                                              {"delete", Device::TaskFilesManagerAction::Delete},
                                                                              {"rename", Device::TaskFilesManagerAction::Rename},
                                                                              {"create-directory", Device::TaskFilesManagerAction::CreateDirectory},
                                                                              {"get", Device::TaskFilesManagerAction::Load}};

    Device::TaskFilesManagerAction actionType = Device::TaskFilesManagerAction::Unknown;
    for (const auto& pair : action) {
        if (pair.first == actionArg.getValue().c_str()) {
            actionType = pair.second;
            break;
        }
    }

    if (actionType == Device::TaskFilesManagerAction::Unknown) {
        error("{\"error\": \"Unknown action\"}");
        return;
    }

    Device::TaskFilesManager task(actionType);

    switch (actionType) {
        case Device::TaskFilesManagerAction::List:
            if (arg1Arg.isSet()) {
                task.path = arg1Arg.getValue().c_str();
            }
            break;
        case Device::TaskFilesManagerAction::Delete:
            if (!arg1Arg.isSet()) {
                error("\"error\": \"Missing path for deletion\"}");
                return;
            }
            task.path = arg1Arg.getValue().c_str();
            break;
        case Device::TaskFilesManagerAction::Rename:
            if (!arg1Arg.isSet() || !arg2Arg.isSet()) {
                error("\"error\": \"To rename file you need provide paths 'rename /path/from /path/to'\"}");
                return;
            }
            task.path = arg1Arg.getValue().c_str();
            task.pathTo = arg2Arg.getValue().c_str();
            break;
        case Device::TaskFilesManagerAction::CreateDirectory:
            if (!arg1Arg.isSet()) {
                error("\"error\": \"Missing path for directory creation\"}");
                return;
            }
            task.path = arg1Arg.getValue().c_str();
            break;
        case Device::TaskFilesManagerAction::Load:
            if (!arg1Arg.isSet()) {
                error("\"error\": \"Missing path to file to get it's content\"}");
                return;
            }
            task.path = arg1Arg.getValue().c_str();
            break;
    }

    SerialAdapter::getInstance().sendTask(std::move(task));
}

//==================
// File Upload
//==================
void SerialAdapter::registerFileUploadCommand(SimpleCLI& cli)
{
    Command cmd = cli.addCmd("upload", commandFileUpload);
    cmd.addArg("n,name", "");
    cmd.addArg("t,type", "signal");
    cmd.addPosArg("data", "");
}

void SerialAdapter::commandFileUpload(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument nameArg = cmd.getArg("n");
    Argument typeArg = cmd.getArg("t");
    Argument dataArg = cmd.getArg("data");

    String dataString = dataArg.getValue();
    size_t length = dataString.length();

    std::vector<uint8_t> dataRaw(dataString.begin(), dataString.end());
    dataRaw.push_back('\0');

    Device::FileUploadType type;

    if (typeArg.isSet()) {
        type = typeArg.getValue().c_str() == "firmware" ? Device::FileUploadType::Firmware : Device::FileUploadType::File;
    }

    Device::TaskFileUpload task(nameArg.getValue().c_str(), type, 0, dataRaw.data(), length, true);
    SerialAdapter::getInstance().sendTask(std::move(task));
}

//==================
// Record Signal
//==================
void SerialAdapter::registerRecordSignalCommand(SimpleCLI& cli)
{
    Command cmd = cli.addCmd("record", commandRecordSignal);
    cmd.addArg("m,modulation", "");
    cmd.addArg("f,frequency");
    cmd.addArg("d,deviation", "");
    cmd.addArg("b,bandwidth", "");
    cmd.addArg("r,datarate", "");
    cmd.addArg("a,module", "");
    cmd.addArg("p,preset", "");
}

void SerialAdapter::commandRecordSignal(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument frequencyArg = cmd.getArg("f");

    std::vector<Argument> requiredParams = {frequencyArg};
    if (!handleMissingArguments(requiredParams)) {
        return;
    }

    Argument presetArg = cmd.getArg("p");
    Argument moduleArg = cmd.getArg("a");
    Argument dataRateArg = cmd.getArg("r");
    Argument deviationArg = cmd.getArg("d");
    Argument bandwidthArg = cmd.getArg("b");
    Argument modulationArg = cmd.getArg("m");

    Device::TaskRecordBuilder taskBuilder(frequencyArg.getValue().toFloat());

    if (presetArg.isSet()) {
        taskBuilder.setPreset(presetArg.getValue().c_str());
    } else {
        if (deviationArg.isSet())
            taskBuilder.setDeviation(deviationArg.getValue().toFloat());
        if (bandwidthArg.isSet())
            taskBuilder.setRxBandwidth(bandwidthArg.getValue().toFloat());
        if (dataRateArg.isSet())
            taskBuilder.setDataRate(dataRateArg.getValue().toFloat());
        if (modulationArg.isSet()) {
            if (modulationArg.getValue() == "ook") {
                taskBuilder.setModulation(MODULATION_ASK_OOK);
            } else if (modulationArg.getValue() == "2fsk") {
                taskBuilder.setModulation(MODULATION_2_FSK);
            }
        }
    }

    if (moduleArg.isSet()) {
        if (moduleArg.getValue().toInt() == 1) {
            taskBuilder.setModule(MODULE_1);
        } else if (moduleArg.getValue().toInt() == 2) {
            taskBuilder.setModule(MODULE_2);
        } else {
            taskBuilder.setModule(MODULE_1);
        }
    }

    Device::TaskRecord task = taskBuilder.build();
    SerialAdapter::getInstance().sendTask(std::move(task));
    ;
}

//==================
// Transmit Signal
//==================
void SerialAdapter::registerTransmitSignalCommand(SimpleCLI& cli)
{
    Command cmd = cli.addCmd("transmit", commandTransmitSignal);
    cmd.addArg("t,type");
    cmd.addArg("f,frequency", "");
    cmd.addArg("d,data", "");
    cmd.addArg("p,preset", "");
    cmd.addArg("a,module", "");
    cmd.addArg("d,deviation", "");
    cmd.addArg("m,modulation", "");
    cmd.addArg("s,filename", "");
    cmd.addArg("r,repeat", "1");
}

void SerialAdapter::commandTransmitSignal(cmd* commandPointer)
{
    Command cmd(commandPointer);
    Argument typeArg = cmd.getArg("t");
    Argument moduleArg = cmd.getArg("a");
    Argument frequencyArg = cmd.getArg("f");
    Argument modulationArg = cmd.getArg("m");
    Argument dataArg = cmd.getArg("d");
    Argument presetArg = cmd.getArg("p");
    Argument deviationArg = cmd.getArg("d");
    Argument repeatArg = cmd.getArg("r");
    Argument filenameArg = cmd.getArg("s");

    std::vector<Argument> requiredParams;
    Device::TransmissionType type = Device::TransmissionType::Raw;

    if (typeArg.isSet()) {
        if (typeArg.getValue() == "file") {
            type = Device::TransmissionType::File;
            requiredParams.push_back(filenameArg);
        } else if (typeArg.getValue() == "binary") {
            type = Device::TransmissionType::Binary;
        } else if (typeArg.getValue() == "raw") {
            type = Device::TransmissionType::Raw;
            requiredParams.push_back(frequencyArg);
            if (!presetArg.isSet()) {
                requiredParams.push_back(dataArg);
            }
        } else {
            error("\"error\": \"Unsupported transmission type\"}");
        }
    }

    if (!handleMissingArguments(requiredParams)) {
        return;
    }

    Device::TaskTransmissionBuilder taskBuilder(type);

    taskBuilder.setFrequency(frequencyArg.getValue().toFloat());

    if (moduleArg.isSet())
        taskBuilder.setModule(moduleArg.getValue().toInt() == 2 ? MODULE_2 : MODULE_1);
    if (modulationArg.isSet())
        taskBuilder.setModulation(modulationArg.getValue().toInt());
    if (dataArg.isSet())
        taskBuilder.setData(dataArg.getValue().c_str());
    if (presetArg.isSet())
        taskBuilder.setPreset(presetArg.getValue().c_str());
    if (deviationArg.isSet())
        taskBuilder.setDeviation(deviationArg.getValue().toFloat());
    if (repeatArg.isSet())
        taskBuilder.setRepeat(repeatArg.getValue().toInt());
    if (filenameArg.isSet())
        taskBuilder.setFilename(filenameArg.getValue().c_str());

    Device::TaskTransmission task = taskBuilder.build();
    SerialAdapter::getInstance().sendTask(std::move(task));
    ;
}

void SerialAdapter::setup(SimpleCLI& cli)
{
    this->simpleCli = &cli;
    cli.setOnError(errorCallback);
    registerDetectSignalCommand(cli);
    registerRecordSignalCommand(cli);
    registerTransmitSignalCommand(cli);
    registerGetStateCommand(cli);
    registerIdleCommand(cli);
    registerFilesListCommand(cli);
    registerFileUploadCommand(cli);
}

void SerialAdapter::errorCallback(cmd_error* e)
{
    CommandError cmdError(e);
    error(cmdError.toString().c_str());
}

void SerialAdapter::notify(String type, std::string message)
{
    if (!message.empty()) {
        String response;
        if (message[0] != '{' && message[0] != '[') {
            response = "Event: {\"type\":\"" + type + "\",\"data\":\"" + String(message.c_str()) + "\"}";
        } else {
            response = "Event: {\"type\":\"" + type + "\",\"data\":" + String(message.c_str()) + "}";
        }
        writeResponseMessage(response);
    } else {
        Serial.println("message is empty");
    }
}

void SerialAdapter::response(String message)
{
    String response;
    response = "Response: " + message;
    writeResponseMessage(response);
}

void SerialAdapter::error(String message)
{
    String response;
    response = "Error: " + message;
    writeResponseMessage(response);
}

void SerialAdapter::writeResponseMessage(String message)
{
    Serial.println(message);
}

bool SerialAdapter::handleMissingArguments(const std::vector<Argument>& arguments)
{
    std::vector<String> missingParams;
    for (const auto& argument : arguments) {
        if (!argument.isSet()) {
            missingParams.push_back(argument.getName());
        }
    }

    if (!missingParams.empty()) {
        String errorMessage = "{\"error\":\"Missing required arguments: ";
        for (size_t i = 0; i < missingParams.size(); ++i) {
            errorMessage += missingParams[i];
            if (i < missingParams.size() - 1) {
                errorMessage += ", ";
            }
        }
        errorMessage += "\"}";
        error(errorMessage);
        return false;
    }

    return true;
}