# Templates de Monitoramento

Scripts de monitoramento e observabilidade leve para a infraestrutura LoRaWAN. Bash puro, zero dependencias externas.

## Scripts

| Script | Funcao | Frequencia | Usuario |
|--------|--------|------------|---------|
| `health_check.sh` | Status dos servicos, memoria, disco, PULL_ACK, temperatura, load | A cada 5 min | `<USER>` |
| `watchdog_concentrator.sh` | Auto-recovery do concentrador (PULL_ACK timeout) | A cada 2 min | root |
| `device_monitor.sh` | Alerta de devices offline via ChirpStack REST API | A cada 3 min | `<USER>` |
| `daily_report.sh` | Dashboard textual diario (servicos, devices, backup, recursos) | Diario 7h | `<USER>` |

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
| `<BACKUP_DIR>` | Diretorio de backups | `/home/seuusuario/backups` | daily_report |

## Deploy

1. Copie os scripts para o diretorio home do usuario:
   ```bash
   cp health_check.sh watchdog_concentrator.sh device_monitor.sh daily_report.sh ~/
   chmod +x ~/health_check.sh ~/watchdog_concentrator.sh ~/device_monitor.sh ~/daily_report.sh
   ```

2. Substitua os placeholders:
   ```bash
   sed -i 's/<USER>/seuusuario/g; s/<MEM_THRESH>/80/g; s/<DISK_THRESH>/90/g' ~/health_check.sh
   sed -i 's/<USER>/seuusuario/g; s/<PULL_ACK_TIMEOUT>/90/g' ~/watchdog_concentrator.sh
   sed -i 's/<USER>/seuusuario/g; s/<CHIRPSTACK_HOST>/localhost/g; s/<CHIRPSTACK_PORT>/8090/g; s/<CHIRPSTACK_TOKEN>/SEU_TOKEN/g; s/<OFFLINE_THRESHOLD>/180/g' ~/device_monitor.sh
   sed -i 's/<USER>/seuusuario/g; s/<CHIRPSTACK_HOST>/localhost/g; s/<CHIRPSTACK_PORT>/8090/g; s/<CHIRPSTACK_TOKEN>/SEU_TOKEN/g; s|<BACKUP_DIR>|/home/seuusuario/backups|g' ~/daily_report.sh
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

4. Configure o crontab do root (para watchdog com permissao de restart):
   ```bash
   sudo crontab -e
   ```
   ```cron
   */2 * * * * /bin/bash /home/seuusuario/watchdog_concentrator.sh
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

Formato de log: `[YYYY-MM-DD HH:MM:SS] mensagem` (identico ao script de backup).

## Logrotate

A configuracao `logrotate-lorawan.conf` aplica:
- Rotacao semanal
- Retencao de 12 semanas (3 meses)
- Compressao gzip (com delay de 1 semana)
- Tolerante a logs inexistentes

## Degradacao Graceful

Todos os scripts degradam graciosamente:
- Se um servico nao esta instalado (`is-enabled` falha), e ignorado
- Se `vcgencmd` nao existe, tenta `/sys/class/thermal/`
- Se `curl` nao existe, pula consultas a API
- Se a API do ChirpStack esta indisponivel, registra erro e sai
