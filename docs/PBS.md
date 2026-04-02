# PBS — LoRaCore

> Ultima atualizacao: 2026-04-02

## Visao Geral

Kit de infraestrutura LoRaWAN generico para IoT industrial. Documentacao canonica, templates de configuracao validados e codecs prontos para deploy sobre RPi5 + RAK2287 + ChirpStack v4.

## Escala de Maturidade

| Nivel | Estado | Definicao |
|---|---|---|
| 0 | `pendente` | Componente identificado, sem codigo |
| 1 | `esqueleto` | Interface/header existe, implementacao stub ou parcial |
| 2 | `implementado` | Codigo funcional, sem validacao formal |
| 3 | `validado` | Testado (unit/bench/integracao) com evidencia |
| 4 | `producao` | Em uso real, estavel, sem issues conhecidos |

Estado so avanca com evidencia (commit, teste, log de bancada). Nunca por estimativa.

## Componentes

### 1. Documentacao Canonica
- **Responsabilidade:** Referencia tecnica completa do sistema LoRaWAN (protocolo, integracao, operacao, FAQ, glossario)
- **Arquivos:** `docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md`, `docs/QUICK_START.md`, `docs/GUIA_CONSUMIDOR.md`, `docs/REFERENCIA_INTEGRACAO.md`, `docs/FAQ.md`, `docs/GLOSSARIO.md`, `docs/RELATORIO_STRESS_TEST.md`, `docs/RELATORIO_STRESS_TEST_V2.md`, `docs/RELATORIO_STRESS_TEST_V3.md`, `docs/LORACORE_AI_INTEGRATION_GUIDE.md`
- **Depende de:** —
- **Estado:** `producao`
- **Evidencia:** 3 stress tests executados em RPi5 (commits v0.1.0–v0.2.0), feedback de uso real
- **Notas:** —

### 2. Templates de Configuracao
- **Responsabilidade:** Configuracoes parametrizadas para todos os servicos do stack (packet forwarder, ChirpStack, MQTT forwarder, Mosquitto, systemd, sysctl, udev)
- **Arquivos:** `templates/packet-forwarder/global_conf.json`, `templates/chirpstack/{chirpstack.toml,chirpstack-sqlite.toml,region_us915_0.toml}`, `templates/mqtt-forwarder/chirpstack-mqtt-forwarder.toml`, `templates/mosquitto/{production.conf,password_auth.conf}`, `templates/systemd/*.service`, `templates/systemd/*.conf`, `templates/sysctl/90-lorawan.conf`, `templates/udev/60-scheduler.rules`
- **Depende de:** Hardware (RPi5 + RAK2287)
- **Estado:** `producao`
- **Evidencia:** CI valida JSON/TOML (`validate-core.yml`), deploy real em RPi5, stress tests V1-V3
- **Notas:** Todos parametrizados com placeholders — sem hardcodes (CI verifica)

### 3. Device Profiles
- **Responsabilidade:** Perfis de dispositivo ChirpStack v4 para Class A (sensor OTAA) e Class C (actuator OTAA)
- **Arquivos:** `templates/chirpstack/device-profiles/class-a-sensor-otaa.json`, `templates/chirpstack/device-profiles/class-c-actuator-otaa.json`
- **Depende de:** ChirpStack v4 API
- **Estado:** `producao`
- **Evidencia:** Devices registrados e operando via API REST, CI valida JSON
- **Notas:** —

### 4. Codecs ChirpStack
- **Responsabilidade:** Funcoes JavaScript de decode/encode para ChirpStack v4 (producao + exemplos + template)
- **Arquivos:** `templates/codecs/cubecell-class-a-sensor.js`, `templates/codecs/cubecell-stress-test-device2.js`, `templates/codecs/rak3172-class-c-actuator.js`, `templates/codecs/example-thermal-sensor.js`, `templates/codecs/example-actuator-bidirectional.js`, `templates/codecs/CODEC_TEMPLATE.js`
- **Depende de:** ChirpStack v4 codec runtime
- **Estado:** `producao`
- **Evidencia:** 5 test files automatizados (`templates/codecs/tests/test-*.js`), CI roda em cada PR (`validate-core.yml`)
- **Notas:** Formato `decodeUplink(input)` — invariante do projeto

### 5. Monitoramento e Observabilidade
- **Responsabilidade:** Health check, auto-recovery, watchdog de concentrador, monitor de devices, report diario, limpeza de disco, manutencao de banco, recovery de rede
- **Arquivos:** `templates/monitoring/{health_check.sh,auto_recovery.sh,watchdog_concentrator.sh,device_monitor.sh,daily_report.sh,disk_cleanup.sh,db_maintenance.sh,network_recovery.sh,logrotate-lorawan.conf}`
- **Depende de:** systemd, cron, ChirpStack REST API
- **Estado:** `producao`
- **Evidencia:** Logs em `/var/log/lorawan-*.log`, 4 camadas de resiliencia ativas (systemd → auto_recovery → hw watchdog → preventivo), commit `066663b`
- **Notas:** Zero dependencias externas (ADR-0004)

