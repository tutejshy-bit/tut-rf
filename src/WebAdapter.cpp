#include "WebAdapter.h"

WebAdapter webAdapter;

WebAdapter::WebAdapter() : server(nullptr), events(nullptr) {}

void WebAdapter::begin()
{
    server = new AsyncWebServer(WEB_SERVER_PORT);
    events = new AsyncEventSource("/events");
    events->onConnect([this](AsyncEventSourceClient *client) { onEventsConnect(); });

    server->addHandler(events);
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
    server->begin();

    handleGetState();
    handleDetectSignal();
    handleIdle();
    handleRecordSignal();
    handleTransmitSignal();
    handleTransmitFromFile();
    handleFilesManagement();
    handleFileUpload();
    server->onNotFound([](AsyncWebServerRequest *request) { request->send(404, "text/plain", "Not Found"); });
}

void WebAdapter::initStatic(SDFS sd)
{
    if (!staticServed) {
        server->serveStatic("/", sd, "/HTML").setDefaultFile("index.html");
        staticServed = true;
    }
}

void WebAdapter::handleGetState()
{
    server->on("/getstate", HTTP_GET, [this](AsyncWebServerRequest *request) {
        Device::TaskGetState task(true);
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(std::move(task));
    });
}

void WebAdapter::handleDetectSignal()
{
    server->on("/detect", HTTP_GET, [this](AsyncWebServerRequest *request) {
        Device::TaskDetectSignalBuilder taskBuilder;

        if (request->hasArg("minrssi"))
            taskBuilder.setMinRssi(request->arg("minrssi").toInt());
        if (request->hasArg("module"))
            taskBuilder.setModule(request->arg("module").toInt() == 2 ? MODULE_2 : MODULE_1);

        Device::TaskDetectSignal task = taskBuilder.build();
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(std::move(task));
    });
}

void WebAdapter::handleIdle()
{
    server->on("/idle", HTTP_GET, [this](AsyncWebServerRequest *request) {
        request->send(HTTP_NO_CONTENT, "text/json", "");
        int module = MODULE_1;
        if (request->hasArg("module")) {
            module = request->arg("module").toInt() == 2 ? MODULE_2 : MODULE_1;
        }
        Device::TaskIdle task(module);
        sendTask(std::move(task));
    });
}

void WebAdapter::handleRecordSignal()
{
    server->on("/record", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"frequency"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }

        Device::TaskRecordBuilder taskBuilder(request->arg("frequency").toFloat());

        if (request->hasArg("module"))
            taskBuilder.setModule(request->arg("module").toInt() == 2 ? MODULE_2 : MODULE_1);

        if (request->hasArg("preset")) {
            taskBuilder.setPreset(std::string(request->arg("preset").c_str()));
        } else {
            if (request->hasArg("modulation"))
                taskBuilder.setModulation(request->arg("modulation").toInt());
            if (request->hasArg("deviation"))
                taskBuilder.setDeviation(request->arg("deviation").toFloat());
            if (request->hasArg("rxbandwidth"))
                taskBuilder.setRxBandwidth(request->arg("rxbandwidth").toFloat());
            if (request->hasArg("datarate"))
                taskBuilder.setDataRate(request->arg("datarate").toFloat());
        }

        request->send(HTTP_NO_CONTENT, "text/json", "");
        Device::TaskRecord task = taskBuilder.build();
        sendTask(std::move(task));
    });
}

void WebAdapter::handleTransmitSignal()
{
    server->on("/transmit/signal", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"frequency", "type", "data"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }

        Device::TaskTransmissionBuilder *taskBuilder = nullptr;

        if (request->arg("type") == "raw") {
            taskBuilder = new Device::TaskTransmissionBuilder(Device::TransmissionType::Raw);
        }

        if (taskBuilder != nullptr) {
            taskBuilder->setFrequency(request->arg("frequency").toFloat());
            taskBuilder->setData(request->arg("data").c_str());
            if (request->hasArg("module")) {
                taskBuilder->setModule(request->arg("module").toInt() == 2 ? MODULE_2 : MODULE_1);
            } else {
                taskBuilder->setModule(MODULE_1);
            }
            if (request->hasArg("preset")) {
                taskBuilder->setPreset(request->arg("preset").c_str());
            } else {
                if (request->hasArg("modulation"))
                    taskBuilder->setModulation(request->arg("modulation").toInt());
                if (request->hasArg("deviation"))
                    taskBuilder->setDeviation(request->arg("deviation").toFloat());
            }

            if (request->hasArg("repeat"))
                taskBuilder->setRepeat(request->arg("repeat").toInt());

            Device::TaskTransmission task = taskBuilder->build();

            request->send(HTTP_NO_CONTENT, "text/json", "");
            sendTask(std::move(task));
        } else {
            request->send(HTTP_BAD_REQUEST, "text/json", "Invalid transmission type");
        }
    });
}

