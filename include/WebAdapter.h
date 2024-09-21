#ifndef WebAdapter_h
#define WebAdapter_h

#include "SD.h"
#include "config.h"
#include <Arduino.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include "ControllerAdapter.h"
#include "ModuleCc1101.h"
#include "FilesManager.h"
#include "Update.h"

class WebAdapter: public ControllerAdapter
{
public:
  WebAdapter();

  void notify(String type, std::string message) override;
  void begin(SDFS sd);
  void initStatic(SDFS sd);

  String getName() override {
    return "webAdapter";
  }
private:
  bool staticServed =  false;

  AsyncWebServer* server;
  AsyncEventSource* events;

  void handleDetectSignal();
  void handleGetState() ;
  void handleIdle();
  void handleRecordSignal();
  void handleTransmitSignal();
  void handleTransmitFromFile();
  void handleFilesManagement();
  void handleFileUpload();
  void onEventsConnect();
  bool handleMissingParams(AsyncWebServerRequest* request, const std::vector<String>& requiredParams);
};

extern WebAdapter webAdapter;

#endif // WebAdapter_h