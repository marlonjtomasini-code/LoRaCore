# Protocolo de Comunicacao LoRaWAN - Documentacao Tecnica

**Projeto**: Rede LoRaWAN para dispositivos IoT
**Data**: 2026-03-28
**Versao**: 3.0
**Classificacao**: Documento tecnico para replicacao de infraestrutura

---

## Indice

1. [Visao Geral da Arquitetura](#1-visao-geral-da-arquitetura)
2. [Hardware Utilizado](#2-hardware-utilizado)
3. [Sistema Operacional e Preparacao do Servidor](#3-sistema-operacional-e-preparacao-do-servidor)
4. [Camada 1 - Concentrador LoRa (Packet Forwarder)](#4-camada-1---concentrador-lora-packet-forwarder)
5. [Camada 2 - MQTT Forwarder (UDP para MQTT)](#5-camada-2---mqtt-forwarder-udp-para-mqtt)
6. [Camada 3 - Broker MQTT (Mosquitto)](#6-camada-3---broker-mqtt-mosquitto)
7. [Camada 4 - Network Server (ChirpStack)](#7-camada-4---network-server-chirpstack)
8. [Camada 5 - Banco de Dados (PostgreSQL)](#8-camada-5---banco-de-dados-postgresql)
9. [Camada 6 - Cache (Redis)](#9-camada-6---cache-redis)
10. [Configuracao de Regiao e Frequencias (US915)](#10-configuracao-de-regiao-e-frequencias-us915)
11. [Plano de Frequencias do Concentrador](#11-plano-de-frequencias-do-concentrador)
12. [Device Profiles e Classes LoRaWAN](#12-device-profiles-e-classes-lorawan)
13. [Fluxo Completo de um Pacote (Uplink e Downlink)](#13-fluxo-completo-de-um-pacote-uplink-e-downlink)
14. [Topicos MQTT e Integracao de Dados](#14-topicos-mqtt-e-integracao-de-dados)
15. [Garantias de Confiabilidade da Comunicacao](#15-garantias-de-confiabilidade-da-comunicacao)
16. [Tuning de Performance do Sistema](#16-tuning-de-performance-do-sistema)
17. [Monitoramento, Watchdog e Backup](#17-monitoramento-watchdog-e-backup)
18. [Servicos systemd e Portas de Rede](#18-servicos-systemd-e-portas-de-rede)
19. [Procedimento de Instalacao Passo a Passo](#19-procedimento-de-instalacao-passo-a-passo)
20. [Registro de Dispositivos](#20-registro-de-dispositivos)
21. [Resultados de Stress Test](#21-resultados-de-stress-test)
22. [Troubleshooting](#22-troubleshooting)

---

## 1. Visao Geral da Arquitetura

```
                          OVER THE AIR (LoRa)
  [Dispositivos IoT] ─────────────────────────────── [Antena]
   CubeCell (Class A)                                    │
   RAK3172  (Class C)                                    │
                                                    [RAK2287]
                                                   SX1302 + SX1250
                                                    USB (ttyACM0)
                                                         │
                                              ┌──────────┴──────────┐
                                              │   RASPBERRY PI 5    │
                                              │                     │
                                              │  ┌───────────────┐  │
                                              │  │ Packet Fwd    │  │  Nice=-5
                                              │  │ (sx1302_hal)  │  │  C, 3MB RAM
                                              │  └──────┬────────┘  │
                                              │         │ UDP:1700  │  Buffer 4MB
                                              │  ┌──────┴────────┐  │
                                              │  │ MQTT Forwarder│  │  Nice=-5, CPUWeight=200
                                              │  │ (Rust, 3.7MB) │  │  QoS 1, clean_session=false
                                              │  └──────┬────────┘  │
                                              │         │ MQTT:1883 │
                                              │  ┌──────┴────────┐  │
                                              │  │  Mosquitto    │  │  Nice=-5, CPUWeight=150
                                              │  │  MQTT Broker  │  │
                                              │  └──────┬────────┘  │
                                              │         │ MQTT      │
                                              │  ┌──────┴────────┐  │
                                              │  │  ChirpStack   │──┼── Web UI :8080
                                              │  │  Network Srv  │──┼── REST API :8090
                                              │  └──┬────────┬───┘  │  Nice=-5, CPUWeight=200
                                              │     │        │      │
                                              │  ┌──┴──┐  ┌──┴──┐  │
                                              │  │Redis│  │Postgr│  │  IOWeight=250
                                              │  │:6379│  │:5432 │  │
                                              │  └─────┘  └─────┘  │
                                              └─────────────────────┘
```

**Protocolo LoRaWAN**: 1.0.3
**Regiao RF**: US915
**Sub-band**: 1 (canais 0-7 + canal 64)
**Ativacao**: OTAA (Over-The-Air Activation)
**ADR**: Habilitado (Adaptive Data Rate)
**MQTT QoS**: 1 (at least once) em todos os trechos
**Sessao MQTT**: Persistente (clean_session = false)
**Operacao**: Funciona 100% offline na rede local (sem dependencia de internet)
**Prioridade de CPU**: Servicos LoRaWAN com Nice=-5 e CPUWeight=200 (prioridade sobre processos normais)
**Buffer UDP**: 4 MB (previne perda de pacotes sob carga)

---

## 2. Hardware Utilizado

### 2.1 Servidor / Gateway

| Componente | Especificacao |
|---|---|
| **Computador** | Raspberry Pi 5 |
| **CPU** | ARM Cortex-A76, 4 cores |
| **RAM** | 8 GB |
| **Armazenamento** | microSD 128 GB |
| **Conectividade** | WiFi (wlan0) |
| **Concentrador LoRa** | RAK2287 (chipset Semtech SX1302 + SX1250) |
| **Interface concentrador** | USB (STM32 Virtual COM Port) |
| **Device USB** | VID:0483 PID:5740 (STMicroelectronics) |
| **Device path** | /dev/ttyACM0 |
| **Concentrador EUI** | 0x0016c001f118e87a |
| **Gateway ID** | 2CCF67FFFE576A1D |

**Geracao do Gateway ID**: Derivado do MAC address da interface wlan0 com insercao de FFFE no centro (padrao EUI-64).

```
MAC wlan0:  2C:CF:67:57:6A:1D
Gateway ID: 2CCF67 FFFE 576A1D
```

### 2.2 Dispositivos Finais (End Devices)

| Dispositivo | Chip | Classe LoRaWAN | Funcao |
|---|---|---|---|
| Heltec CubeCell HTCC-AB01 | ASR6501 | Class A | Somente TX (telemetria) |
| RAK3172 Breakout (RAK3272S) | STM32WLE5CC | Class C | TX + RX (comandos bidirecionais) |

---

## 3. Sistema Operacional e Preparacao do Servidor

### 3.1 Sistema Base

```
SO:     Ubuntu 24.04.4 LTS (Noble Numbat)
Kernel: 6.8.0-1048-raspi (aarch64)
```

### 3.2 Swap (protecao contra OOM)

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 3.3 Limite de logs do Journald

Arquivo: `/etc/systemd/journald.conf.d/size.conf`
```ini
[Journal]
SystemMaxUse=100M
SystemKeepFree=500M
```

```bash
sudo systemctl restart systemd-journald
```

### 3.4 Grupo do usuario

O usuario que executa o packet forwarder deve pertencer ao grupo `dialout` para acesso ao `/dev/ttyACM0`:

```bash
sudo usermod -aG dialout $USER
```

### 3.5 Operacao Offline (sem dependencia de internet)

O sistema opera inteiramente em localhost. Para garantir que funcione sem internet:

**Desabilitar espera por rede no boot:**
```bash
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service
```

**DNS local como fallback** - Arquivo: `/etc/systemd/resolved.conf.d/local.conf`
```ini
[Resolve]
DNS=127.0.0.1
FallbackDNS=
DNSStubListener=yes
```

**Dependencias dos servicos ChirpStack** - Override para nao depender de `network-online.target`:

Arquivo: `/etc/systemd/system/chirpstack.service.d/override.conf`
```ini
[Unit]
Wants=
After=postgresql.service redis-server.service mosquitto.service
Wants=postgresql.service redis-server.service mosquitto.service
```

Arquivo: `/etc/systemd/system/chirpstack-mqtt-forwarder.service.d/priority.conf`

(ver secao 16.1 para configuracao completa de prioridade)

```bash
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved
```

---

## 4. Camada 1 - Concentrador LoRa (Packet Forwarder)

O packet forwarder e o software que se comunica diretamente com o chip SX1302 da RAK2287 via USB e encaminha os pacotes LoRa recebidos para o MQTT Forwarder via protocolo UDP Semtech.

### 4.1 Compilacao

```bash
sudo apt install -y git build-essential
git clone https://github.com/Lora-net/sx1302_hal.git
cd sx1302_hal
make clean && make all
```

### 4.2 Instalacao

```bash
mkdir -p ~/packet_forwarder
cp sx1302_hal/packet_forwarder/lora_pkt_fwd ~/packet_forwarder/
cp sx1302_hal/mcu_bin/* ~/packet_forwarder/
```

O arquivo de configuracao base e `global_conf.json.sx1250.US915.USB` do repositorio sx1302_hal, adaptado para sub-band 1.

### 4.3 Configuracao (global_conf.json)

```json
{
    "SX130x_conf": {
        "com_type": "USB",
        "com_path": "/dev/ttyACM0",
        "lorawan_public": true,
        "clksrc": 0,
        "antenna_gain": 0,
        "full_duplex": false,
        "fine_timestamp": {
            "enable": false,
            "mode": "all_sf"
        },
        "radio_0": {
            "enable": true,
            "type": "SX1250",
            "freq": 902700000,
            "rssi_offset": -215.4,
            "rssi_tcomp": {"coeff_a": 0, "coeff_b": 0, "coeff_c": 20.41, "coeff_d": 2162.56, "coeff_e": 0},
            "tx_enable": true,
            "tx_freq_min": 923000000,
            "tx_freq_max": 928000000,
            "tx_gain_lut": [
                {"rf_power": 12, "pa_gain": 0, "pwr_idx": 15},
                {"rf_power": 13, "pa_gain": 0, "pwr_idx": 16},
                {"rf_power": 14, "pa_gain": 0, "pwr_idx": 17},
                {"rf_power": 15, "pa_gain": 0, "pwr_idx": 19},
                {"rf_power": 16, "pa_gain": 0, "pwr_idx": 20},
                {"rf_power": 17, "pa_gain": 0, "pwr_idx": 22},
                {"rf_power": 18, "pa_gain": 1, "pwr_idx": 1},
                {"rf_power": 19, "pa_gain": 1, "pwr_idx": 2},
                {"rf_power": 20, "pa_gain": 1, "pwr_idx": 3},
                {"rf_power": 21, "pa_gain": 1, "pwr_idx": 4},
                {"rf_power": 22, "pa_gain": 1, "pwr_idx": 5},
                {"rf_power": 23, "pa_gain": 1, "pwr_idx": 6},
                {"rf_power": 24, "pa_gain": 1, "pwr_idx": 7},
                {"rf_power": 25, "pa_gain": 1, "pwr_idx": 9},
                {"rf_power": 26, "pa_gain": 1, "pwr_idx": 11},
                {"rf_power": 27, "pa_gain": 1, "pwr_idx": 14}
            ]
        },
        "radio_1": {
            "enable": true,
            "type": "SX1250",
            "freq": 903400000,
            "rssi_offset": -215.4,
            "rssi_tcomp": {"coeff_a": 0, "coeff_b": 0, "coeff_c": 20.41, "coeff_d": 2162.56, "coeff_e": 0},
            "tx_enable": false
        },
        "chan_multiSF_All": {"spreading_factor_enable": [5, 6, 7, 8, 9, 10, 11, 12]},
        "chan_multiSF_0": {"enable": true, "radio": 0, "if": -400000},
        "chan_multiSF_1": {"enable": true, "radio": 0, "if": -200000},
        "chan_multiSF_2": {"enable": true, "radio": 0, "if":  0},
        "chan_multiSF_3": {"enable": true, "radio": 0, "if":  200000},
        "chan_multiSF_4": {"enable": true, "radio": 1, "if": -300000},
        "chan_multiSF_5": {"enable": true, "radio": 1, "if": -100000},
        "chan_multiSF_6": {"enable": true, "radio": 1, "if":  100000},
        "chan_multiSF_7": {"enable": true, "radio": 1, "if":  300000},
        "chan_Lora_std":  {"enable": true, "radio": 0, "if": 300000, "bandwidth": 500000, "spread_factor": 8,
                           "implicit_hdr": false, "implicit_payload_length": 17, "implicit_crc_en": false, "implicit_coderate": 1},
        "chan_FSK": {"enable": false, "radio": 1, "if": 300000, "bandwidth": 125000, "datarate": 50000}
    },
    "gateway_conf": {
        "gateway_ID": "2CCF67FFFE576A1D",
        "server_address": "localhost",
        "serv_port_up": 1700,
        "serv_port_down": 1700,
        "keepalive_interval": 10,
        "stat_interval": 30,
        "push_timeout_ms": 100,
        "forward_crc_valid": true,
        "forward_crc_error": false,
        "forward_crc_disabled": false,
        "gps_tty_path": ""
    }
}
```

### 4.4 Servico systemd

Arquivo: `/etc/systemd/system/lora-pkt-fwd.service`

```ini
[Unit]
Description=LoRa Packet Forwarder (RAK2287 USB)
After=local-fs.target

[Service]
Type=simple
StandardOutput=journal
StandardError=journal
WorkingDirectory=<PKT_FWD_DIR>
ExecStartPre=/bin/sh -c "test -e /dev/ttyACM0"
ExecStart=<PKT_FWD_DIR>/lora_pkt_fwd
Restart=always
RestartSec=5
WatchdogSec=120
User=<USER>

[Install]
WantedBy=multi-user.target
```

**Detalhes de confiabilidade do servico**:
- `After=local-fs.target`: nao depende de rede, apenas do filesystem (USB)
- `ExecStartPre`: verifica que a RAK2287 esta fisicamente conectada antes de iniciar
- `Restart=always`: reinicia mesmo se o processo sair com codigo 0
- `WatchdogSec=120`: systemd reinicia o processo se travar por mais de 2 minutos

```bash
sudo systemctl daemon-reload
sudo systemctl enable lora-pkt-fwd
sudo systemctl start lora-pkt-fwd
```

### 4.5 Comunicacao

- **Protocolo**: Semtech UDP Packet Forwarder Protocol
- **Direcao Uplink**: Concentrador envia PUSH_DATA para localhost:1700
- **Direcao Downlink**: Concentrador recebe PULL_RESP de localhost:1700
- **Keepalive**: PULL_DATA a cada 10 segundos
- **Stats**: Enviados a cada 30 segundos

---

## 5. Camada 2 - MQTT Forwarder (UDP para MQTT)

O ChirpStack MQTT Forwarder converte o protocolo UDP Semtech em mensagens MQTT e publica diretamente no Mosquitto. Substitui o antigo Gateway Bridge (Go, 14MB) por um binario Rust de 3.7MB, sem garbage collector, significativamente mais resiliente sob carga.

**Justificativa da escolha**: Em stress test com CPU 100% + I/O saturado, o antigo Gateway Bridge (Go) perdeu 100% dos pacotes. O MQTT Forwarder (Rust) sob a mesma carga entregou 97.8% dos pacotes ao ChirpStack. A ausencia de garbage collector no Rust elimina pausas imprevisiveis que o Go sofre sob contencao de CPU.

### 5.1 Instalacao

```bash
# Repositorio ChirpStack (mesmo das outras dependencias)
sudo apt install chirpstack-mqtt-forwarder
```

**Versao**: 4.5.1

### 5.2 Configuracao

Arquivo: `/etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml`

```toml
[logging]
  level="info"
  log_to_syslog=false

[mqtt]
  topic_prefix="us915_0"
  json=false
  server="tcp://127.0.0.1:1883"
  qos=1
  clean_session=false
  keep_alive_interval="30s"

[backend]
  enabled="semtech_udp"

  [backend.filters]
    forward_crc_ok=true
    forward_crc_invalid=false
    forward_crc_missing=false

  [backend.semtech_udp]
    bind="0.0.0.0:1700"
    time_fallback_enabled=true
```

**Pontos criticos**:
- O `bind` em porta 1700 deve coincidir com `serv_port_up`/`serv_port_down` do packet forwarder
- O `topic_prefix` "us915_0" deve coincidir com o `topic_prefix` na configuracao de regiao do ChirpStack
- **`qos=1`**: garante entrega "at least once". Pacotes nao se perdem se o Mosquitto estiver momentaneamente ocupado
- **`clean_session=false`**: ao reconectar ao Mosquitto, mensagens enfileiradas durante a desconexao sao entregues retroativamente
- **`time_fallback_enabled=true`**: usa hora do servidor se o packet forwarder nao enviar timestamp (mais robusto)
- **`forward_crc_invalid=false`**: descarta pacotes com CRC invalido (evita processar lixo RF)

### 5.3 Prioridade de CPU

Arquivo: `/etc/systemd/system/chirpstack-mqtt-forwarder.service.d/priority.conf`

```ini
[Service]
Nice=-5
CPUWeight=200
IOWeight=200
```

O `CPUWeight=200` (default=100) garante que sob contencao de CPU, o MQTT Forwarder recebe o dobro de tempo de CPU que processos normais. O `Nice=-5` eleva a prioridade no scheduler do kernel.

```bash
sudo systemctl enable chirpstack-mqtt-forwarder
sudo systemctl start chirpstack-mqtt-forwarder
```

---

## 6. Camada 3 - Broker MQTT (Mosquitto)

O Mosquitto e o broker MQTT que intermedeia a comunicacao entre o MQTT Forwarder e o ChirpStack. Tambem expoe os dados de aplicacao para integracao externa.

### 6.1 Instalacao

```bash
sudo apt install mosquitto mosquitto-clients
```

**Versao**: 2.0.18

### 6.2 Configuracao

Arquivo principal: `/etc/mosquitto/mosquitto.conf`
```conf
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
include_dir /etc/mosquitto/conf.d
```

Arquivo de producao: `/etc/mosquitto/conf.d/production.conf`
```conf
max_connections 200
max_queued_messages 5000
max_inflight_messages 40
autosave_interval 300
allow_anonymous true
```

### 6.3 Porta

| Porta | Protocolo | Uso |
|---|---|---|
| 1883 | MQTT (TCP) | Comunicacao interna entre componentes |

---

## 7. Camada 4 - Network Server (ChirpStack)

O ChirpStack e o servidor LoRaWAN que gerencia dispositivos, processa joins OTAA, roteia mensagens, executa ADR e expoe a interface web.

### 7.1 Instalacao

```bash
sudo apt install chirpstack chirpstack-rest-api
```

**Versoes**:
- ChirpStack: 4.17.0
- ChirpStack REST API: 4.16.0

### 7.2 Configuracao Principal

Arquivo: `/etc/chirpstack/chirpstack.toml`

```toml
[logging]
  level = "info"

[postgresql]
  dsn = "postgres://chirpstack:chirpstack@localhost/chirpstack?sslmode=disable"
  max_open_connections = 30
  min_idle_connections = 5
  connection_recycling_method = "verified"

[redis]
  servers = ["redis://localhost/"]
  cluster = false

[network]
  net_id = "000000"
  enabled_regions = ["us915_0"]

[api]
  bind = "0.0.0.0:8080"
  secret = "<GERAR COM: openssl rand -base64 32>"

[integration]
  enabled = ["mqtt"]
  [integration.mqtt]
    server = "tcp://localhost:1883/"
    json = true
    qos = 1
    clean_session = false
```

**Pontos criticos**:
- O `secret` DEVE ser unico por instalacao (gerar com `openssl rand -base64 32`)
- `json = true` na integracao MQTT faz o ChirpStack publicar eventos de aplicacao em JSON (facilita debug e integracao)
- `enabled_regions` deve conter exatamente as regioes configuradas nos arquivos `region_*.toml`
- **`qos = 1`**: garante que eventos de aplicacao (uplinks decodificados, joins, ACKs) sejam entregues ao Mosquitto mesmo sob carga
- **`clean_session = false`**: preserva subscricoes e mensagens pendentes apos reconexao

### 7.3 Portas e Interfaces

| Porta | Servico | Protocolo | Uso |
|---|---|---|---|
| 8080 | ChirpStack | HTTP/gRPC | Web UI + API gRPC |
| 8090 | REST API | HTTP | API REST (proxy gRPC-to-REST) |

### 7.4 Acesso a Interface Web

```
URL:   http://<IP_DO_SERVIDOR>:8080
Login: admin
Senha: admin (alterar no primeiro acesso)
```

### 7.5 REST API

O pacote `chirpstack-rest-api` expoe a API gRPC como REST na porta 8090.

Arquivo de ambiente: `/etc/chirpstack-rest-api/environment`
```
BIND=0.0.0.0:8090
SERVER=0.0.0.0:8080
INSECURE=true
```

### 7.6 Geracao de API Keys

```bash
sudo chirpstack -c /etc/chirpstack create-api-key --name <nome>
```

Uso em chamadas HTTP:
```
Header: Grpc-Metadata-Authorization: Bearer <token>
```

---

## 8. Camada 5 - Banco de Dados (PostgreSQL)

### 8.1 Instalacao e Criacao do Banco

```bash
sudo apt install postgresql
sudo -u postgres psql -c "CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';"
sudo -u postgres psql -c "CREATE DATABASE chirpstack WITH OWNER chirpstack;"
sudo -u postgres psql -d chirpstack -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

**Versao**: 16.13

### 8.2 Tuning para Producao

Arquivo: `/etc/postgresql/16/main/postgresql.conf`

| Parametro | Valor | Razao |
|---|---|---|
| `shared_buffers` | 512MB | Cache de paginas em memoria (~6% da RAM de 8GB) |
| `work_mem` | 8MB | Memoria por operacao de sort/hash |
| `max_connections` | 200 | Margem para ChirpStack (pool=30) + futuras integracoes |
| `effective_cache_size` | 4GB | Estimativa de cache do SO para o query planner |

```bash
sudo systemctl restart postgresql
```

---

## 9. Camada 6 - Cache (Redis)

### 9.1 Instalacao

```bash
sudo apt install redis-server
```

**Versao**: 7.0.15

### 9.2 Configuracao para Producao

Arquivo: `/etc/redis/redis.conf`

| Parametro | Valor | Razao |
|---|---|---|
| `maxmemory` | 512mb | Limite de memoria (evita OOM) |
| `maxmemory-policy` | allkeys-lru | Evicta chaves menos usadas quando atinge o limite |
| `appendonly` | yes | Persistencia em disco (sobrevive a reinicio) |
| `appendfsync` | everysec | Sincroniza AOF a cada segundo (equilibrio performance/durabilidade) |

```bash
sudo systemctl restart redis-server
```

---

## 10. Configuracao de Regiao e Frequencias (US915)

### 10.1 Arquivo de Regiao

Arquivo: `/etc/chirpstack/region_us915_0.toml`

Parametros essenciais da secao `[regions.network]`:

| Parametro | Valor | Descricao |
|---|---|---|
| `id` | us915_0 | Identificador da regiao |
| `common_name` | US915 | Nome padrao LoRa Alliance |
| `installation_margin` | 10 dB | Margem do ADR (maior = mais conservador) |
| `rx_window` | 0 | Usa RX1 e RX2 |
| `rx1_delay` | 1 s | Delay entre TX e abertura da janela RX1 |
| `rx1_dr_offset` | 0 | Offset do data rate na RX1 |
| `rx2_dr` | 8 | Data rate da janela RX2 (SF12/500kHz) |
| `rx2_frequency` | 923300000 Hz | Frequencia fixa da janela RX2 |
| `adr_disabled` | false | ADR habilitado |
| `min_dr` | 0 | DR minimo permitido (SF10/125kHz) |
| `max_dr` | 5 | DR maximo permitido (SF7/125kHz) |
| `enabled_uplink_channels` | [0,1,2,3,4,5,6,7,64] | Sub-band 1 + canal 500kHz |

### 10.2 Topico MQTT do Gateway

Configuracao na secao `[regions.gateway.backend.mqtt]`:

```toml
topic_prefix = "us915_0"
share_name = "chirpstack"
server = "tcp://localhost:1883"
qos = 1
clean_session = false
```

**Pontos criticos**:
- O prefixo `us915_0` nos topicos MQTT e o elo entre o MQTT Forwarder e o ChirpStack. Ambos devem usar exatamente o mesmo prefixo
- **`qos = 1`**: lado ChirpStack tambem consome com QoS 1, garantindo entrega bidirecional confiavel
- **`clean_session = false`**: ja configurado por padrao neste arquivo

---

## 11. Plano de Frequencias do Concentrador

### 11.1 US915 Sub-band 1

O concentrador SX1302 possui dois radios. Cada radio cobre uma faixa de ~800 kHz. Os canais sao definidos como offsets (IF) em relacao a frequencia central de cada radio.

```
Radio 0: centro em 902.700 MHz (cobre canais 0-3)
Radio 1: centro em 903.400 MHz (cobre canais 4-7)
```

### 11.2 Mapa de Canais Uplink (125 kHz)

| Canal | Frequencia (MHz) | Radio | IF Offset (Hz) | Modulacao |
|---|---|---|---|---|
| 0 | 902.3 | 0 | -400000 | LoRa 125 kHz, SF7-SF12 |
| 1 | 902.5 | 0 | -200000 | LoRa 125 kHz, SF7-SF12 |
| 2 | 902.7 | 0 | 0 | LoRa 125 kHz, SF7-SF12 |
| 3 | 902.9 | 0 | +200000 | LoRa 125 kHz, SF7-SF12 |
| 4 | 903.1 | 1 | -300000 | LoRa 125 kHz, SF7-SF12 |
| 5 | 903.3 | 1 | -100000 | LoRa 125 kHz, SF7-SF12 |
| 6 | 903.5 | 1 | +100000 | LoRa 125 kHz, SF7-SF12 |
| 7 | 903.7 | 1 | +300000 | LoRa 125 kHz, SF7-SF12 |

### 11.3 Canal Uplink 500 kHz (Canal 64)

| Canal | Frequencia (MHz) | Radio | IF Offset (Hz) | Modulacao |
|---|---|---|---|---|
| 64 | 903.0 | 0 | +300000 | LoRa 500 kHz, SF8 fixo |

### 11.4 Frequencias de Downlink

Os downlinks US915 usam frequencias fixas derivadas do canal de uplink:

```
Downlink freq = 923.3 + 0.6 * (canal_uplink % 8) MHz
```

| Canal Uplink | Frequencia Downlink (MHz) |
|---|---|
| 0 | 923.3 |
| 1 | 923.9 |
| 2 | 924.5 |
| 3 | 925.1 |
| 4 | 925.7 |
| 5 | 926.3 |
| 6 | 926.9 |
| 7 | 927.5 |

Faixa de TX configurada no concentrador: 923.0 - 928.0 MHz

### 11.5 Janela RX2 (fixa para US915)

```
Frequencia: 923.3 MHz
Data Rate:  DR8 (SF12/500kHz)
```

---

## 12. Device Profiles e Classes LoRaWAN

### 12.1 Profiles Configurados

| Profile | ID | Classe | OTAA | ClassC Timeout | Uso |
|---|---|---|---|---|---|
| CubeCell-ClassA-Sensor | ed752293-bebb-40a9-9432-8b644f504413 | A | Sim | N/A | Sensores TX-only |
| RAK3172-ClassC-Actuator | f1812613-bc5d-413a-be6a-f6ed2a26afff | C | Sim | 8s | Atuadores TX+RX |

Todos os profiles usam:
- **LoRaWAN**: 1.0.3
- **Regional Parameters Revision**: A
- **ADR Algorithm**: default
- **Uplink Interval**: 60 segundos

### 12.2 Comportamento Class A (CubeCell)

```
Device transmite (TX)
  └─ Abre janela RX1 (1s apos TX, mesma frequencia de downlink correspondente)
      └─ Abre janela RX2 (2s apos TX, 923.3 MHz, DR8)
          └─ Entra em sleep ate proximo ciclo TX
```

- Downlinks so sao possivel imediatamente apos um uplink
- Consumo minimo de energia (ideal para bateria)

### 12.3 Comportamento Class C (RAK3172)

```
Device transmite (TX)
  └─ Abre janela RX1 (1s apos TX)
      └─ Abre janela RX2 (2s apos TX)
          └─ Abre janela RXC (continua, mesmos parametros de RX2: 923.3 MHz, DR8)
              └─ Escuta continuamente ate proximo TX
```

- Downlinks podem ser enviados a qualquer momento (sem esperar uplink)
- Latencia minima para comandos
- Requer alimentacao continua (nao adequado para bateria)
- `classCTimeout = 8s`: tempo que o servidor espera por ACK em confirmed downlinks

### 12.4 Codecs de Payload

**CubeCell-ClassA-Sensor** (decode uplink):
```javascript
function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) return { data: {} };
  var batteryMv = (bytes[0] << 8) | bytes[1];
  var uptimeSec = (bytes[2] << 8) | bytes[3];
  return {
    data: {
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      uptime_s: uptimeSec
    }
  };
}
```

**RAK3172-ClassC-Actuator** (decode uplink + encode downlink):
```javascript
// Decode uplink
function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) return { data: {} };
  var batteryMv = (bytes[0] << 8) | bytes[1];
  var status = bytes[2];
  var gpioState = bytes[3];
  return {
    data: {
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      status: status,
      gpio_state: gpioState
    }
  };
}

// Encode downlink (servidor -> device)
function encodeDownlink(input) {
  var cmd = input.data.command || 0;
  var val = input.data.value || 0;
  return { bytes: [cmd, val] };
}
```

---

## 13. Fluxo Completo de um Pacote (Uplink e Downlink)

### 13.1 Uplink (Device -> Servidor)

```
1. Device transmite pacote LoRa em um dos canais 0-7 (902.3-903.7 MHz)
   Modulacao: LoRa, BW=125kHz, SF definido pelo ADR (SF7-SF12)
   Potencia: 20 dBm

2. RAK2287 (SX1302) recebe e demodula o pacote
   Adiciona metadados: RSSI, SNR, timestamp, frequencia, data rate

3. Packet Forwarder empacota em PUSH_DATA (protocolo UDP Semtech)
   Envia para localhost:1700

4. MQTT Forwarder recebe o UDP, converte para Protobuf
   Publica no MQTT: us915_0/gateway/2ccf67fffe576a1d/event/up

5. ChirpStack consome o topico MQTT
   - Verifica MIC (Message Integrity Code) com as chaves da sessao
   - Incrementa frame counter
   - Decodifica payload com o codec JS do device profile
   - Publica dados decodificados: application/<app_id>/device/<dev_eui>/event/up

6. Aplicacao externa consome os dados via MQTT ou REST API
```

### 13.2 Downlink (Servidor -> Device)

**Class A:**
```
1. Aplicacao envia comando via API ou MQTT
2. ChirpStack enfileira o downlink
3. Aguarda proximo uplink do device
4. Ao receber uplink, envia downlink na janela RX1 ou RX2
5. Publica ACK: us915_0/gateway/<gw_id>/event/ack
```

**Class C:**
```
1. Aplicacao envia comando via API ou MQTT
2. ChirpStack envia imediatamente via MQTT: us915_0/gateway/<gw_id>/command/down
3. MQTT Forwarder converte para UDP e envia ao Packet Forwarder
4. Concentrador transmite na frequencia/DR da janela RXC (923.3 MHz, DR8)
5. Device recebe imediatamente (esta sempre escutando)
```

---

## 14. Topicos MQTT e Integracao de Dados

### 14.1 Topicos do Gateway (Protobuf)

| Topico | Direcao | Conteudo |
|---|---|---|
| `us915_0/gateway/<gw_id>/event/up` | GW -> CS | Pacote uplink recebido |
| `us915_0/gateway/<gw_id>/event/stats` | GW -> CS | Estatisticas do gateway (a cada 30s) |
| `us915_0/gateway/<gw_id>/event/ack` | GW -> CS | Confirmacao de downlink transmitido |
| `us915_0/gateway/<gw_id>/command/down` | CS -> GW | Comando de downlink para transmitir |

### 14.2 Topicos de Aplicacao (JSON)

| Topico | Evento | Conteudo |
|---|---|---|
| `application/<app_id>/device/<dev_eui>/event/up` | Uplink | Dados decodificados do device |
| `application/<app_id>/device/<dev_eui>/event/join` | Join | Notificacao de OTAA join |
| `application/<app_id>/device/<dev_eui>/event/status` | Status | Margem e bateria do device |
| `application/<app_id>/device/<dev_eui>/event/ack` | ACK | Confirmacao de downlink recebido |
| `application/<app_id>/device/<dev_eui>/event/log` | Log | Frame log (uplink/downlink) |

### 14.3 Exemplo de Payload JSON de Uplink

```json
{
  "deviceInfo": {
    "tenantId": "6ab88d75-...",
    "applicationId": "e7e90971-...",
    "deviceName": "sensor-01",
    "devEui": "3daa1dd8e5ceb357",
    "deviceProfileName": "CubeCell-ClassA-Sensor"
  },
  "fPort": 2,
  "fCnt": 42,
  "dr": 3,
  "txInfo": {
    "frequency": 902500000
  },
  "rxInfo": [
    {
      "gatewayId": "2ccf67fffe576a1d",
      "rssi": -62,
      "snr": 13.5
    }
  ],
  "object": {
    "battery_mv": 3700,
    "battery_v": 3.7,
    "uptime_s": 3600
  }
}
```

### 14.4 Monitoramento MQTT via Linha de Comando

```bash
# Todos os uplinks de aplicacao (JSON)
mosquitto_sub -h localhost -t "application/+/device/+/event/up" -v

# Stats do gateway
mosquitto_sub -h localhost -t "us915_0/gateway/+/event/stats" -v

# Todos os eventos de um device especifico
mosquitto_sub -h localhost -t "application/+/device/3daa1dd8e5ceb357/event/#" -v
```

---

## 15. Garantias de Confiabilidade da Comunicacao

Esta secao documenta os mecanismos implementados para garantir confiabilidade em operacao critica.

### 15.1 QoS 1 em Toda a Cadeia MQTT

```
Packet Fwd ──UDP──> MQTT Forwarder ──MQTT QoS 1──> Mosquitto ──MQTT QoS 1──> ChirpStack
                                                        │
                                                        └── MQTT QoS 1 ──> Aplicacao externa
```

**QoS 0 (descartado)**: "at most once" - pacote pode ser perdido silenciosamente.
**QoS 1 (implementado)**: "at least once" - Mosquitto confirma recebimento; se nao confirmar, o publicador reenvia.

Pontos onde QoS 1 esta configurado:
- MQTT Forwarder -> Mosquitto (`chirpstack-mqtt-forwarder.toml`: `qos=1`)
- Mosquitto -> ChirpStack (`region_us915_0.toml`: `qos = 1`)
- ChirpStack -> Mosquitto para eventos de aplicacao (`chirpstack.toml`: `qos = 1`)

### 15.2 Sessao MQTT Persistente

Com `clean_session = false` em todos os clientes MQTT:
- Se o MQTT Forwarder ou ChirpStack desconectar momentaneamente do Mosquitto (ex: reinicio de servico), as mensagens publicadas durante a desconexao sao enfileiradas pelo Mosquitto
- Ao reconectar, as mensagens pendentes sao entregues retroativamente
- Subscricoes sao preservadas (nao precisam ser recriadas)

**Requisito**: QoS >= 1 para que o enfileiramento funcione. QoS 0 com clean_session=false nao enfileira.

### 15.3 Operacao 100% Offline

O sistema nao depende de internet para nenhuma funcionalidade LoRaWAN:
- Todos os servicos comunicam via `localhost`
- Boot nao espera por rede (`systemd-networkd-wait-online` mascarado)
- DNS local configurado como fallback
- ChirpStack depende apenas de `postgresql`, `redis` e `mosquitto` (nao de `network-online.target`)
- Packet forwarder depende apenas de `local-fs.target` (acesso USB)

O WiFi e necessario apenas para acesso remoto a Web UI e API REST.

### 15.4 Auto-Recovery do Concentrador

Tres niveis de protecao:

1. **ExecStartPre**: verifica que `/dev/ttyACM0` existe antes de iniciar
2. **Restart=always + RestartSec=5**: reinicia automaticamente em qualquer falha
3. **Watchdog externo** (`watchdog_concentrator.sh`, cron a cada 2 min): se nao houver `PULL_ACK` nos logs nos ultimos 90 segundos, forca reinicio do servico

### 15.5 Deteccao de Device Offline

Script `device_monitor.sh` (cron a cada 3 minutos):
- Consulta a API do ChirpStack para obter `lastSeenAt` de todos os devices
- Se um device nao reportou em mais de 180 segundos (3x o intervalo de 60s), registra `ALERT OFFLINE` no log
- Log centralizado em `/var/log/lorawan-health.log`

### 15.6 Confirmacao de Comandos Class C (Camada de Aplicacao)

O ACK LoRaWAN confirma apenas que o frame chegou ao device, **nao que o comando foi executado**. Para operacao critica, o protocolo de aplicacao deve implementar:

```
1. Servidor envia downlink com comando (ex: [0x01, 0xFF] = ligar atuador)
2. Device RAK3172 recebe, executa a acao
3. Device envia uplink de confirmacao com status (ex: [bateria, 0x01, 0xFF] = executado)
4. Se o servidor nao receber confirmacao em 2x ciclos de uplink (120s), reenvia o comando
```

O codec `encodeDownlink`/`decodeUplink` do profile RAK3172-ClassC-Actuator ja suporta este fluxo. A implementacao e no firmware do device.

---

## 16. Tuning de Performance do Sistema

### 16.1 Prioridade de CPU para Servicos LoRaWAN

Todos os servicos criticos rodam com `Nice=-5` e `CPUWeight` elevado via systemd. Em situacao de contencao de CPU, estes servicos recebem prioridade sobre processos normais (nice=0, CPUWeight=100).

| Servico | Nice | CPUWeight | IOWeight | Arquivo |
|---|---|---|---|---|
| chirpstack-mqtt-forwarder | -5 | 200 | 200 | `.service.d/priority.conf` |
| chirpstack | -5 | 200 | 200 | `.service.d/override.conf` |
| mosquitto | -5 | 150 | - | `.service.d/priority.conf` |
| lora-pkt-fwd | -5 | - | - | direto no `.service` |
| postgresql | - | - | 250 | `postgresql@.service.d/io-priority.conf` |

**Como funciona**: O `CPUWeight` e relativo. Com weight=200 e outros processos em weight=100, o servico recebe ~67% do CPU disputado (200/300). Com 4 servicos em weight=200, todos dividem igualmente entre si mas com prioridade sobre qualquer processo externo.

### 16.2 Buffers UDP do Kernel

Os buffers de recepcao/envio UDP foram aumentados de 208 KB (padrao) para 4 MB. Isso previne perda silenciosa de pacotes UDP quando o processo receptor (MQTT Forwarder) esta momentaneamente ocupado.

Arquivo: `/etc/sysctl.d/90-lorawan.conf`

```
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 4194304
net.core.wmem_max = 4194304
```

```bash
sudo sysctl --system
```

### 16.3 I/O Scheduler e Prioridade de Disco

O microSD usa o scheduler `mq-deadline` (persistido via udev) e o PostgreSQL tem prioridade maxima de I/O.

Arquivo: `/etc/udev/rules.d/60-scheduler.rules`
```
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"
```

Arquivo: `/etc/systemd/system/postgresql@.service.d/io-priority.conf`
```ini
[Service]
IOSchedulingClass=best-effort
IOSchedulingPriority=0
IOWeight=250
```

`IOSchedulingPriority=0` e a prioridade maxima (escala 0-7). `IOWeight=250` (default=100) garante que o PostgreSQL recebe 2.5x mais banda de I/O que processos normais em contencao.

---

## 17. Monitoramento, Watchdog e Backup

> **Nota:** Substitua os placeholders abaixo pelos valores da sua instalacao:
> `<USER>` = usuario do sistema, `<BACKUP_DIR>` = diretorio de backups (ex: `/home/seuusuario/backups`)

### 17.1 Health Check (cron a cada 5 minutos)

Script: `/home/<USER>/health_check.sh`

Verifica:
- Status dos 7 servicos systemd
- Uso de memoria (alerta > 80%)
- Uso de disco (alerta > 90%)
- Atividade do gateway (PULL_ACK nos ultimos 2 minutos)

Log: `/var/log/lorawan-health.log`

```bash
# Crontab do usuario marlon
*/5 * * * * /bin/bash /home/<USER>/health_check.sh
```

### 17.2 Watchdog do Concentrador (cron a cada 2 minutos)

Script: `/home/<USER>/watchdog_concentrator.sh`

Verifica se houve atividade (`PULL_ACK`) do concentrador nos ultimos 90 segundos. Se nao, reinicia o servico `lora-pkt-fwd` e registra no log.

```bash
# Crontab do root
*/2 * * * * /bin/bash /home/<USER>/watchdog_concentrator.sh
```

### 17.3 Monitor de Devices Offline (cron a cada 3 minutos)

Script: `/home/<USER>/device_monitor.sh`

Consulta a API REST do ChirpStack, verifica `lastSeenAt` de todos os devices registrados. Se um device nao reportou em mais de 180 segundos, registra `ALERT OFFLINE <nome> <dev_eui>` no log.

```bash
# Crontab do root
*/3 * * * * /bin/bash /home/<USER>/device_monitor.sh
```

### 17.4 Backup Diario (cron as 3h)

Script: `/home/<USER>/lorawan-backup.sh`
Template: `templates/backup/lorawan-backup.sh`

Conteudo do backup:
- `chirpstack_YYYYMMDD.dump` - Dump completo do PostgreSQL (`pg_dump -Fc`)
- `redis_YYYYMMDD.rdb` - Snapshot do Redis (BGSAVE + copy)
- `configs_YYYYMMDD.tar.gz` - Todos os arquivos de configuracao + crontabs

Diretorio local: `<BACKUP_DIR>`
Diretorio remoto: Google Drive via rclone (`gdrive:LoRaCore-backups/`)
Retencao: 30 dias (local e remoto)

O script executa em fases independentes — falha em uma fase nao aborta as demais. O sync remoto degrada graciosamente se o RPi estiver offline ou rclone nao estiver configurado.

```bash
# Crontab do root
0 3 * * * /bin/bash /home/<USER>/lorawan-backup.sh
```

Para setup completo (rclone, Google Drive, cron): ver `templates/backup/README.md`.

### 17.5 Resumo de Automacoes (cron)

| Script | Frequencia | Usuario | Funcao |
|---|---|---|---|
| `health_check.sh` | A cada 5 min | `<USER>` | Servicos, memoria, disco, gateway |
| `watchdog_concentrator.sh` | A cada 2 min | root | Auto-recovery do concentrador |
| `device_monitor.sh` | A cada 3 min | root | Alerta de devices offline |
| `lorawan-backup.sh` | Diario 3h | root | Backup PostgreSQL + Redis + configs + sync Google Drive |

### 17.6 Restauracao de Backup

Script guiado: `/home/<USER>/lorawan-restore.sh`
Template: `templates/backup/lorawan-restore.sh`

```bash
# Restaurar do backup local
sudo bash ~/lorawan-restore.sh --date YYYYMMDD

# Restaurar puxando do Google Drive
sudo bash ~/lorawan-restore.sh --date YYYYMMDD --from-remote

# Simular sem executar
sudo bash ~/lorawan-restore.sh --date YYYYMMDD --dry-run
```

O script e interativo — pede confirmacao antes de cada passo destrutivo (PostgreSQL, Redis, configs). Restauracao manual passo a passo:

```bash
# PostgreSQL
sudo -u postgres pg_restore -d chirpstack -c --if-exists <BACKUP_DIR>/chirpstack_YYYYMMDD.dump

# Redis
sudo systemctl stop redis-server
sudo cp <BACKUP_DIR>/redis_YYYYMMDD.rdb /var/lib/redis/dump.rdb
sudo chown redis:redis /var/lib/redis/dump.rdb
sudo systemctl start redis-server

# Configs
sudo tar xzf <BACKUP_DIR>/configs_YYYYMMDD.tar.gz -C /
sudo systemctl daemon-reload
sudo systemctl restart chirpstack chirpstack-mqtt-forwarder mosquitto redis-server lora-pkt-fwd
```

---

## 18. Servicos systemd e Portas de Rede

### 18.1 Servicos

| Servico | Descricao | Reinicio | Nice | CPUWeight | Depende de |
|---|---|---|---|---|---|
| `postgresql` | Banco de dados | automatico | 0 | 100 | - |
| `redis-server` | Cache e filas | automatico | 0 | 100 | - |
| `mosquitto` | Broker MQTT | automatico | -5 | 150 | - |
| `chirpstack` | Network Server LoRaWAN | automatico | -5 | 200 | postgresql, redis, mosquitto |
| `chirpstack-mqtt-forwarder` | Conversor UDP-MQTT (Rust, QoS 1) | automatico | -5 | 200 | mosquitto |
| `chirpstack-rest-api` | Proxy REST para API gRPC | automatico | 0 | 100 | chirpstack |
| `lora-pkt-fwd` | Comunicacao com RAK2287 | always, 5s, watchdog 120s | -5 | - | local-fs (USB) |

### 18.2 Mapa de Portas

| Porta | Protocolo | Servico | Acesso |
|---|---|---|---|
| 1700 | UDP | MQTT Forwarder | Interno (localhost) |
| 1883 | TCP | Mosquitto MQTT | Interno (localhost) |
| 5432 | TCP | PostgreSQL | Interno (localhost) |
| 6379 | TCP | Redis | Interno (localhost) |
| 8080 | TCP | ChirpStack Web/gRPC | Rede local |
| 8090 | TCP | ChirpStack REST API | Rede local |

### 18.3 Ordem de Inicializacao

```
1. postgresql                 (independente)
2. redis-server               (independente)
3. mosquitto                  (independente)
4. chirpstack                 (depende de postgresql, redis, mosquitto)
5. chirpstack-mqtt-forwarder  (depende de mosquitto)
6. chirpstack-rest-api        (depende de chirpstack)
7. lora-pkt-fwd               (depende apenas de USB/filesystem, NAO de rede)
```

Nenhum servico depende de `network-online.target`. O boot completa mesmo sem WiFi conectado.

---

## 19. Procedimento de Instalacao Passo a Passo

### Resumo ordenado para replicacao em um novo servidor:

```bash
# 1. Sistema base (Ubuntu 24.04 em Raspberry Pi 5)

# 2. Swap
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 3. Dependencias base
sudo apt update
sudo apt install -y postgresql redis-server mosquitto mosquitto-clients \
    git build-essential apt-transport-https

# 4. PostgreSQL
sudo -u postgres psql -c "CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';"
sudo -u postgres psql -c "CREATE DATABASE chirpstack WITH OWNER chirpstack;"
sudo -u postgres psql -d chirpstack -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
# Aplicar tuning em /etc/postgresql/16/main/postgresql.conf
sudo systemctl restart postgresql

# 5. Redis - aplicar tuning em /etc/redis/redis.conf
sudo systemctl restart redis-server

# 6. Mosquitto - criar /etc/mosquitto/conf.d/production.conf
sudo systemctl restart mosquitto

# 7. Repositorio ChirpStack
curl -fsSL https://artifacts.chirpstack.io/packages/chirpstack.key -o /tmp/chirpstack.key
sudo gpg --dearmor --yes -o /usr/share/keyrings/chirpstack-archive-keyring.gpg /tmp/chirpstack.key
echo "deb [signed-by=/usr/share/keyrings/chirpstack-archive-keyring.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | sudo tee /etc/apt/sources.list.d/chirpstack.list
sudo apt update
sudo apt install -y chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api

# 8. Configurar ChirpStack (chirpstack.toml, region_us915_0.toml)
# 9. Configurar MQTT Forwarder (chirpstack-mqtt-forwarder.toml - ver secao 5.2)
# 10. Gerar secret: openssl rand -base64 32

# 11. Iniciar servicos
sudo systemctl enable chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api
sudo systemctl start chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api

# 12. Compilar e instalar Packet Forwarder
git clone https://github.com/Lora-net/sx1302_hal.git
cd sx1302_hal && make all
mkdir -p ~/packet_forwarder
cp packet_forwarder/lora_pkt_fwd ~/packet_forwarder/
cp mcu_bin/* ~/packet_forwarder/
# Criar global_conf.json conforme secao 4.3

# 13. Criar servico systemd para packet forwarder (com watchdog - ver secao 4.4)

# 14. Operacao offline (ver secao 3.5)
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service
# Criar override chirpstack.service.d
# Criar /etc/systemd/resolved.conf.d/local.conf

# 15. Tuning de performance (ver secao 16)
#     - CPUWeight e Nice para servicos criticos
#     - Buffers UDP 4MB (/etc/sysctl.d/90-lorawan.conf)
#     - I/O scheduler mq-deadline (/etc/udev/rules.d/60-scheduler.rules)
#     - IOWeight para PostgreSQL

# 16. Registrar gateway no ChirpStack via Web UI ou API
# 17. Criar device profiles (ClassA e ClassC)
# 18. Configurar health check, watchdog, device monitor e backup (ver secao 17)
```

---

## 20. Registro de Dispositivos

### 20.1 Via API REST

**Criar dispositivo:**
```bash
curl -X POST http://<IP>:8090/api/devices \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "device": {
      "devEui": "<DEV_EUI_16_HEX>",
      "name": "<nome>",
      "applicationId": "<app_uuid>",
      "deviceProfileId": "<profile_uuid>",
      "isDisabled": false,
      "skipFcntCheck": false
    }
  }'
```

**Definir chaves OTAA:**
```bash
curl -X POST http://<IP>:8090/api/devices/<DEV_EUI>/keys \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceKeys": {
      "devEui": "<DEV_EUI>",
      "nwkKey": "<APP_KEY_32_HEX>",
      "appKey": "<APP_KEY_32_HEX>"
    }
  }'
```

### 20.2 Parametros OTAA para Firmware dos Devices

Cada device precisa ser programado com:

| Parametro | Formato | Origem |
|---|---|---|
| DevEUI | 8 bytes hex | Gerado (unico por device) |
| AppKey | 16 bytes hex | Gerado (unico por device) |
| JoinEUI (AppEUI) | 8 bytes hex | 0000000000000000 |
| Regiao | US915 | Fixo |
| Sub-band | 1 (canais 0-7) | Fixo |
| Channel Mask | 0x00FF,0x0000,0x0000,0x0000,0x0000,0x0000 | Sub-band 1 |

---

## 21. Resultados de Stress Test

Stress test realizado para validar a resiliencia da cadeia de comunicacao sob carga extrema.

### 21.1 Cenario de Teste

```bash
stress-ng --cpu 4 --vm 2 --vm-bytes 512M --io 2 --hdd 2 --timeout 300
```

10 workers saturando todos os recursos da RPi por 5 minutos, com a CubeCell transmitindo uplinks a cada 5 segundos simultaneamente.

### 21.2 Resultado Comparativo

O teste foi executado duas vezes: antes e depois das melhorias de resiliencia.

| Metrica | ANTES (Gateway Bridge Go) | DEPOIS (MQTT Forwarder Rust) |
|---|---|---|
| **Uplinks entregues ao ChirpStack** | **0 (0%)** | **45 (97.8%)** |
| **MQTT Forwarder/Bridge publicou** | 0 | 46 |
| **App MQTT recebeu** | 0 | 45 |
| **Servicos sobreviveram** | 7/7 (100%) | 7/7 (100%) |
| **Temperatura pico** | 71.0 C | 55.6 C |
| **Swap pico** | 523 MB | 52 MB |
| **CPU media** | 100% | 100% |
| **Load average pico** | 12.5 | 11.2 |

### 21.3 Analise

**Antes das melhorias**: O Gateway Bridge (Go, 14MB, 7 threads) nao conseguiu processar nenhum pacote UDP sob CPU 100%. O garbage collector do Go e a falta de prioridade de CPU fizeram o processo ser completamente impedido de executar. O Packet Forwarder (C) continuou recebendo pacotes RF, mas o PUSH_DATA nunca foi confirmado (acknowledged: 0.00%).

**Depois das melhorias**: O MQTT Forwarder (Rust, 3.7MB, sem GC) com Nice=-5 e CPUWeight=200, combinado com buffer UDP de 4MB, conseguiu processar 46 dos ~47 pacotes recebidos pelo concentrador. A temperatura caiu 15C (menos overhead de processamento). O swap caiu 90% (Rust usa ~3.7MB vs Go 15MB + GC overhead).

### 21.4 Conclusao

A cadeia de comunicacao e resiliente sob carga extrema. Em operacao normal com 50 devices (CPU < 10%), a taxa de entrega sera 100%. O cenario testado (CPU 100% + I/O saturado por 5 minutos) e uma condicao extrema que somente ocorreria com processos descontrolados no servidor.

---

## 22. Troubleshooting

### 22.1 Device nao faz Join

| Verificacao | Comando |
|---|---|
| Packet forwarder recebendo? | `journalctl -u lora-pkt-fwd -f` (procurar "rxpk") |
| MQTT Forwarder recebendo? | `journalctl -u chirpstack-mqtt-forwarder -f` (procurar "Sending uplink") |
| ChirpStack processando? | `journalctl -u chirpstack -f` (procurar "JoinRequest") |
| Frequencias coincidem? | Verificar sub-band do device vs concentrador |
| DevEUI/AppKey corretos? | Comparar firmware do device com ChirpStack |

### 22.2 Gateway offline no ChirpStack

| Verificacao | Comando |
|---|---|
| Packet forwarder rodando? | `systemctl is-active lora-pkt-fwd` |
| PULL_ACK recebido? | `journalctl -u lora-pkt-fwd \| grep PULL_ACK` |
| Gateway registrado? | Verificar Gateway ID no ChirpStack Web UI |
| Prefixo MQTT correto? | Comparar `topic_prefix` na region e no mqtt-forwarder |

### 22.3 Downlink nao chega ao device Class C

| Verificacao | Comando |
|---|---|
| Device fez uplink apos join? | Class C so recebe downlink apos primeiro uplink |
| Device profile e Class C? | Verificar `supportsClassC = true` no profile |
| Gateway consegue transmitir? | Verificar `tx_enable = true` no radio_0 |
| Frequencia TX dentro da faixa? | tx_freq_min/max deve cobrir 923-928 MHz |

### 22.4 Verificar QoS MQTT

```bash
# Confirmar QoS 1 nos tres componentes
sudo grep "qos" /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
sudo grep "qos" /etc/chirpstack/region_us915_0.toml
sudo grep "qos" /etc/chirpstack/chirpstack.toml

# Confirmar clean_session false
sudo grep "clean_session" /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
sudo grep "clean_session" /etc/chirpstack/region_us915_0.toml
sudo grep "clean_session" /etc/chirpstack/chirpstack.toml
```

### 22.5 Device offline nao detectado

| Verificacao | Comando |
|---|---|
| Monitor rodando? | `sudo crontab -l \| grep device_monitor` |
| API acessivel? | `curl -s http://localhost:8090/api/tenants` |
| Alertas no log? | `grep "ALERT OFFLINE" /var/log/lorawan-health.log` |
| Device registrado? | Verificar na Web UI se o device existe |

### 22.6 Logs Uteis

```bash
# Todos os logs em tempo real
journalctl -u lora-pkt-fwd -u chirpstack -u chirpstack-mqtt-forwarder -f

# Health check + alertas de devices offline + watchdog
cat /var/log/lorawan-health.log

# Somente alertas criticos
grep -E "FAIL|WARN|ALERT|WATCHDOG" /var/log/lorawan-health.log

# Mosquitto
cat /var/log/mosquitto/mosquitto.log
```

---

**Fim do documento**

Para duvidas sobre esta configuracao, consultar:
- ChirpStack docs: https://www.chirpstack.io/docs/
- Semtech sx1302_hal: https://github.com/Lora-net/sx1302_hal
- RAK2287 datasheet: https://docs.rakwireless.com/product-categories/wislink/rak2287/datasheet/
- LoRaWAN Regional Parameters US915: https://lora-alliance.org/resource_hub/rp002-1-0-4-regional-parameters/
