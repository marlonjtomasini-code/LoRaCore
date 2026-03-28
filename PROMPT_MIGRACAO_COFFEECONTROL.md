# Prompt: Plano de Migracao CoffeeControl AI - LoRa P2P para LoRaWAN

## Contexto para a IA

Voce e um engenheiro de sistemas embarcados e IoT. Preciso que crie um plano detalhado de migracao do projeto **CoffeeControl AI** de comunicacao **LoRa P2P** para **LoRaWAN**, utilizando uma infraestrutura de referencia ja validada e documentada.

---

## Projeto CoffeeControl AI - Arquitetura Atual (LoRa P2P)

O CoffeeControl AI controla secadores de cafe por `slot`. Cada slot agrega sensores e atuadores no campo que comunicam via **LoRa P2P** (ponto-a-ponto, sem stack LoRaWAN) com um backend FastAPI em uma Raspberry Pi.

### Dispositivos no campo (por slot)

| Dispositivo | Funcao | Frame TX | Frame RX | Alimentacao | Hardware |
|---|---|---|---|---|---|
| `sonda_movel` | Mede T_massa (termopar MAX31856) | A1 | - | Bateria + acelerometro LIS3DSH | CubeCell |
| `sonda_fixa` | Mede T_ar (termopar MAX31856) | A1 | - | Rede eletrica | CubeCell |
| `sensor_amperagem` | Mede corrente RMS bifasica | A4 | - | Rede eletrica | CubeCell + ADS1115 + 2x SCT013 |
| `atuador_bts` | Controla persiana BTS7960 | A3 (ACK) | A2 (cmd) | Rede eletrica | CubeCell |

### Gateway atual

- **Hardware**: Heltec WiFi LoRa 32 V4
- **Funcao**: Ponte de transporte LoRa <-> UART/USB (nao interpreta semantica)
- **Emite**: A5 (diagnostico periodico)

### Cadeia de comunicacao atual (hot path)

```
[Sensores] --LoRa P2P--> [Modem Heltec V4] --UART/USB--> [Backend FastAPI]
                                                               │
[Atuador]  <--LoRa P2P-- [Modem Heltec V4] <--UART/USB-- [Backend FastAPI]
```

- O backend le/escreve diretamente na porta serial via `SerialGateway` e `HeltecSerialAdapter`
- O protocolo A1-A5 e customizado, definido em `firmware/shared/include/cc_protocol.h`
- Latencia minima: o hot path nao passa por nenhum broker ou network server

### Protocolo de frames A1-A5

| Frame | Tipo | Direcao | Conteudo |
|---|---|---|---|
| A1 | Telemetria termica | Device -> Backend | Temperatura (termopar) |
| A2 | Comando de atuacao | Backend -> Device | Comando para persiana |
| A3 | ACK de atuacao | Device -> Backend | Confirmacao de execucao |
| A4 | Telemetria de corrente | Device -> Backend | I_motor_1 + I_motor_2 (RMS) |
| A5 | Diagnostico do modem | Modem -> Backend | Status do gateway |

### Backend FastAPI

- `SerialGateway`: le/escreve bytes na UART
- `IngestWorker`: decodifica frames, atualiza RuntimeStore, dispara avaliacao
- `ThermalController`: controle termico automatico por slot
- `CommandDispatcher`: fila de comandos A2 com prioridade, timeout, retry
- `CalibrationService`: calibracao da curva termica
- `RuntimeStore`: estado operacional efemero (em memoria, fora do banco)
- `StaticConfigStore`: cache de config do SQLite
- Hot path nao depende de SQL

### Requisitos criticos

- **Latencia**: O controle termico depende de telemetria em tempo real. `sonda_fixa` TX a cada 10s, `sonda_movel` a cada 180s
- **Bidirecionalidade**: `atuador_bts` precisa receber comandos A2 e responder A3 com baixa latencia
- **Confiabilidade**: Perda de link por >60s aciona safety (fechamento de persiana)
- **4 slots**: Sistema suporta 4 secadores simultaneos (16+ dispositivos no campo)
- **Watchdog do atuador**: Se nao receber heartbeat/comando em 25s, abre persiana por seguranca

---

## Infraestrutura LoRaWAN de Referencia (ja validada)

A infraestrutura abaixo esta operacional, testada sob stress, e documentada. O objetivo e migrar o CoffeeControl para usa-la.

### Stack no servidor (Raspberry Pi 5, Ubuntu 24.04)

```
RAK2287 (SX1302) --USB--> lora_pkt_fwd --UDP:1700--> chirpstack-mqtt-forwarder --MQTT--> Mosquitto --MQTT--> ChirpStack v4.17.0
```

| Componente | Versao | Funcao |
|---|---|---|
| RAK2287 | SX1302+SX1250 | Concentrador LoRa 8 canais, USB |
| lora_pkt_fwd | sx1302_hal 2.1.0 | Comunicacao com SX1302 via USB |
| chirpstack-mqtt-forwarder | 4.5.1 (Rust) | Converte UDP Semtech -> MQTT |
| Mosquitto | 2.0.18 | Broker MQTT |
| ChirpStack | 4.17.0 | Network Server LoRaWAN |
| PostgreSQL | 16.13 | Banco de dados |
| Redis | 7.0.15 | Cache |
| chirpstack-rest-api | 4.16.0 | API REST na porta 8090 |

### Configuracao RF

