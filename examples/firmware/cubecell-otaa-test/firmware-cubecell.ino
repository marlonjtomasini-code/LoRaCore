#include "LoRaWan_APP.h"
#include "Arduino.h"

/*
 * OTAA Keys - ChirpStack registered device
 * DevEUI:  3daa1dd8e5ceb357
 * AppKey:  ae0a314fd2f6303d18ad170821f37c7d
 * JoinEUI: 0000000000000000
 */
uint8_t devEui[] = { 0x3D, 0xAA, 0x1D, 0xD8, 0xE5, 0xCE, 0xB3, 0x57 };
uint8_t appEui[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
uint8_t appKey[] = { 0xAE, 0x0A, 0x31, 0x4F, 0xD2, 0xF6, 0x30, 0x3D,
                     0x18, 0xAD, 0x17, 0x08, 0x21, 0xF3, 0x7C, 0x7D };

/* ABP placeholders (not used) */
uint8_t nwkSKey[] = { 0 };
uint8_t appSKey[] = { 0 };
uint32_t devAddr  = 0;

/* US915 Sub-band 1 (channels 0-7: 902.3 - 903.7 MHz) */
uint16_t userChannelsMask[6] = { 0x00FF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 };

/* LoRaWAN config */
LoRaMacRegion_t loraWanRegion = LORAMAC_REGION_US915;
DeviceClass_t   loraWanClass  = CLASS_A;
bool     overTheAirActivation = true;
bool     loraWanAdr           = false;
bool     keepNet              = false;
bool     isTxConfirmed        = false;
uint8_t  confirmedNbTrials    = 4;
uint8_t  appPort              = 2;
uint32_t appTxDutyCycle       = 5000;

static uint32_t txCount = 0;

static void prepareTxFrame(uint8_t port) {
    uint16_t batteryVoltage = getBatteryVoltage();
    txCount++;

    appDataSize = 6;
    appData[0] = (uint8_t)(batteryVoltage >> 8);
    appData[1] = (uint8_t)(batteryVoltage);
    appData[2] = (uint8_t)(txCount >> 24);
    appData[3] = (uint8_t)(txCount >> 16);
    appData[4] = (uint8_t)(txCount >> 8);
    appData[5] = (uint8_t)(txCount);

    Serial.printf("[%lu] TX #%lu bat=%dmV\r\n", millis()/1000, txCount, batteryVoltage);
}

void downLinkDataHandle(McpsIndication_t *mcpsIndication) {
    Serial.printf("RX: port=%d, size=%d\r\n", mcpsIndication->Port, mcpsIndication->BufferSize);
}

void setup() {
    Serial.begin(115200);
    deviceState = DEVICE_STATE_INIT;
    LoRaWAN.ifskipjoin();
}

void loop() {
    switch (deviceState) {
        case DEVICE_STATE_INIT:
            LoRaWAN.init(loraWanClass, loraWanRegion);
            deviceState = DEVICE_STATE_JOIN;
            break;

        case DEVICE_STATE_JOIN:
            LoRaWAN.join();
            break;

        case DEVICE_STATE_SEND:
            prepareTxFrame(appPort);
            LoRaWAN.send();
            deviceState = DEVICE_STATE_CYCLE;
            break;

        case DEVICE_STATE_CYCLE:
            txDutyCycleTime = appTxDutyCycle + randr(0, APP_TX_DUTYCYCLE_RND);
            LoRaWAN.cycle(txDutyCycleTime);
            deviceState = DEVICE_STATE_SLEEP;
            break;

        case DEVICE_STATE_SLEEP:
            LoRaWAN.sleep();
            break;

        default:
            deviceState = DEVICE_STATE_INIT;
            break;
    }
}
