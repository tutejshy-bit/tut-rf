#ifndef Service_Mode_h
#define Service_Mode_h

// WiFi includes removed - ServiceMode disabled for BLE-only operation
// #include <WiFi.h>
// #include <WiFiAP.h>
// #include <ESPmDNS.h>
// #include "SPIFFS.h"
// #include <ESPAsyncWebServer.h>
// #include <esp_wifi.h>
// #include "Update.h"  // Removed - not used, lib_ignore in platformio.ini
#include "ConfigManager.h"

class ServiceMode {
    private:
        // WiFi-dependent functions removed
        // static void serveWebPage();
        // static void initWifi();
    public:
        static void serviceModeStart();
        static void initWifi();
        static void serveWebPage();
        static void handleWebSocketEvent(void *server, void *client, int type, void *arg, uint8_t *data, size_t len);
        static void handleUpload(void *request, String filename, size_t index, uint8_t *data, size_t len, bool final);
        static void handleNotFound(void *request);
};


#endif