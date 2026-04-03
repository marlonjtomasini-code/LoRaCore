# Regras de Protocolo Firmware

Aplicar estas regras ao revisar ou escrever codigo de firmware LoRaWAN neste projeto.

## Payload

- Big-endian (MSB first) obrigatorio em todos os campos multi-byte
- Tamanho do payload deve caber no data rate alvo (DR0 = 11 bytes, DR1 = 53 bytes)
- Layout de bytes documentado inline no firmware (`// [campo1(N) campo2(N)]`) e no header do codec correspondente
- Firmware e codec devem concordar campo a campo: ordem, tamanho, tipo (signed/unsigned), escala

## fPort

- Usar fPort entre 1-223 para distinguir tipos de payload (ex: fPort 1 = telemetria, fPort 2 = diagnostico)
- Nunca usar fPort 0 (reservado MAC) nem portas > 223

## OTAA / Credenciais

- `overTheAirActivation = true` sempre; ABP proibido
- devEui e appKey no firmware devem ser placeholders (`0x00`) ou lidos de config externa
- appEui/joinEui = all zeros para ChirpStack v4
- Credenciais de producao nunca commitadas — validar antes de aprovar PR

## Rede

- Regiao: `LORAMAC_REGION_US915`
- Sub-band 1: channel mask `0x00FF` (canais 0-7 + 64)
- Sensores a bateria = Class A; atuadores com alimentacao externa = Class C

## Build

- `pio run` deve passar sem erros antes de commit
- `appDataSize` deve corresponder ao numero real de bytes escritos em `appData[]`

## Atomicidade

- Mudancas no layout de payload exigem alteracao atomica: firmware + codec + backend no mesmo commit
