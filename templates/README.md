# Templates de Configuracao

Configuracoes reutilizaveis e validadas para deploy da infraestrutura LoRaWAN. Extraidas da documentacao canonica ([DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](../docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md)).

## Como Usar

1. Copie os arquivos de template para seu ambiente de deploy
2. Substitua os **placeholders** (marcados com `<...>`) pelos valores da sua instalacao
3. Consulte a documentacao canonica para entender cada parametro

## Placeholders Comuns

| Placeholder | Descricao | Exemplo |
|-------------|-----------|---------|
| `<GATEWAY_ID>` | EUI do gateway (16 hex) | `2CCF67FFFE576A1D` |
| `<SECRET>` | Chave secreta da API | Gerar com `openssl rand -base64 32` |
| `<USER>` | Usuario do sistema | `marlon` |
| `<PKT_FWD_PATH>` | Path do packet forwarder | `/home/marlon/packet_forwarder` |

## Indice de Templates

| Diretorio | Arquivo | Componente |
|-----------|---------|------------|
| `packet-forwarder/` | `global_conf.json` | SX1302 concentrador USB — US915 sub-band 1 |
| `mqtt-forwarder/` | `chirpstack-mqtt-forwarder.toml` | MQTT Forwarder (Rust) — UDP para MQTT |
| `chirpstack/` | `chirpstack.toml` | ChirpStack v4 — network server |
| `chirpstack/` | `region_us915_0.toml` | Configuracao de regiao US915 + MQTT gateway |
| `mosquitto/` | `production.conf` | Mosquitto — broker MQTT de producao |
| `systemd/` | `lora-pkt-fwd.service` | Unit file do packet forwarder |
| `systemd/` | `chirpstack-mqtt-fwd-priority.conf` | Override de prioridade CPU para MQTT forwarder |
| `systemd/` | `postgresql-io-priority.conf` | Override de prioridade I/O para PostgreSQL |
| `sysctl/` | `90-lorawan.conf` | Tuning de buffers UDP (4 MB) |
| `udev/` | `60-scheduler.rules` | I/O scheduler mq-deadline para microSD |
| `codecs/` | `cubecell-class-a-sensor.js` | Decoder ChirpStack — CubeCell Class A |
| `codecs/` | `rak3172-class-c-actuator.js` | Decoder + Encoder ChirpStack — RAK3172 Class C |
