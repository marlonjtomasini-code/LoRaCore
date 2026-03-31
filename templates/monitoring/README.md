# Templates de Monitoramento

Scripts de monitoramento, auto-recuperacao e observabilidade leve para a infraestrutura LoRaWAN. Bash puro, zero dependencias externas.

## Scripts

| Script | Funcao | Frequencia | Usuario |
|--------|--------|------------|---------|
| `health_check.sh` | Status dos servicos, memoria, disco, PULL_ACK, temperatura, load | A cada 5 min | `<USER>` |
| `watchdog_concentrator.sh` | Auto-recovery do concentrador (PULL_ACK timeout) | A cada 2 min | root |
| `device_monitor.sh` | Alerta de devices offline via ChirpStack REST API | A cada 3 min | `<USER>` |
| `daily_report.sh` | Dashboard textual diario (servicos, devices, backup, recursos) | Diario 7h | `<USER>` |
| `auto_recovery.sh` | Orquestrador de recuperacao de todos os servicos com circuit breaker | A cada 2 min | root |
| `disk_cleanup.sh` | Limpeza automatica de disco em 3 tiers escalantes | A cada 30 min | root |
| `db_maintenance.sh` | VACUUM/REINDEX PostgreSQL, verificacao Redis, monitor swap | Semanal dom 4h | root |
| `network_recovery.sh` | Recuperacao automatica de conectividade de rede | A cada 5 min | root |

## Placeholders

Substitua os placeholders abaixo pelos valores da sua instalacao antes do deploy:

| Placeholder | Descricao | Exemplo | Usado em |
|-------------|-----------|---------|----------|
| `<USER>` | Usuario do sistema | `seuusuario` | todos |
| `<MEM_THRESH>` | Percentual de memoria para alerta | `80` | health_check |
| `<DISK_THRESH>` | Percentual de disco para alerta | `90` | health_check |
| `<PULL_ACK_TIMEOUT>` | Segundos sem PULL_ACK para reiniciar | `90` | watchdog |
| `<CHIRPSTACK_HOST>` | Host do ChirpStack REST API | `localhost` | device_monitor, daily_report |
| `<CHIRPSTACK_PORT>` | Porta do ChirpStack REST API | `8090` | device_monitor, daily_report |
| `<CHIRPSTACK_TOKEN>` | API key do ChirpStack | (gerar via Web UI) | device_monitor, daily_report |
| `<OFFLINE_THRESHOLD>` | Segundos sem report para offline | `180` | device_monitor |
| `<APPLICATION_ID>` | UUID da application no ChirpStack | (obter via Web UI ou API) | device_monitor, daily_report |
| `<BACKUP_DIR>` | Diretorio de backups | `/home/seuusuario/backups` | daily_report, disk_cleanup |
| `<RETENTION_DAYS>` | Dias de retencao de backups | `30` | disk_cleanup |
| `<PG_DATABASE>` | Nome do banco PostgreSQL | `chirpstack` | db_maintenance |

## Deploy

1. Copie os scripts para o diretorio home do usuario:
   ```bash
   cp health_check.sh watchdog_concentrator.sh device_monitor.sh daily_report.sh \
      auto_recovery.sh disk_cleanup.sh db_maintenance.sh network_recovery.sh ~/
   chmod +x ~/*.sh
   ```

