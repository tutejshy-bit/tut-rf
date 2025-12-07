#include "ServiceMode.h"

// ServiceMode disabled for BLE-only operation
// All WiFi-dependent functionality has been removed

void ServiceMode::serviceModeStart() {
    Serial.println("ServiceMode disabled - BLE-only operation");
    // ServiceMode functionality removed for BLE-only operation
}

void ServiceMode::initWifi() {
    // WiFi initialization disabled
}

void ServiceMode::serveWebPage() {
    // Web server disabled
}

void ServiceMode::handleWebSocketEvent(void *server, void *client, int type, void *arg, uint8_t *data, size_t len) {
    // WebSocket handling disabled
}

void ServiceMode::handleUpload(void *request, String filename, size_t index, uint8_t *data, size_t len, bool final) {
    // File upload handling disabled
}

void ServiceMode::handleNotFound(void *request) {
    // 404 handling disabled
}