# CubeCell OTAA Test

Firmware de **validacao** da infraestrutura LoRaCore. Testa o fluxo completo: OTAA join no ChirpStack, uplink periodico com payload de bateria e contador, e recepcao de downlinks.

**Este firmware e codigo de teste, nao um produto.**

## Hardware

- Heltec CubeCell HTCC-AB01
- Regiao: US915 sub-band 1
- Ativacao: OTAA
- Classe: A

## Configuracao

Antes de usar, altere as credenciais no codigo-fonte:

```cpp
uint8_t devEui[] = { ... };  // DevEUI do seu dispositivo no ChirpStack
uint8_t appKey[] = { ... };  // AppKey gerado no ChirpStack
```

## Build

```bash
# Com PlatformIO
pio run

# Upload
pio run -t upload

# Monitor serial
pio device monitor --baud 115200
```

## Payload

| Byte | Campo | Tipo |
|------|-------|------|
| 0-1 | Tensao bateria (mV) | uint16 big-endian |
| 2-5 | Contador TX | uint32 big-endian |

Use o codec em [`templates/codecs/cubecell-class-a-sensor.js`](../../../templates/codecs/cubecell-class-a-sensor.js) no Device Profile do ChirpStack para decodificar.

## Comportamento

- Join OTAA ao iniciar
- TX a cada 5s + offset aleatorio
- Log serial a 115200 baud: `[timestamp] TX #count bat=XXXXmV`
- Recebe downlinks na porta 2
