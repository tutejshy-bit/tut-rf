#define CC1101_NUM_MODULES 2

// Modulation types
#define MODULATION_2_FSK 0
#define MODULATION_GFSK 1
#define MODULATION_ASK_OOK 2
#define MODULATION_4_FSK 3
#define MODULATION_MSK 4

#if defined(ESP8266)
    #define RECEIVE_ATTR ICACHE_RAM_ATTR
#elif defined(ESP32)
    #define RECEIVE_ATTR IRAM_ATTR
#else
    #define RECEIVE_ATTR
#endif

#define MIN_SAMPLE 30
#define MIN_PULSE_DURATION 50
#define MAX_SIGNAL_DURATION 100000

#define SERIAL_BAUDRATE 115200

// Tasks params
#define NOTIFICATIONS_QUEUE 10

/* I/O */
// SPI devices
#define SD_SCLK 18
#define SD_MISO 19
#define SD_MOSI 23
#define SD_SS   22

#define CC1101_SCK  14
#define CC1101_MISO 12
#define CC1101_MOSI 13
#define CC1101_SS0   5 
#define CC1101_SS1 27
#define MOD0_GDO0 2
#define MOD0_GDO2 4
#define MOD1_GDO0 25
#define MOD1_GDO2 26

// Buttons and led
#define LED 32
#define BUTTON1 34
#define BUTTON2 35
