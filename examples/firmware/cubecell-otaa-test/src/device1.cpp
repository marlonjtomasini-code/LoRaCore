/*
 * LoRaCore Stress Test — Device 1 (Baseline)
 * CubeCell HTCC-AB01 — OTAA US915 SB1
 *
 * TX a cada 5s, unconfirmed, payload 6 bytes
 * DevEUI: 3daa1dd8e5ceb357
 * AppKey: ae0a314fd2f6303d18ad170821f37c7d
 */
#include "LoRaWan_APP.h"
#include "Arduino.h"

/* OTAA Keys — device registrado no ChirpStack */
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
bool     isTxConfirmed        = false;   /* unconfirmed */
uint8_t  confirmedNbTrials    = 4;
uint8_t  appPort              = 2;
uint32_t appTxDutyCycle       = 5000;    /* 5 segundos */

static uint32_t txCount = 0;
static uint32_t rxCount = 0;
static uint32_t txFail  = 0;

static void prepareTxFrame(uint8_t port) {
    uint16_t batteryVoltage = getBatteryVoltage();
    txCount++;

    /* Payload: [deviceId(1)] [bat(2)] [txCount(4)] = 7 bytes */
    appDataSize = 7;
    appData[0] = 0x01;                              /* device ID marker */
    appData[1] = (uint8_t)(batteryVoltage >> 8);
    appData[2] = (uint8_t)(batteryVoltage);
    appData[3] = (uint8_t)(txCount >> 24);
    appData[4] = (uint8_t)(txCount >> 16);
    appData[5] = (uint8_t)(txCount >> 8);
    appData[6] = (uint8_t)(txCount);

    Serial.printf("[D1][%lus] TX #%lu bat=%dmV fail=%lu rx=%lu\r\n",
                  millis()/1000, txCount, batteryVoltage, txFail, rxCount);
}

void downLinkDataHandle(McpsIndication_t *mcpsIndication) {
    rxCount++;
    Serial.printf("[D1] RX #%lu port=%d size=%d\r\n",
                  rxCount, mcpsIndication->Port, mcpsIndication->BufferSize);
}

void setup() {
    Serial.begin(115200);
    Serial.println("\r\n=== LoRaCore Stress Device 1 ===");
    Serial.println("TX=5s | Unconfirmed | Payload=7B");
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
