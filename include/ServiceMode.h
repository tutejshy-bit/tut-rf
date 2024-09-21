#ifndef Service_Mode_h
#define Service_Mode_h

#include <WiFi.h>
#include <WiFiAP.h>
#include <ESPmDNS.h>
#include "SPIFFS.h"
#include <ESPAsyncWebServer.h>
#include <esp_wifi.h>
#include "Update.h"
#include "ConfigManager.h"

class ServiceMode {
    private:
        static void serveWebPage();
        static void initWifi();
    public:
        static void serviceModeStart();
};


#endif