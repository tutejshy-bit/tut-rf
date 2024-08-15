#include "ModuleCc1101.h"

SemaphoreHandle_t ModuleCc1101::rwSemaphore = xSemaphoreCreateMutex();

static const char* TAG = "Cc1101Config";

ModuleCc1101 moduleCC1101State[] = {ModuleCc1101(CC1101_SCK, CC1101_MISO, CC1101_MOSI, CC1101_SS0, MOD0_GDO2, MOD0_GDO0, MODULE_1),
                                    ModuleCc1101(CC1101_SCK, CC1101_MISO, CC1101_MOSI, CC1101_SS1, MOD1_GDO2, MOD1_GDO0, MODULE_2)};

ModuleCc1101::ModuleCc1101(byte sck, byte miso, byte mosi, byte ss, byte ip, byte op, byte module)
{
    stateChangeSemaphore = xSemaphoreCreateBinary();
    cc1101.addSpiPin(sck, miso, mosi, ss, module);
    cc1101.addGDO(op, ip, module);
    inputPin = ip;
    outputPin = op;
    id = module;
}

SemaphoreHandle_t ModuleCc1101::getStateChangeSemaphore()
{
    return stateChangeSemaphore;
}

void ModuleCc1101::unlock()
{
    xSemaphoreGive(stateChangeSemaphore);
}

ModuleCc1101 ModuleCc1101::backupConfig()
{
    tmpConfig = config;
    return *this;
}

ModuleCc1101 ModuleCc1101::restoreConfig()
{
    config = tmpConfig;
    return *this;
}

ModuleCc1101 ModuleCc1101::setConfig(int mode, float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate)
{
    config.transmitMode = mode == MODE_TRANSMIT;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    config.dcFilterOff = dcFilterOff;
    config.rxBandwidth = rxBandwidth;
    config.dataRate = dataRate;

    return *this;
}

ModuleCc1101 ModuleCc1101::setConfig(CC1101ModuleConfig config)
{
    this->config = config;
    return *this;
}

ModuleCc1101 ModuleCc1101::setReceiveConfig(float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate)
{
    if (config.frequency == frequency && config.dcFilterOff == dcFilterOff && config.modulation == modulation && config.rxBandwidth == rxBandwidth &&
        config.deviation == deviation && config.dataRate == dataRate) {
        ESP_LOGD(TAG, "Config not changed");

        return *this;
    }

    ESP_LOGD(TAG, "Config changed");
    config.transmitMode = false;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    config.dcFilterOff = dcFilterOff;
    config.rxBandwidth = rxBandwidth;
    config.dataRate = dataRate;
    return *this;
}

ModuleCc1101 ModuleCc1101::changeFrequency(float frequency)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    config.frequency = frequency;
    cc1101.setModul(id);
    cc1101.setSidle();
    cc1101.setMHZ(frequency);
    cc1101.SetRx();
    cc1101.setDRate(config.dataRate);
    cc1101.setRxBW(config.rxBandwidth);
    xSemaphoreGive(rwSemaphore);
    return *this;
}

ModuleCc1101 ModuleCc1101::setTransmitConfig(float frequency, int modulation, float deviation)
{
    config.transmitMode = true;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    return *this;
}

CC1101ModuleConfig ModuleCc1101::getCurrentConfig()
{
    return config;
}

byte ModuleCc1101::getId()
{
    return id;
}

int ModuleCc1101::getModulation()
{
    return config.modulation;
}

void ModuleCc1101::init()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.Init();
    xSemaphoreGive(rwSemaphore);
}

