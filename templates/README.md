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
| `<USER>` | Usuario do sistema | `seuusuario` |
| `<PKT_FWD_PATH>` | Path do packet forwarder | `/home/seuusuario/packet_forwarder` |

## Indice de Templates

| Diretorio | Arquivo | Componente |
|-----------|---------|------------|
| `packet-forwarder/` | `global_conf.json` | SX1302 concentrador USB — US915 sub-band 1 |
| `mqtt-forwarder/` | `chirpstack-mqtt-forwarder.toml` | MQTT Forwarder (Rust) — UDP para MQTT |
| `chirpstack/` | `chirpstack.toml` | ChirpStack v4 — network server (PostgreSQL) |
| `chirpstack/` | `chirpstack-sqlite.toml` | ChirpStack v4 — variante SQLite para deploy leve |
| `chirpstack/` | `region_us915_0.toml` | Configuracao de regiao US915 + MQTT gateway |
| `chirpstack/device-profiles/` | `class-a-sensor-otaa.json` | Device profile — sensor Class A OTAA |
| `chirpstack/device-profiles/` | `class-c-actuator-otaa.json` | Device profile — atuador Class C OTAA |
| `mosquitto/` | `production.conf` | Mosquitto — broker MQTT de producao (allow_anonymous) |
| `mosquitto/` | `password_auth.conf` | Mosquitto — autenticacao por senha (redes nao-isoladas) |
| `systemd/` | `lora-pkt-fwd.service` | Unit file do packet forwarder |
| `systemd/` | `chirpstack-mqtt-fwd-priority.conf` | Override de prioridade CPU para MQTT forwarder |
| `systemd/` | `chirpstack-priority.conf` | Override de prioridade CPU para ChirpStack |
| `systemd/` | `mosquitto-priority.conf` | Override de prioridade CPU para Mosquitto |
| `systemd/` | `postgresql-io-priority.conf` | Override de prioridade I/O para PostgreSQL |
| `sysctl/` | `90-lorawan.conf` | Tuning de buffers UDP (4 MB) |
| `udev/` | `60-scheduler.rules` | I/O scheduler mq-deadline para microSD |
| `codecs/` | `cubecell-class-a-sensor.js` | Decoder ChirpStack — CubeCell Class A |
| `codecs/` | `cubecell-stress-test-device2.js` | Decoder ChirpStack — CubeCell Stress Test Device 2 (14B) |
| `codecs/` | `rak3172-class-c-actuator.js` | Decoder + Encoder ChirpStack — RAK3172 Class C |
| `codecs/` | `CODEC_TEMPLATE.js` | Esqueleto para novos codecs (3 funcoes) |
| `codecs/` | `example-thermal-sensor.js` | Exemplo — sensor termico industrial (decode only) |
| `codecs/` | `example-actuator-bidirectional.js` | Exemplo — atuador bidirecional (decode + encode) |
| `codecs/` | `README.md` | Guia de desenvolvimento de codecs |
| `backup/` | `lorawan-backup.sh` | Backup diario: PostgreSQL + Redis + configs → Google Drive |
| `backup/` | `lorawan-restore.sh` | Restauracao guiada (interativa, com --dry-run) |
| `backup/` | `README.md` | Guia de setup: rclone, auth headless, cron, troubleshooting |
| `monitoring/` | `health_check.sh` | Health check: servicos, memoria, disco, PULL_ACK, temperatura |
| `monitoring/` | `watchdog_concentrator.sh` | Watchdog: auto-recovery do concentrador (PULL_ACK timeout) |
| `monitoring/` | `device_monitor.sh` | Monitor de devices offline via ChirpStack REST API |
| `monitoring/` | `daily_report.sh` | Relatorio diario: dashboard textual de toda a infraestrutura |
| `monitoring/` | `logrotate-lorawan.conf` | Logrotate semanal (12 semanas retencao, compressao) |
| `monitoring/` | `README.md` | Guia de deploy: placeholders, cron, logrotate |
| `deploy/` | `setup-loracore.sh` | Script interativo de deploy completo (13 fases) |
| `deploy/` | `README.md` | Prerequisitos, opcoes, disaster recovery |

## PostgreSQL vs SQLite

O ChirpStack v4 suporta dois backends de banco de dados. Escolha conforme seu cenario:

| Criterio | PostgreSQL (`chirpstack.toml`) | SQLite (`chirpstack-sqlite.toml`) |
|----------|-------------------------------|-----------------------------------|
| Devices | Muitos (100+) | Poucos (< 100) |
| Concorrencia | Multi-processo | Single-writer |
| Setup | Requer PostgreSQL instalado | Arquivo unico, zero config |
| Caso de uso | Producao, infraestrutura existente | Edge, dev/teste, setup simplificado |
| Backup | `pg_dump` | Copiar arquivo `.sqlite` |

**Nota:** Redis continua obrigatorio em ambos os casos.
