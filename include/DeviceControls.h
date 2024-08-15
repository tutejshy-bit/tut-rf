#ifndef Device_Controls_h
#define Device_Controls_h

#include <EEPROM.h>
#include "config.h"
#include "ModuleCc1101.h"

const int BLINK_ON_TIME = 100;
const int BLINK_OFF_TIME = 10000;

// EEPROM
const int EEPROM_SIZE = 4096;

// DEEP SLEEP
const int DEEP_SLEEP_STATE_ADDRESS = EEPROM_SIZE - 2;
const byte DEEP_SLEEP_STATE_ON = 1;
const byte DEEP_SLEEP_STATE_OFF = 0;

class DeviceControls {
  private:
    static unsigned long blinkTime;

  public:
    static void setup();
    static void onLoadPowerManagement();
    static void goDeepSleep();
    static void ledBlink(int count, int pause);
    static void poweronBlink();
};

#endif