2. Substitua os placeholders:
   ```bash
   sed -i 's/<USER>/seuusuario/g; s/<MEM_THRESH>/80/g; s/<DISK_THRESH>/90/g' ~/health_check.sh
   sed -i 's/<USER>/seuusuario/g; s/<PULL_ACK_TIMEOUT>/90/g' ~/watchdog_concentrator.sh
   sed -i 's/<USER>/seuusuario/g; s/<CHIRPSTACK_HOST>/localhost/g; s/<CHIRPSTACK_PORT>/8090/g; s/<CHIRPSTACK_TOKEN>/SEU_TOKEN/g; s/<OFFLINE_THRESHOLD>/180/g; s/<APPLICATION_ID>/SEU_APP_ID/g' ~/device_monitor.sh
   sed -i 's/<USER>/seuusuario/g; s/<CHIRPSTACK_HOST>/localhost/g; s/<CHIRPSTACK_PORT>/8090/g; s/<CHIRPSTACK_TOKEN>/SEU_TOKEN/g; s|<BACKUP_DIR>|/home/seuusuario/backups|g; s/<APPLICATION_ID>/SEU_APP_ID/g' ~/daily_report.sh
   sed -i 's/<USER>/seuusuario/g' ~/auto_recovery.sh
   sed -i 's/<USER>/seuusuario/g; s|<BACKUP_DIR>|/home/seuusuario/backups|g; s/<RETENTION_DAYS>/30/g' ~/disk_cleanup.sh
   sed -i 's/<USER>/seuusuario/g; s/<PG_DATABASE>/chirpstack/g' ~/db_maintenance.sh
   sed -i 's/<USER>/seuusuario/g' ~/network_recovery.sh
   ```

3. Configure o crontab do usuario:
   ```bash
   crontab -e
   ```
   ```cron
   */5 * * * * /bin/bash /home/seuusuario/health_check.sh
   */3 * * * * /bin/bash /home/seuusuario/device_monitor.sh
   0 7 * * *   /bin/bash /home/seuusuario/daily_report.sh
   ```

4. Configure o crontab do root (scripts que precisam de permissao de restart):
   ```bash
   sudo crontab -e
   ```
   ```cron
   */2 * * * *   /bin/bash /home/seuusuario/auto_recovery.sh
   */2 * * * *   /bin/bash /home/seuusuario/watchdog_concentrator.sh
   */5 * * * *   /bin/bash /home/seuusuario/network_recovery.sh
   */30 * * * *  /bin/bash /home/seuusuario/disk_cleanup.sh
   0 4 * * 0     /bin/bash /home/seuusuario/db_maintenance.sh
   ```

5. Instale o logrotate:
   ```bash
   sudo cp logrotate-lorawan.conf /etc/logrotate.d/lorawan
   ```

## Logs

Todos os scripts gravam em arquivos de log padrao:

| Log | Origem |
|-----|--------|
| `/var/log/lorawan-health.log` | health_check, watchdog_concentrator |
| `/var/log/lorawan-backup.log` | lorawan-backup.sh |
| `/var/log/lorawan-daily-report.log` | daily_report |
| `/var/log/lorawan-recovery.log` | auto_recovery, disk_cleanup, db_maintenance, network_recovery, alert_dispatch |

Formato de log: `[YYYY-MM-DD HH:MM:SS] [TAG] mensagem`.

## Logrotate

A configuracao `logrotate-lorawan.conf` aplica:
- Rotacao semanal
- Retencao de 12 semanas (3 meses)
- Compressao gzip (com delay de 1 semana)
- Tolerante a logs inexistentes

## Camadas de Recuperacao

```
Camada 0: systemd Restart=on-failure (imediato, por servico)
Camada 1: auto_recovery.sh (2 min, orquestrado com dependencias)
Camada 2: Hardware watchdog (30s, reboot forcado se kernel travar)
Camada 3: disk_cleanup + db_maintenance + network_recovery (preventivo)
Camada 4: Alertas externos via ntfy.sh (ver templates/alerting/)
```

## Degradacao Graceful

Todos os scripts degradam graciosamente:
- Se um servico nao esta instalado (`is-enabled` falha), e ignorado
- Se `vcgencmd` nao existe, tenta `/sys/class/thermal/`
- Se `curl` nao existe, pula consultas a API
- Se a API do ChirpStack esta indisponivel, registra erro e sai
- Se `alert_dispatch.sh` nao existe, alertas externos viram no-op
- Circuit breaker usa `/run/lorawan/` (tmpfs, zero escrita no SD)