ModuleCc1101 ModuleCc1101::initConfig()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setModulation(config.modulation);  // set modulation mode. 0 = 2-FSK, 1 = GFSK, 2 = ASK/OOK, 3 = 4-FSK, 4 = MSK.
    cc1101.setDeviation(config.deviation);  // Set the Frequency deviation in kHz. Value from 1.58 to 380.85. Default is 47.60 kHz.
    cc1101.setMHZ(config.frequency);

    if (config.transmitMode) {
        cc1101.SetTx();
    } else {
        cc1101.SetRx();
        delay(1);
        cc1101.setDcFilterOff(config.dcFilterOff);
        cc1101.setSyncMode(0);  // Combined sync-word qualifier mode. 0 = No preamble/sync. 1 = 16 sync word bits detected. 2 = 16/16 sync word bits detected. 3 =
                                // 30/32 sync word bits detected. 4 = No preamble/sync, carrier-sense above threshold. 5 = 15/16 + carrier-sense above threshold. 6
                                // = 16/16 + carrier-sense above threshold. 7 = 30/32 + carrier-sense above threshold.
        cc1101.setPktFormat(3);  // Format of RX and TX data. 0 = Normal mode, use FIFOs for RX and TX. 1 = Synchronous serial mode, Data in on GDO0 and data out on
                                 // either of the GDOx pins. 2 = Random TX mode; sends random data using PN9 generator. Used for t. Works as normal mode, setting 0
                                 // (00), in RX. 3 = Asynchronous serial mode, Data in on GDO0 and data out on either of the GDOx pins.
        cc1101.setDRate(config.dataRate);
        cc1101.setRxBW(config.rxBandwidth);
    }
    xSemaphoreGive(rwSemaphore);

    return *this;
}

void ModuleCc1101::setTx(float frequency)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    cc1101.Init();
    cc1101.setMHZ(frequency);
    cc1101.SetTx();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::applySubConfiguration(const uint8_t *byteArray, int length)
{
    int index = 0;

    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    while (index < length) {
        uint8_t addr = byteArray[index++];
        uint8_t value = byteArray[index++];

        if (addr == 0x00 && value == 0x00) {
            break;
        }
        cc1101.SpiWriteReg(addr, value);
    }

    std::array<uint8_t, 8> paValue;
    std::copy(byteArray + index, byteArray + index + paValue.size(), paValue.begin());
    cc1101.SpiWriteBurstReg(CC1101_PATABLE, paValue.data(), paValue.size());
    xSemaphoreGive(rwSemaphore);
}

byte ModuleCc1101::getInputPin()
{
    return inputPin;
}

byte ModuleCc1101::getOutputPin()
{
    return outputPin;
}

int ModuleCc1101::getRssi()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    int rssi = cc1101.getRssi();
    xSemaphoreGive(rwSemaphore);
    return rssi;
    }

byte ModuleCc1101::getLqi()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    byte lqi = cc1101.getLqi();
    xSemaphoreGive(rwSemaphore);
    return lqi;
}

void ModuleCc1101::setSidle()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::reset()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSres();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::goSleep()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.goSleep();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::sendData(byte *txBuffer, byte size)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.SendData(txBuffer, size);
    xSemaphoreGive(rwSemaphore);
}

byte ModuleCc1101::getRegisterValue(byte address)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    byte value = cc1101.SpiReadReg(address);
    xSemaphoreGive(rwSemaphore);
    return value;
}

std::array<byte,8> ModuleCc1101::getPATableValues()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    std::array<byte,8> paTable;
    cc1101.setModul(id);
    cc1101.SpiReadBurstReg(0x3E, paTable.data(), paTable.size());
    xSemaphoreGive(rwSemaphore);
    return paTable;
}

void ModuleCc1101::readAllConfigRegisters(byte *buffer, byte num)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.selectModule(id);
    cc1101.SpiReadBurstReg(0x00, buffer, num); // 0x00 is the start address for configuration registers
    xSemaphoreGive(rwSemaphore);
}

float ModuleCc1101::getFrequency()
{
    float fq;
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    fq = cc1101.getFrequency(); // 0x00 is the start address for configuration registers
    xSemaphoreGive(rwSemaphore);
    return fq;
}