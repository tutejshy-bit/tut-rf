#ifndef ConfigManager_h
#define ConfigManager_h

#include <SPIFFS.h>

class ConfigManager
{
  public:
    static void createDefaultConfig()
    {
        if (!SPIFFS.exists("/config.txt")) {
            File configFile = SPIFFS.open("/config.txt", FILE_WRITE);
            if (configFile) {
                configFile.println("wifi_mode=ap");
                configFile.println("ssid=Tut RF");
                configFile.println("password=123456789");
                configFile.println("serial_baud_rate=115200");
                configFile.close();
            }
        }
    }

    static void resetConfigToDefault()
    {
        SPIFFS.remove("/config.txt");
        createDefaultConfig();
    }

    static bool saveConfig(const String& config)
    {
        File configFile = SPIFFS.open("/config.txt", FILE_WRITE);
        if (configFile) {
            configFile.print(config);
            configFile.close();
            return true;
        }
        return false;
    }

    static String getPlainConfig()
    {
        String configData = "";
        if (SPIFFS.exists("/config.txt")) {
            File configFile = SPIFFS.open("/config.txt", "r");
            if (configFile) {
                while (configFile.available()) {
                    configData += configFile.readStringUntil('\n');  // Read each line
                    configData += '\n';                              // Ensure each line ends with a newline character
                }
                configFile.close();
            }
        }
        return configData;
    }

    static String getConfigParam(const String& param)
    {
        String config = getPlainConfig();
        int paramIndex = config.indexOf(param + "=");
        if (paramIndex != -1) {
            int endIndex = config.indexOf("\n", paramIndex);
            if (endIndex == -1) {  // If no newline is found, this is the last line
                endIndex = config.length();
            }
            String value = config.substring(paramIndex + param.length() + 1, endIndex);
            value.trim();
            return value;
        }
        return "";
    }

    static bool setFlag(const char* path, bool value)
    {
        if (value) {
            File flagFile = SPIFFS.open(path, FILE_WRITE);
            if (flagFile) {
                flagFile.close();
                return true;
            }
        } else {
            return SPIFFS.remove(path);
        }
        return false;
    }

    static bool isFlagSet(const char* path)
    {
        return SPIFFS.exists(path);
    }

    static void setSleepMode(bool value)
    {
        setFlag("/sleep_mode.flag", value);
    }

    static void setServiceMode(bool value)
    {
        setFlag("/service_mode.flag", value);
    }

    static bool isSleepMode()
    {
        return isFlagSet("/sleep_mode.flag");
    }

    static bool isServiceMode()
    {
        return isFlagSet("/service_mode.flag");
    }
};

#endif  // ConfigManager_h