### 6. Backup e Disaster Recovery
- **Responsabilidade:** Backup diario (PostgreSQL + Redis + configs) para Google Drive via rclone, restore interativo com --dry-run
- **Arquivos:** `templates/backup/lorawan-backup.sh`, `templates/backup/lorawan-restore.sh`
- **Depende de:** rclone, PostgreSQL, Redis
- **Estado:** `producao`
- **Evidencia:** Cron ativo no RPi5, artefatos verificados (dump + rdb + tar.gz), retencao 30 dias
- **Notas:** —

### 7. Alerting
- **Responsabilidade:** Despacho e entrega de alertas externos via ntfy.sh/webhook com spool offline
- **Arquivos:** `templates/alerting/alert_dispatch.sh`, `templates/alerting/alert_flush.sh`
- **Depende de:** ntfy.sh (via SSH tunnel), spool local
- **Estado:** `producao`
- **Evidencia:** ntfy configurado e assinado (TASK-2026-0000 concluida), ADR-0006
- **Notas:** —

### 8. Acesso Remoto
- **Responsabilidade:** Tunnel SSH reverso via autossh para acesso ao RPi5 sem IP publico
- **Arquivos:** `templates/remote-access/loracore-tunnel.service`, `templates/remote-access/setup-tunnel.sh`
- **Depende de:** Relay server externo, autossh
- **Estado:** `validado`
- **Evidencia:** Script e service testados localmente, ADR-0007
- **Notas:** TASK-2026-0001 cancelada

### 9. Deploy Automatizado
- **Responsabilidade:** Script interativo de 15 fases para deploy completo do stack no RPi5
- **Arquivos:** `templates/deploy/setup-loracore.sh`
- **Depende de:** Todos os templates de configuracao
- **Estado:** `producao`
- **Evidencia:** Deploy executado com sucesso no RPi5 (TASK-2026-0010), opcoes `--non-interactive`, `--dry-run`
- **Notas:** —

### 10. Firmware de Exemplo
- **Responsabilidade:** Firmware de validacao OTAA para CubeCell HTCC-AB01 (join + uplink)
- **Arquivos:** `examples/firmware/cubecell-otaa-test/`
- **Depende de:** PlatformIO, hardware CubeCell
- **Estado:** `validado`
- **Evidencia:** CI compila via `firmware-build.yml`, testado em bancada
- **Notas:** Exemplo de consumo — nao e componente core

### 11. CI/CD
- **Responsabilidade:** Validacao automatica de codecs, templates e firmware em cada PR
- **Arquivos:** `.github/workflows/validate-core.yml`, `.github/workflows/firmware-build.yml`
- **Depende de:** GitHub Actions, Node.js, PlatformIO
- **Estado:** `producao`
- **Evidencia:** Workflows ativos, PRs validados automaticamente
- **Notas:** 5 jobs: lint-codecs, test-codecs, validate-templates, no-hardcodes, firmware-build

### 12. Runbooks Operacionais
- **Responsabilidade:** Procedimentos de resposta a incidentes (servico caido, SD falhou, gateway mudo, backup falhou, device offline, alerting falhou, tunnel caiu)
- **Arquivos:** `docs/runbooks/RUNBOOK-001.md` a `RUNBOOK-007.md`
- **Depende de:** —
- **Estado:** `producao`
- **Evidencia:** Documentados e referenciados pelo auto_recovery.sh, commit `062ebad`
- **Notas:** —

## Integracao

| De → Para | Interface | Estado |
|---|---|---|
| Device (LoRa) → Packet Forwarder | LoRaWAN RF (US915 SB1, OTAA) | `producao` |
| Packet Forwarder → ChirpStack | UDP localhost | `producao` |
| ChirpStack → MQTT Forwarder | Internal (Rust bridge) | `producao` |
| MQTT Forwarder → Mosquitto | MQTT :1883 | `producao` |
| Mosquitto → Apps consumidoras | MQTT subscribe (topics `application/+/device/+/event/+`) | `producao` |
| ChirpStack → PostgreSQL | TCP :5432 | `producao` |
| ChirpStack → Redis | TCP :6379 | `producao` |
| Monitoring → ChirpStack | REST API :8090 | `producao` |
| Alerting → ntfy.sh | HTTPS via SSH tunnel | `producao` |
| Backup → Google Drive | rclone (cron diario) | `producao` |
| Tunnel → Relay Server | SSH reverso (autossh) | `validado` |

## Resumo

| Componente | Estado | Bloqueios |
|---|---|---|
| Documentacao Canonica | `producao` | — |
| Templates de Configuracao | `producao` | — |
| Device Profiles | `producao` | — |
| Codecs ChirpStack | `producao` | — |
| Monitoramento e Observabilidade | `producao` | — |
| Backup e Disaster Recovery | `producao` | — |
| Alerting | `producao` | — |
| Acesso Remoto | `validado` | — |
| Deploy Automatizado | `producao` | — |
| Firmware de Exemplo | `validado` | Nao e core — validacao apenas |
| CI/CD | `producao` | — |
| Runbooks Operacionais | `producao` | — |
