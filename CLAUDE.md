# LoRaCore — Instrucoes Especificas

> Diretrizes universais no CLAUDE.md pai (raiz). Aqui apenas info deste projeto.

## Projeto

Kit de infraestrutura LoRaWAN generico para IoT industrial.
Documentacao canonica, templates de configuracao, codecs prontos para deploy.
Firmwares pertencem aos projetos consumidores, nao ao LoRaCore.

## Stack

Gateway RPi5 + RAK2287 (SX1302) / ChirpStack v4.17.0 / PostgreSQL 16 / Redis 7 / Mosquitto 2.0.18
US915 sub-band 1 (canais 0-7 + 64) / OTAA / PlatformIO

## Git

- Branch: `main`

## Deploy (Raspberry Pi 5)

- Maquina: `ssh marlon@192.168.1.200`
- ChirpStack: `http://192.168.1.200:8080` / REST API: `:8090` / MQTT: `:1883`
- Servicos: lora-pkt-fwd, chirpstack-mqtt-forwarder, mosquitto, chirpstack, postgresql, redis-server
- Pos-deploy: `scripts/smoke-test.sh`

## Testes

- Codecs: `node templates/codecs/tests/test-*.js`
- Firmware: `cd examples/firmware/<nome> && pio run`
- Serial: `pio device monitor --baud 115200`

## Governanca Firmware (extensao do pai)

- Plan Mode tambem quando: protocolo firmware-backend
- Testar tambem: parsing/protocolo de comunicacao
- Verificacao de compilacao: `pio run`

## Invariantes: `docs/architecture/INVARIANTS.md`
