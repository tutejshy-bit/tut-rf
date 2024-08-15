#include "DeviceControls.h"

unsigned long DeviceControls::blinkTime = 0;

void DeviceControls::setup()
{
    pinMode(LED, OUTPUT);
    pinMode(BUTTON1, INPUT);
    pinMode(BUTTON2, INPUT);
}

void DeviceControls::onLoadPowerManagement()
{
    EEPROM.begin(EEPROM_SIZE);
    byte deepSleepSavedState = EEPROM.read(DEEP_SLEEP_STATE_ADDRESS);

    if (digitalRead(BUTTON2) != LOW) {
        if (deepSleepSavedState == DEEP_SLEEP_STATE_ON) {
            goDeepSleep();
        }
    } else {
        if (deepSleepSavedState == DEEP_SLEEP_STATE_OFF) {
            EEPROM.write(DEEP_SLEEP_STATE_ADDRESS, DEEP_SLEEP_STATE_ON);
            EEPROM.commit();
            goDeepSleep();
        } else {
            EEPROM.write(DEEP_SLEEP_STATE_ADDRESS, DEEP_SLEEP_STATE_OFF);
            EEPROM.commit();
        }
    }
}

void DeviceControls::goDeepSleep()
{
    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        moduleCC1101State[i].goSleep();
    }
    ledBlink(5, 150);
    esp_deep_sleep_start();
}

void DeviceControls::ledBlink(int count, int pause)
{
    for (int i = 0; i < count; i++) {
        digitalWrite(LED, HIGH);
        delay(pause);
        digitalWrite(LED, LOW);
        delay(pause);
    }
}

void DeviceControls::poweronBlink()
{
    if (millis() - blinkTime > BLINK_OFF_TIME) {
        digitalWrite(LED, LOW);
    }
    if (millis() - blinkTime > BLINK_OFF_TIME + BLINK_ON_TIME) {
        digitalWrite(LED, HIGH);
        blinkTime = millis();
    }
}