# RUNBOOK-004: Falha no Backup Diario

**Trigger:** Log de backup mostra `[ERRO]`, backup do dia ausente, `daily_report.sh` reporta zero dumps nas ultimas 24h.

**Tempo estimado:** 5-10 minutos

---

## 1. Deteccao

Sinais de que o backup falhou:

```bash
# Erros no log de backup
$ grep "ERRO" /var/log/lorawan-backup.log | tail -10

# Verificar se o backup de hoje existe
$ ls -la <BACKUP_DIR>/chirpstack_$(date +%Y%m%d).dump

# Ultimo backup bem-sucedido
$ grep "backup finalizado" /var/log/lorawan-backup.log | tail -1

# Cron esta configurado?
$ sudo crontab -l | grep lorawan-backup
```

---

## 2. Triagem — Identificar a fase que falhou

O script de backup executa em fases independentes. Identifique qual falhou:

```bash
$ tail -50 /var/log/lorawan-backup.log
```

### Fase 1: PostgreSQL dump

```bash
# Sinal: "[ERRO] pg_dump falhou"
# Verificar se PostgreSQL esta rodando
$ systemctl is-active postgresql

# Testar pg_dump manualmente
$ sudo -u postgres pg_dump -Fc <PG_DATABASE> > /dev/null
```

### Fase 2: Redis snapshot

```bash
# Sinal: "[ERRO] redis BGSAVE falhou"
# Verificar se Redis esta rodando
$ systemctl is-active redis-server

# Testar BGSAVE manualmente
$ redis-cli BGSAVE
$ redis-cli LASTSAVE
```

### Fase 3: Configs tar

```bash
# Sinal: "[ERRO] tar de configs falhou"
# Geralmente causado por arquivo faltando ou permissao
# tar exit 1 (some files differ) e tolerado, exit 2+ e erro
```

### Fase 4: Sync remoto (Google Drive)

```bash
# Sinal: "[ERRO] rclone sync falhou"
# Verificar se rclone funciona
$ rclone ls <RCLONE_REMOTE>:<REMOTE_DIR>/ --max-depth 1 2>&1 | head -5
```

### Disco cheio?

```bash
$ df -h /
$ df -h <BACKUP_DIR>
# Se >90%, limpeza urgente
```

---

## 3. Recovery

### 3.1 PostgreSQL dump falhou

```bash
# Se PostgreSQL nao esta rodando, iniciar
$ sudo systemctl restart postgresql
$ sleep 3

# Re-executar backup manualmente
$ sudo bash ~/lorawan-backup.sh
$ tail -20 /var/log/lorawan-backup.log
```

Se pg_dump falha com permission denied:

```bash
# Verificar que o script roda como root (cron do root)
$ sudo crontab -l | grep lorawan-backup
# Deve ser: 0 3 * * * /bin/bash /home/<USER>/lorawan-backup.sh
```

### 3.2 Redis snapshot falhou

```bash
# Se Redis nao esta rodando
$ sudo systemctl restart redis-server

# Se disco cheio para snapshot
$ df -h /var/lib/redis/
# Limpar backups antigos se necessario (ver 3.5)
```

### 3.3 Disco cheio

```bash
# Verificar retencao — limpar backups alem do periodo
$ ls -la <BACKUP_DIR>/ | wc -l

# Remover backups com mais de 30 dias manualmente
$ find <BACKUP_DIR> -name "*.dump" -mtime +30 -delete
$ find <BACKUP_DIR> -name "*.rdb" -mtime +30 -delete
$ find <BACKUP_DIR> -name "*.tar.gz" -mtime +30 -delete

# Verificar espaco recuperado
$ df -h /
```

### 3.4 rclone / Google Drive falhou

```bash
# Testar conectividade do rclone
$ rclone lsd <RCLONE_REMOTE>: 2>&1

# Se "token expired" ou "invalid_grant":
# O token OAuth expira em ~6 meses. Renovar:
$ rclone config reconnect <RCLONE_REMOTE>:
# Seguir instrucoes (copiar URL para navegador, colar token)

# Se RPi esta offline (sem internet), sync remoto e esperado falhar
# O backup LOCAL continua funcional — apenas o sync para Drive falha
```

### 3.5 Re-executar backup manualmente

```bash
$ sudo bash ~/lorawan-backup.sh
$ echo $?  # 0 = sucesso, 1 = alguma fase falhou
$ tail -20 /var/log/lorawan-backup.log
```

---

## 4. Pos-incidente

```bash
# Confirmar que o backup de hoje existe
$ ls -la <BACKUP_DIR>/chirpstack_$(date +%Y%m%d).dump
$ ls -la <BACKUP_DIR>/redis_$(date +%Y%m%d).rdb
$ ls -la <BACKUP_DIR>/configs_$(date +%Y%m%d).tar.gz

# Verificar espaco livre (manter >500 MB)
$ df -h /

# Se o problema foi token OAuth, anotar data de renovacao
# O token expira em ~6 meses — programar proxima renovacao
```

### Prevencao

- Monitorar `daily_report.sh` para detectar backup ausente cedo
- Manter pelo menos 500 MB livres no SD
- Renovar token OAuth do rclone antes de expirar (~6 meses)
- Se o RPi opera 100% offline, o backup local e a unica protecao — garantir que o disco tem espaco
