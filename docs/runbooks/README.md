# Runbooks Operacionais

Procedimentos passo-a-passo para incidentes de producao da infraestrutura LoRaWAN. Projetados para serem seguidos durante um incidente — leia sequencialmente, execute cada passo, avance.

## Quando usar

Cada runbook e acionado por um **trigger** — o sinal que indica que o incidente esta acontecendo. Os triggers vem dos scripts de monitoramento (`health_check.sh`, `watchdog_concentrator.sh`, `device_monitor.sh`) ou da observacao direta.

## Indice

| Runbook | Trigger | Tempo estimado |
|---------|---------|----------------|
| [RUNBOOK-001](RUNBOOK-001-service-failure.md) | Servico systemd inativo | 5-10 min |
| [RUNBOOK-002](RUNBOOK-002-sd-card-failure.md) | Erros de I/O em `dmesg`, filesystem read-only | 30-60 min |
| [RUNBOOK-003](RUNBOOK-003-gateway-not-receiving.md) | Zero PULL_ACK, nenhum uplink recebido | 10-15 min |
| [RUNBOOK-004](RUNBOOK-004-backup-failure.md) | Erro no log de backup, backup ausente | 5-10 min |
| [RUNBOOK-005](RUNBOOK-005-device-offline.md) | ALERT OFFLINE no log, device sem report | 10-15 min |
| [RUNBOOK-006](RUNBOOK-006-alerting-failure.md) | Alertas nao chegam, spool acumulando | 5-10 min |
| [RUNBOOK-007](RUNBOOK-007-tunnel-down.md) | Tunnel SSH reverso inativo | 5-15 min |
| [RUNBOOK-008](RUNBOOK-008-new-device-registration.md) | Cadastro de novo dispositivo | 15-30 min |

## Estrutura de cada runbook

1. **Deteccao** — como voce percebe que o incidente esta acontecendo
2. **Triagem** — diagnostico rapido para identificar a causa
3. **Recovery** — passos para restaurar a operacao
4. **Pos-incidente** — verificacao e acoes preventivas

## Convencoes

- Comandos precedidos de `$` executam como usuario normal
- Comandos precedidos de `#` executam como root (`sudo`)
- Placeholders `<...>` devem ser substituidos pelos valores da sua instalacao
- Todos os comandos assumem SSH conectado ao RPi5

## Ordem de restart dos servicos

Quando precisar reiniciar a stack completa, siga esta ordem (respeita dependencias):

```bash
# 1. Banco de dados (base de tudo)
sudo systemctl restart postgresql

# 2. Cache
sudo systemctl restart redis-server

# 3. Broker MQTT
sudo systemctl restart mosquitto

# 4. Network server
sudo systemctl restart chirpstack

# 5. REST API proxy
sudo systemctl restart chirpstack-rest-api

# 6. MQTT forwarder
sudo systemctl restart chirpstack-mqtt-forwarder

# 7. Packet forwarder (gateway)
sudo systemctl restart lora-pkt-fwd
```

## Logs relevantes

| Log | Conteudo |
|-----|----------|
| `/var/log/lorawan-health.log` | Health check, watchdog, device monitor |
| `/var/log/lorawan-backup.log` | Backup diario |
| `/var/log/lorawan-daily-report.log` | Relatorio diario |
| `/var/log/lorawan-recovery.log` | Auto-recovery, disk cleanup, DB maintenance, rede, alertas |
| `journalctl -u <servico>` | Logs de cada servico systemd |
| `journalctl -u loracore-tunnel` | Tunnel de acesso remoto |
| `/var/log/mosquitto/mosquitto.log` | Broker MQTT |