void WebAdapter::handleTransmitFromFile()
{
    server->on("/transmit/file", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"file"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }

        Device::TaskTransmission task = Device::TaskTransmissionBuilder(Device::TransmissionType::File).setFilename(request->arg("file").c_str()).build();
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(std::move(task));
    });
}

void WebAdapter::handleFilesManagement()
{
    server->on("/file/list", HTTP_GET, [this](AsyncWebServerRequest *request) {
        Device::TaskFilesManager task(Device::TaskFilesManagerAction::List);
        if (request->hasArg("path"))
            task.path = request->arg("path").c_str();

        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(std::move(task));
    });

    server->on("/file/get", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"file"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }
        Device::TaskFilesManager task = Device::TaskFilesManager(Device::TaskFilesManagerAction::Load, request->arg("file").c_str());
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(std::move(task));
    });

    server->on("/file/create-directory", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"path"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }
        Device::TaskFilesManager task = Device::TaskFilesManager(Device::TaskFilesManagerAction::CreateDirectory, request->arg("path").c_str());
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(task);
    });

    server->on("/file/delete", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"path"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }
        Device::TaskFilesManager task = Device::TaskFilesManager(Device::TaskFilesManagerAction::Delete, request->arg("path").c_str());
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(task);
    });

    server->on("/file/rename", HTTP_GET, [this](AsyncWebServerRequest *request) {
        std::vector<String> requiredParams = {"from", "to"};
        if (!this->handleMissingParams(request, requiredParams)) {
            return;
        }
        Device::TaskFilesManager task = Device::TaskFilesManager(Device::TaskFilesManagerAction::Rename, request->arg("from").c_str(), request->arg("to").c_str());
        request->send(HTTP_NO_CONTENT, "text/json", "");
        sendTask(task);
    });
}

void WebAdapter::handleFileUpload()
{
    server->on(
        "/upload", HTTP_POST, [](AsyncWebServerRequest *request) {},
        [this](AsyncWebServerRequest *request, String filename, size_t index, uint8_t *data, size_t len, bool final) {
            Device::TaskFileUpload task(filename.c_str(), Device::FileUploadType::File, index, data, len, final);
            request->send(HTTP_NO_CONTENT, "text/json", "");
            sendTask(std::move(task));
        });
}

void WebAdapter::notify(String type, std::string message)
{
    String response;
    if (!message.empty()) {
        if (message[0] != '{' && message[0] != '[') {
            response = "{\"type\":\"" + type + "\", \"data\":\"" + String(message.c_str()) + "\"}";
        } else {
            response = "{\"type\":\"" + type + "\", \"data\":" + String(message.c_str()) + "}";
        }
        events->send(response.c_str(), "message", millis());
    } else {
        // Serial.println("message is empty");
    }
}

void WebAdapter::onEventsConnect()
{
    notify("DeviceStatus", "connected");
}

bool WebAdapter::handleMissingParams(AsyncWebServerRequest *request, const std::vector<String> &params)
{
    std::vector<String> missingParams;
    for (const auto &param : params) {
        if (!request->hasArg(param.c_str())) {
            missingParams.push_back(param);
        }
    }

    if (!missingParams.empty()) {
        String errorMessage = "{\"error\":\"Missing parameters: ";
        for (size_t i = 0; i < missingParams.size(); ++i) {
            errorMessage += missingParams[i];
            if (i < missingParams.size() - 1) {
                errorMessage += ", ";
            }
        }
        errorMessage += "\"}";
        request->send(HTTP_OK, "text/json", errorMessage);
        return false;
    }

    return true;
}