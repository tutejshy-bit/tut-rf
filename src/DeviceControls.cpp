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
    if (digitalRead(BUTTON2) != LOW && digitalRead(BUTTON1) == LOW) {
        if (ConfigManager::isSleepMode()) {
            goDeepSleep();
        }
    }

    if (digitalRead(BUTTON2) == LOW && digitalRead(BUTTON1) == HIGH) {
        if (!ConfigManager::isSleepMode()) {
            ConfigManager::setSleepMode(1);
            goDeepSleep();
        } else {
            ConfigManager::setSleepMode(0);
        }
    }
}

void DeviceControls::onLoadServiceMode()
{
    if (digitalRead(BUTTON1) == LOW && digitalRead(BUTTON2) == LOW) {
        if (!ConfigManager::isServiceMode()) {
            ConfigManager::setServiceMode(1);
        } else {
            ConfigManager::setServiceMode(0);
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