# CubeCell OTAA Test — Dual Device

Firmwares de **validacao e stress test** da infraestrutura LoRaCore. Testam o fluxo completo: OTAA join no ChirpStack, uplink periodico e recepcao de downlinks.

**Estes firmwares sao codigo de teste, nao produtos.**

## Devices

| | Device 1 (`src/device1.cpp`) | Device 2 (`src/device2.cpp`) |
|---|---|---|
| **DevEUI** | `3daa1dd8e5ceb357` | `4bcc2ef7a1d06489` |
| **TX intervalo** | 5s + offset aleatorio | 3s + offset aleatorio |
| **Confirmacao** | Unconfirmed | **Confirmed** (8 retries) |
| **Payload** | 7 bytes | 14 bytes |
| **Marker** | `0x01` | `0x02` |
| **Uso** | Baseline, validacao simples | **Stress test v2** |

## Hardware

- Heltec CubeCell HTCC-AB01
- Regiao: US915 sub-band 1
- Ativacao: OTAA
- Classe: A

## Build e Upload

Requer [PlatformIO](https://platformio.org/). O `platformio.ini` define dois environments:

```bash
# Compilar ambos
pio run

# Upload Device 1 (ttyUSB0)
pio run -e cubecell1 -t upload

# Upload Device 2 (ttyUSB1)
pio run -e cubecell2 -t upload

# Monitor serial
pio device monitor -e cubecell1 --baud 115200
pio device monitor -e cubecell2 --baud 115200
```

As portas USB podem variar. Ajuste `upload_port` e `monitor_port` no `platformio.ini` conforme necessario.

## Payloads

### Device 1 — 7 bytes

| Byte | Campo | Tipo |
|------|-------|------|
| 0 | Device ID (`0x01`) | uint8 |
| 1-2 | Tensao bateria (mV) | uint16 big-endian |
| 3-6 | Contador TX | uint32 big-endian |

### Device 2 — 14 bytes

| Byte | Campo | Tipo |
|------|-------|------|
| 0 | Device ID (`0x02`) | uint8 |
| 1-2 | Tensao bateria (mV) | uint16 big-endian |
| 3-6 | Contador TX | uint32 big-endian |
| 7-10 | Uptime (segundos) | uint32 big-endian |
| 11-12 | Contador RX | uint16 big-endian |
| 13 | Contador ACK | uint8 |

Use o codec em [`templates/codecs/cubecell-stress-test-device2.js`](../../../templates/codecs/cubecell-stress-test-device2.js) no Device Profile do ChirpStack para decodificar o Device 2.

## Serial Output

- Device 1: `[D1][Xs] TX #N bat=XXXXmV fail=N rx=N`
- Device 2: `[D2][Xs] TX #N bat=XXXXmV fail=N rx=N ack=N`

## Stress Test v2

O Device 2 foi usado no stress test documentado em [`docs/RELATORIO_STRESS_TEST_V2.md`](../../../docs/RELATORIO_STRESS_TEST_V2.md). Resultado: 79% de entrega sob carga maxima (CPU 100% + mem + IO + disco), validando o MQTT Forwarder (Rust) como substituto do Gateway Bridge (Go).