- **Regiao**: US915
- **Sub-band**: 1 (canais 0-7, 902.3-903.7 MHz + canal 64 500kHz)
- **Uplink**: 8 canais 125kHz + 1 canal 500kHz
- **Downlink**: 923.3-927.5 MHz
- **ADR**: Habilitado (DR0-DR5, SF7-SF10)
- **Ativacao**: OTAA

### Garantias de confiabilidade

- MQTT QoS 1 em toda a cadeia (at-least-once delivery)
- clean_session = false (mensagens preservadas em reconexao)
- Operacao 100% offline (sem dependencia de internet)
- CPUWeight=200 e Nice=-5 para servicos LoRaWAN
- Buffer UDP 4MB (previne perda sob carga)
- Watchdog do concentrador (reinicio automatico em 2 min)
- Monitor de devices offline (alerta em 3 min)

### Device Profiles disponiveis

| Profile | Classe | Uso |
|---|---|---|
| CubeCell-ClassA-Sensor | A | Sensores TX-only |
| RAK3172-ClassC-Actuator | C | Atuadores TX+RX bidirecional |

### Dados expostos via MQTT (JSON)

Cada uplink de device e publicado em:
```
application/<app_id>/device/<dev_eui>/event/up
```

Payload JSON com campos: `deviceInfo`, `fPort`, `fCnt`, `dr`, `rxInfo` (RSSI, SNR), `object` (dados decodificados pelo codec JS).

### Stress test validado

Sob CPU 100% + I/O saturado por 5 minutos: 97.8% dos pacotes entregues ao ChirpStack. Todos os servicos sobreviveram.

### Documentacao completa

O arquivo `DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md` (v3.0, 22 secoes) documenta toda a configuracao em detalhe suficiente para replicacao.

---

## Tarefa

Crie um plano de migracao detalhado cobrindo os seguintes aspectos:

### 1. Mapeamento de dispositivos

Para cada dispositivo do CoffeeControl, defina:
- Qual Device Profile LoRaWAN usar (ClassA ou ClassC)
- Intervalo de uplink adequado
- Formato do payload LoRaWAN (como encapsular os frames A1-A4 em payloads LoRaWAN)
- Codec JS de decode/encode para o ChirpStack
- Se precisa de confirmed ou unconfirmed uplinks

Considere que:
- `sonda_movel`, `sonda_fixa`, `sensor_amperagem` sao somente TX -> Class A
- `atuador_bts` precisa receber comandos com baixa latencia -> Class C
- O `modem` Heltec V4 e **eliminado** (substituido pela stack LoRaWAN)
- O frame A5 (diagnostico do modem) e **eliminado** (o ChirpStack faz o papel de monitoramento do gateway)

### 2. Impacto no backend FastAPI

O backend atualmente le a porta serial (UART/USB). Com LoRaWAN:
- O transporte muda de serial para MQTT
- O `SerialGateway` e `HeltecSerialAdapter` precisam ser substituidos por um **MQTT client** que consome `application/<app_id>/device/+/event/up`
- O `CommandDispatcher` precisa enviar downlinks via **API REST do ChirpStack** ou publicando em topico MQTT de downlink
- O codec Python (`protocol/codec.py`) precisa ser adaptado para decodificar os payloads LoRaWAN (que ja vem decodificados pelo codec JS do ChirpStack no campo `object`)
- O `RuntimeStore` precisa mapear `dev_eui` para `slot` em vez de `chip_id`
- A latencia do hot path aumenta (~1-2s vs ~100ms do serial direto)

Defina:
- Nova arquitetura do transporte no backend
- O que muda no IngestWorker
- O que muda no CommandDispatcher
- Impacto na latencia e mitigacoes
- Se o watchdog de 25s do atuador e compativel com a latencia do Class C

### 3. Impacto nos firmwares

Todos os firmwares precisam migrar de LoRa P2P para LoRaWAN. Defina:
- Mudancas necessarias em cada firmware
- Como manter o protocolo A1-A4 como payload dentro do LoRaWAN
- Configuracao OTAA (DevEUI, AppKey, JoinEUI, sub-band, channel mask)
- Para o atuador_bts: como implementar Class C e manter o watchdog de seguranca
- Para a sonda_movel: impacto no consumo de bateria com overhead LoRaWAN vs P2P

### 4. Migracao incremental

Proponha uma estrategia de migracao que permita:
- Testar um slot de cada vez
- Manter o sistema atual funcionando enquanto migra
- Rollback se necessario
- Ordem de migracao dos dispositivos (qual primeiro, qual por ultimo)

### 5. Riscos e mitigacoes

Identifique riscos criticos da migracao, especialmente:
- Aumento de latencia no controle do atuador (P2P ~100ms vs LoRaWAN ~1-2s)
- Compatibilidade do watchdog de 25s com Class C
- Capacidade do gateway para 16+ dispositivos a cada 10s
- Perda de link durante OTAA rejoin
- Impacto na sonda_movel (bateria + overhead LoRaWAN)

---

## Restricoes

- A infraestrutura LoRaWAN do servidor **NAO deve ser modificada**. Ela esta validada e documentada. O plano deve adaptar o CoffeeControl a ela.
- Manter o protocolo A1-A4 como payload semantico dentro dos pacotes LoRaWAN (nao reinventar o formato dos dados, apenas o transporte).
- O backend deve continuar sendo FastAPI com a mesma estrutura de workers.
- O SQLite, RuntimeStore e StaticConfigStore permanecem inalterados.
- A regiao RF e US915 sub-band 1. Os dispositivos CubeCell ja usam este hardware.
