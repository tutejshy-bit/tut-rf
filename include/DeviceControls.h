#ifndef Device_Controls_h
#define Device_Controls_h

#include <EEPROM.h>
#include "config.h"
#include "ModuleCc1101.h"
#include "ConfigManager.h"

const int BLINK_ON_TIME = 100;
const int BLINK_OFF_TIME = 10000;

class DeviceControls {
  private:
    static unsigned long blinkTime;

  public:
    static void setup();
    static void onLoadPowerManagement();
    static void goDeepSleep();
    static void ledBlink(int count, int pause);
    static void poweronBlink();
    static void onLoadServiceMode();
};

#endif