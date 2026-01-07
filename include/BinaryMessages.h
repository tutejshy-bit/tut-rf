#ifndef BinaryMessages_h
#define BinaryMessages_h

#include <stdint.h>

#pragma pack(push, 1)

// Message type IDs (0x80-0xFF reserved for responses)
enum BinaryMessageType : uint8_t {
    // Status & State messages
    MSG_MODE_SWITCH = 0x80,      // Mode changed
    MSG_STATUS = 0x81,           // Current status
    MSG_HEARTBEAT = 0x82,        // Heartbeat
    
    // Signal events
    MSG_SIGNAL_DETECTED = 0x90,
    MSG_SIGNAL_RECORDED = 0x91,
    MSG_SIGNAL_SENT = 0x92,
    MSG_SIGNAL_SEND_ERROR = 0x93,
    MSG_FREQUENCY_SEARCH = 0x94,  // Frequency search command
    
    // File operations (RAW binary, NO JSON!)
    MSG_FILE_CONTENT = 0xA0,     // Raw file content chunks
    MSG_FILE_LIST = 0xA1,        // File list STREAMING: [0xA1][pathLen][path][flags][totalFiles:2][fileCount][files...]
    MSG_DIRECTORY_TREE = 0xA2,   // Directory tree (nested structure, directories only)
    MSG_FILE_ACTION_RESULT = 0xA3, // Result of file action (rename, delete, etc.)
    
    // Errors
    MSG_ERROR = 0xF0,
    MSG_LOW_MEMORY = 0xF1,
    
    // Command results (generic)
    MSG_COMMAND_SUCCESS = 0xF2,  // Generic success
    MSG_COMMAND_ERROR = 0xF3,    // Generic error
};

// Mode switch notification (4 bytes)
struct BinaryModeSwitch {
    uint8_t messageType = MSG_MODE_SWITCH;
    uint8_t module;
    uint8_t currentMode;
    uint8_t previousMode;
};

// Status message with CC1101 registers (102 bytes)
// 1+1+1+1+4+47+47 = 102 bytes total
struct BinaryStatus {
    uint8_t messageType = MSG_STATUS;
    uint8_t module0Mode;
    uint8_t module1Mode;
    uint8_t numRegisters;           // 0x2E (46 registers)
    uint32_t freeHeap;
    uint8_t module0Registers[47];   // All CC1101 registers for module 0
    uint8_t module1Registers[47];   // All CC1101 registers for module 1
};

// Heartbeat (5 bytes)
struct BinaryHeartbeat {
    uint8_t messageType = MSG_HEARTBEAT;
    uint32_t uptimeMs;
};

// Signal detected (12 bytes)
struct BinarySignalDetected {
    uint8_t messageType = MSG_SIGNAL_DETECTED;
    uint8_t module;
    uint16_t samples;
    uint32_t frequency;
    int16_t rssi;
    uint16_t reserved;
};

// Signal recorded (5 bytes + filename)
struct BinarySignalRecorded {
    uint8_t messageType = MSG_SIGNAL_RECORDED;
    uint8_t module;
    uint8_t filenameLength;
    // char filename[]; // Variable length follows
};

// Signal sent result
struct BinarySignalSent {
    uint8_t messageType = MSG_SIGNAL_SENT;
    uint8_t module;
    uint8_t filenameLength;
    // char filename[];
};

// Signal send error
struct BinarySignalSendError {
    uint8_t messageType = MSG_SIGNAL_SEND_ERROR;
    uint8_t module;
    uint8_t errorCode;
    uint8_t filenameLength;
    // char filename[];
};

// Error message (2 bytes + message)
struct BinaryError {
    uint8_t messageType = MSG_ERROR;
    uint8_t errorCode;
    // char message[]; // Variable length follows
};

// File action result (variable length)
// [type][action:1][status:1][errorCode:1][pathLen:1][path...]
struct BinaryFileActionResult {
    uint8_t messageType = MSG_FILE_ACTION_RESULT;
    uint8_t action;         // 1=delete, 2=rename, 3=mkdir, 4=copy, 5=move
    uint8_t status;         // 0=success, 1=error
    uint8_t errorCode;      // Optional error code
    uint8_t pathLen;
    // char path[];        // Path or filename follows
};

#pragma pack(pop)

#endif // BinaryMessages_h

