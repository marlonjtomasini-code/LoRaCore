/*
 * LoRaCore Stress Test — Device 2 (Agressivo)
 * CubeCell HTCC-AB01 — OTAA US915 SB1
 *
 * TX a cada 3s, CONFIRMED, payload 14 bytes (estendido)
 * DevEUI: 4bcc2ef7a1d06489
 * AppKey: c7f3e92a5d1b084673de9af42b6c815e
 */
#include "LoRaWan_APP.h"
#include "Arduino.h"

/* OTAA Keys — device 2 (registrar no ChirpStack) */
uint8_t devEui[] = { 0x4B, 0xCC, 0x2E, 0xF7, 0xA1, 0xD0, 0x64, 0x89 };
uint8_t appEui[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
uint8_t appKey[] = { 0xC7, 0xF3, 0xE9, 0x2A, 0x5D, 0x1B, 0x08, 0x46,
                     0x73, 0xDE, 0x9A, 0xF4, 0x2B, 0x6C, 0x81, 0x5E };

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
bool     isTxConfirmed        = true;    /* CONFIRMED — gera ACK downlink, mais carga */
uint8_t  confirmedNbTrials    = 8;       /* 8 retries — estresse maximo */
uint8_t  appPort              = 2;
uint32_t appTxDutyCycle       = 3000;    /* 3 segundos — mais agressivo */

static uint32_t txCount = 0;
static uint32_t rxCount = 0;
static uint32_t txFail  = 0;
static uint32_t ackCount = 0;

static void prepareTxFrame(uint8_t port) {
    uint16_t batteryVoltage = getBatteryVoltage();
    uint32_t uptime = millis() / 1000;
    txCount++;

    /*
     * Payload estendido: 14 bytes
     * [deviceId(1)] [bat(2)] [txCount(4)] [uptime(4)] [rxCount(2)] [ackCount(1)]
     */
    appDataSize = 14;
    appData[0]  = 0x02;                              /* device ID marker */
    appData[1]  = (uint8_t)(batteryVoltage >> 8);
    appData[2]  = (uint8_t)(batteryVoltage);
    appData[3]  = (uint8_t)(txCount >> 24);
    appData[4]  = (uint8_t)(txCount >> 16);
    appData[5]  = (uint8_t)(txCount >> 8);
    appData[6]  = (uint8_t)(txCount);
    appData[7]  = (uint8_t)(uptime >> 24);
    appData[8]  = (uint8_t)(uptime >> 16);
    appData[9]  = (uint8_t)(uptime >> 8);
    appData[10] = (uint8_t)(uptime);
    appData[11] = (uint8_t)(rxCount >> 8);
    appData[12] = (uint8_t)(rxCount);
    appData[13] = (uint8_t)(ackCount);

    Serial.printf("[D2][%lus] TX #%lu bat=%dmV fail=%lu rx=%lu ack=%lu\r\n",
                  uptime, txCount, batteryVoltage, txFail, rxCount, ackCount);
}

void downLinkDataHandle(McpsIndication_t *mcpsIndication) {
    rxCount++;
    if (mcpsIndication->AckReceived) {
        ackCount++;
    }
    Serial.printf("[D2] RX #%lu port=%d size=%d ack=%s\r\n",
                  rxCount, mcpsIndication->Port, mcpsIndication->BufferSize,
                  mcpsIndication->AckReceived ? "yes" : "no");
}

void setup() {
    Serial.begin(115200);
    Serial.println("\r\n=== LoRaCore Stress Device 2 ===");
    Serial.println("TX=3s | Confirmed(8 retries) | Payload=14B");
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
