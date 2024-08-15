#ifndef SerialAdapter_h
#define SerialAdapter_h

#define COMMAND_BUFFER_LENGTH 512

#include "ControllerAdapter.h"
#include "ModuleCc1101.h"
#include "HardwareSerial.h"
#include <unordered_map>
#include <string>
#include <vector>
#include <queue>
#include "SimpleCLI.h"

class SerialAdapter: public ControllerAdapter
{
private:
    SerialAdapter() : length(0), seenCR(false), simpleCli(nullptr), serialQueue(NULL) {} // Private constructor for singleton
    SerialAdapter(const SerialAdapter&) = delete;
    SerialAdapter& operator=(const SerialAdapter&) = delete;

    void processCharacter(char data);

    void registerDetectSignalCommand(SimpleCLI& cli);
    void registerRecordSignalCommand(SimpleCLI& cli);
    void registerTransmitSignalCommand(SimpleCLI& cli);
    void registerGetStateCommand(SimpleCLI& cli);
    void registerIdleCommand(SimpleCLI& cli);
    void registerFilesListCommand(SimpleCLI& cli);
    void registerFileUploadCommand(SimpleCLI& cli);

    static void errorCallback(cmd_error* e);
    static void commandDetectSignal(cmd* commandPointer);
    static void commandGetState(cmd* commandPointer);
    static void commandIdle(cmd* commandPointer);
    static void commandRecordSignal(cmd* commandPointer);
    static void commandTransmitSignal(cmd* commandPointer);
    static void commandGetFilesList(cmd* commandPointer);
    static void commandFileUpload(cmd *commandPointer);
    static void response(String);
    static void error(String);
    static void writeResponseMessage(String message);
    static bool handleMissingArguments(const std::vector<Argument> &arguments);

    SimpleCLI* simpleCli;
    char buffer[COMMAND_BUFFER_LENGTH];
    int length = 0;
    bool seenCR = false;

    QueueHandle_t serialQueue;
    static SerialAdapter* instance;

    String getName() override {
        return "serial";
    }
public:
    static SerialAdapter& getInstance() {
        static SerialAdapter instance;
        return instance;
    }

    void begin();
    static void onSerialData();
    void setup(SimpleCLI& cli);
    void processQueue();

    void notify(String type, std::string message) override;
};

#endif