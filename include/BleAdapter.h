#ifndef BleAdapter_h
#define BleAdapter_h

#include <Arduino.h>
#include "config.h"
#include "ControllerAdapter.h"
#include <string>
#include <vector>
#include <sstream>
#include <map>
#include <stdint.h>
#include "CommandHandler.h"

// Forward declarations

// BLE includes
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include "FS.h"

class BleAdapter : public ControllerAdapter {
public:
    BleAdapter();
    ~BleAdapter();
    void begin();
    void notify(String type, std::string message) override;
    String getName() override { return "BleAdapter"; }
    bool isConnected() const override { return deviceConnected; }
    
    // Установка CommandHandler
    void setCommandHandler(CommandHandler* handler) { commandHandler_ = handler; }
    
    // File streaming method (public for FileCommands access)
    void streamFileData(const uint8_t* header, size_t headerSize, File& file, size_t fileSize);
    
    // Get instance (public for FileCommands access)
    static BleAdapter* getInstance() { return instance; }

private:
    // Server callbacks
    class ServerCallbacks : public BLEServerCallbacks {
        BleAdapter* adapter;
    public:
        ServerCallbacks(BleAdapter* adapter) : adapter(adapter) {}
        void onConnect(BLEServer* pServer) override;
        void onDisconnect(BLEServer* pServer) override;
    };
    
    // Characteristic callbacks for RX (incoming data)
    class CharacteristicCallbacks : public BLECharacteristicCallbacks {
        BleAdapter* adapter;
    public:
        CharacteristicCallbacks(BleAdapter* adapter) : adapter(adapter) {}
        void onWrite(BLECharacteristic* pCharacteristic) override;
    };
    
    // Characteristic callbacks for TX (outgoing notifications)
    class TxCharacteristicCallbacks : public BLECharacteristicCallbacks {
        BleAdapter* adapter;
    public:
        TxCharacteristicCallbacks(BleAdapter* adapter) : adapter(adapter) {}
        void onStatus(BLECharacteristic* pCharacteristic, Status s, uint32_t code) override;
    };
    
    BLEServer* pServer;
    BLEService* pService;
    BLECharacteristic* pTxCharacteristic;
    BLECharacteristic* pRxCharacteristic;
    
    ServerCallbacks* serverCallbacks;
    CharacteristicCallbacks* characteristicCallbacks;
    TxCharacteristicCallbacks* txCharacteristicCallbacks;
    
    bool deviceConnected = false;
    bool oldDeviceConnected = false;
    
    // BLE UUIDs
    static const char* SERVICE_UUID;
    static const char* CHARACTERISTIC_UUID_TX;
    static const char* CHARACTERISTIC_UUID_RX;
    
    // Binary protocol constants
    static const uint8_t MAGIC_BYTE = 0xAA;
    static const uint16_t MAX_CHUNK_SIZE = 500; // Safe maximum: BLE notify limit is 509 bytes, so 509 - 7 (header) - 1 (checksum) - 1 (safety) = 500
    static const uint8_t PACKET_HEADER_SIZE = 7; // Increased from 6: dataLen is now 2 bytes
    
    // Chunking for large responses
    struct ChunkBuffer {
        String data;
        uint8_t totalChunks;
        uint8_t receivedChunks;
        uint32_t timestamp;
        bool isComplete;
    };
    
    std::map<uint8_t, ChunkBuffer> chunkBuffers;
    
    // File upload structure (minimal memory usage - writes chunks directly to file)
    struct FileUploadState {
        File file;
        uint8_t totalChunks;
        uint8_t receivedChunks;
        uint32_t timestamp;
        bool isActive;
        char filePath[256];  // Static buffer for path
    };
    
    std::map<uint8_t, FileUploadState> fileUploads;
    
    // CommandHandler для выполнения команд
    CommandHandler* commandHandler_ = nullptr;
    
    // Command execution is delegated to CommandHandler via handleSingleCommand()
    
    // Binary protocol methods
    void processBinaryData(uint8_t *data, size_t len);
    void handleSingleCommand(uint8_t *payload, size_t payloadLength);
    void handleChunkedCommand(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength);
    void sendBinaryResponse(const String& data);
    void sendChunkedResponse(const String& data);
    void sendSingleChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, const char* chunkData, uint16_t dataLen);
    uint8_t calculateChecksum(const uint8_t *data, size_t len);
    
    // Utility methods
    bool moduleExists(uint8_t module);
    void notifyError(const char *errorMsg);
    void cleanupOldChunks();
    void cleanupOldUploads();
    bool handleUploadChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength);
    
    // Static instance for callbacks
    static BleAdapter* instance;
    
    // Notification synchronization
    static SemaphoreHandle_t notifySemaphore;
    static volatile bool notifyPending;
    
public:
    // Called when notification is confirmed by BLE stack
    static void onNotifyComplete();
};

#endif // BleAdapter_h
