# RUNBOOK-006: Falha no Sistema de Alertas

**Trigger:** Operador nao recebe notificacoes esperadas (push ntfy.sh) ou `alert_flush.sh` reporta falhas no log.

**Tempo estimado:** 5-10 minutos

---

## 1. Deteccao

Sinais de que o sistema de alertas nao esta funcionando:

```bash
# Verificar se ha alertas acumulados no spool
$ ls -la /var/spool/lorawan-alerts/
$ find /var/spool/lorawan-alerts/ -type f | wc -l

# Verificar log de flush
$ grep "ALERT_FLUSH" /var/log/lorawan-recovery.log | tail -10

# Verificar se flush esta no cron
$ crontab -l | grep alert_flush
```

---

## 2. Triagem

### 2.1. Alertas nao estao sendo gerados

```bash
# Verificar se alert_dispatch.sh existe e esta configurado
$ cat ~/alert_dispatch.sh | grep NTFY_TOPIC
# Se contem <NTFY_TOPIC>, placeholders nao foram substituidos

# Verificar se scripts de monitoramento estao carregando o dispatch
$ grep "alert_dispatch" ~/health_check.sh
```

### 2.2. Alertas estao no spool mas nao sao entregues

```bash
# Verificar conectividade
$ curl -s --max-time 5 https://ntfy.sh && echo "OK" || echo "OFFLINE"

# Verificar configuracao do flush
$ grep NTFY_TOPIC ~/alert_flush.sh

# Executar flush manualmente
$ bash ~/alert_flush.sh
```

### 2.3. ntfy.sh rejeita os alertas

```bash
# Testar envio manual
$ curl -d "Teste de alerta LoRaCore" https://ntfy.sh/SEU_TOPICO
# Se retornar erro, verificar token e topico
```

---

## 3. Recovery

### Placeholders nao substituidos

```bash
$ sed -i 's|<NTFY_TOPIC>|https://ntfy.sh/seu-topico|g; s|<ALERT_HOST_NAME>|seu-gateway|g; s|<ALERT_RATE_LIMIT>|10|g; s|<ALERT_DEDUP_MINUTES>|30|g; s|<NTFY_TOKEN>||g; s|<ALERT_WEBHOOK_URL>||g' ~/alert_dispatch.sh ~/alert_flush.sh
```

### Token expirado ou topico protegido

```bash
# Gerar novo token em https://ntfy.sh/account
$ sed -i 's|<NTFY_TOKEN>|tk_novo_token|g' ~/alert_dispatch.sh ~/alert_flush.sh
```

### Spool lotado

```bash
# Limpar alertas antigos (>48h)
$ find /var/spool/lorawan-alerts/ -type f -mmin +2880 -delete

# Forcar flush
$ bash ~/alert_flush.sh
```

### Flush nao esta no cron

```bash
$ crontab -e
# Adicionar:
# */5 * * * * /bin/bash /home/<USER>/alert_flush.sh
```

---

## 4. Pos-incidente

```bash
# Verificar que alertas estao sendo entregues
$ echo "$(date +%s)" > /var/spool/lorawan-alerts/test_alert
$ cat > /var/spool/lorawan-alerts/test_alert <<EOF
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
SEVERITY=INFO
SOURCE=test
HOST=$(hostname)
MESSAGE=Teste de alerta pos-incidente
HASH=test123
EOF
$ bash ~/alert_flush.sh
# Verificar se recebeu a notificacao no celular
$ rm -f /var/spool/lorawan-alerts/test_alert
```
