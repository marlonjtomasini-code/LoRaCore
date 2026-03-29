#!/usr/bin/env bash
# Template LoRaCore — Backup diario da infraestrutura LoRaWAN
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 17.4
# Destino: /home/<USER>/lorawan-backup.sh
#
# Substituir:
#   <USER>             — usuario do sistema (ex: seuusuario)
#   <BACKUP_DIR>       — diretorio de backup local (ex: /home/seuusuario/backups)
#   <RCLONE_REMOTE>    — nome do remote rclone (ex: gdrive)
#   <REMOTE_DIR>       — pasta no Google Drive (ex: LoRaCore-backups)
#   <PG_DATABASE>      — nome do banco PostgreSQL (ex: chirpstack)
#   <RETENTION_DAYS>   — dias de retencao (ex: 30)
#
# Execucao: sudo bash /home/<USER>/lorawan-backup.sh
# Cron:     0 3 * * * /bin/bash /home/<USER>/lorawan-backup.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

DATE="$(date +%Y%m%d)"
BACKUP_DIR="<BACKUP_DIR>"
LOG_FILE="/var/log/lorawan-backup.log"
RETENTION_DAYS="<RETENTION_DAYS>"
RCLONE_REMOTE="<RCLONE_REMOTE>"
REMOTE_DIR="<REMOTE_DIR>"
PG_DATABASE="<PG_DATABASE>"
USER_HOME="/home/<USER>"
MIN_DISK_MB=500

# Artefatos do dia
PG_DUMP="${BACKUP_DIR}/chirpstack_${DATE}.dump"
REDIS_SNAP="${BACKUP_DIR}/redis_${DATE}.rdb"
CONFIG_TAR="${BACKUP_DIR}/configs_${DATE}.tar.gz"

# Acumulador de erros (0 = sucesso, 1 = pelo menos um erro)
EXIT_CODE=0

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
    EXIT_CODE=1
}

check_disk_space() {
    local avail_mb
    avail_mb=$(df -m "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [ "$avail_mb" -lt "$MIN_DISK_MB" ]; then
        log_error "Espaco em disco insuficiente: ${avail_mb} MB disponivel (minimo: ${MIN_DISK_MB} MB)"
        return 1
    fi
    return 0
}

# =============================================================================
# FASE 1: Setup
# =============================================================================

log "=== Backup iniciado ==="

mkdir -p "$BACKUP_DIR"

if ! check_disk_space; then
    log_error "Backup abortado por falta de espaco em disco"
    exit 1
fi

# =============================================================================
# FASE 2: PostgreSQL dump
# =============================================================================

log "Fase 2: Dump do PostgreSQL (${PG_DATABASE})..."

if sudo -u postgres pg_dump -Fc -d "$PG_DATABASE" > "$PG_DUMP" 2>> "$LOG_FILE"; then
    PG_SIZE=$(du -h "$PG_DUMP" | cut -f1)
    log "Fase 2: PostgreSQL dump concluido (${PG_SIZE})"
else
    log_error "Fase 2: Falha no dump do PostgreSQL"
    rm -f "$PG_DUMP"
fi

# =============================================================================
# FASE 3: Redis snapshot
# =============================================================================

log "Fase 3: Snapshot do Redis..."

REDIS_SRC="/var/lib/redis/dump.rdb"

# Capturar timestamp do ultimo save antes do BGSAVE
LASTSAVE_BEFORE=$(redis-cli LASTSAVE 2>/dev/null)

if redis-cli BGSAVE >> "$LOG_FILE" 2>&1; then
    # Aguardar BGSAVE concluir (max 30 segundos)
    WAITED=0
    while [ "$WAITED" -lt 30 ]; do
        LASTSAVE_AFTER=$(redis-cli LASTSAVE 2>/dev/null)
        if [ "$LASTSAVE_AFTER" != "$LASTSAVE_BEFORE" ]; then
            break
        fi
        sleep 1
        WAITED=$((WAITED + 1))
    done

    if [ "$WAITED" -ge 30 ]; then
        log_error "Fase 3: Timeout aguardando BGSAVE do Redis (30s) — copiando snapshot existente"
    fi
fi

# Copiar o snapshot (mesmo se BGSAVE falhou, o arquivo existente ainda e util)
if [ -f "$REDIS_SRC" ]; then
    if cp "$REDIS_SRC" "$REDIS_SNAP" 2>> "$LOG_FILE"; then
        REDIS_SIZE=$(du -h "$REDIS_SNAP" | cut -f1)
        log "Fase 3: Redis snapshot concluido (${REDIS_SIZE})"
    else
        log_error "Fase 3: Falha ao copiar snapshot do Redis"
    fi
else
    log_error "Fase 3: Arquivo ${REDIS_SRC} nao encontrado"
fi

# =============================================================================
# FASE 4: Arquivo de configuracoes
# =============================================================================

log "Fase 4: Arquivando configuracoes..."

# Diretorio temporario para crontabs
CRON_TMP=$(mktemp -d)
crontab -u "<USER>" -l > "${CRON_TMP}/crontab_<USER>.txt" 2>/dev/null || true
crontab -u root -l > "${CRON_TMP}/crontab_root.txt" 2>/dev/null || true

# Lista de configs a incluir (ignorar silenciosamente os ausentes)
tar czf "$CONFIG_TAR" \
    --ignore-failed-read \
    --warning=no-file-changed \
    /etc/chirpstack/ \
    /etc/chirpstack-mqtt-forwarder/ \
    /etc/mosquitto/mosquitto.conf \
    /etc/mosquitto/conf.d/ \
    /etc/systemd/system/lora-pkt-fwd.service \
    /etc/systemd/system/chirpstack.service.d/ \
    /etc/systemd/system/chirpstack-mqtt-forwarder.service.d/ \
    /etc/systemd/system/postgresql@.service.d/ \
    /etc/sysctl.d/90-lorawan.conf \
    /etc/udev/rules.d/60-scheduler.rules \
    /etc/postgresql/16/main/postgresql.conf \
    /etc/redis/redis.conf \
    /etc/systemd/journald.conf.d/ \
    /etc/systemd/resolved.conf.d/ \
    "${USER_HOME}/packet_forwarder/global_conf.json" \
    "${USER_HOME}/health_check.sh" \
    "${USER_HOME}/watchdog_concentrator.sh" \
    "${USER_HOME}/device_monitor.sh" \
    "${CRON_TMP}/" \
    2>> "$LOG_FILE"

TAR_EXIT=$?
rm -rf "$CRON_TMP"

if [ "$TAR_EXIT" -eq 0 ] || [ "$TAR_EXIT" -eq 1 ]; then
    # tar exit 1 = "some files differ" (normal para arquivos que mudam durante backup)
    CONFIG_SIZE=$(du -h "$CONFIG_TAR" | cut -f1)
    log "Fase 4: Arquivo de configs concluido (${CONFIG_SIZE})"
else
    log_error "Fase 4: Falha ao criar arquivo de configs (exit code: ${TAR_EXIT})"
fi

# =============================================================================
# FASE 5: Retencao local
# =============================================================================

log "Fase 5: Limpando backups locais com mais de ${RETENTION_DAYS} dias..."

DELETED=0
while IFS= read -r -d '' file; do
    rm -f "$file"
    DELETED=$((DELETED + 1))
done < <(find "$BACKUP_DIR" \( -name "chirpstack_*.dump" -o -name "redis_*.rdb" -o -name "configs_*.tar.gz" \) -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)

log "Fase 5: ${DELETED} arquivo(s) antigo(s) removido(s)"

# =============================================================================
# FASE 6: Sync remoto (rclone)
# =============================================================================

log "Fase 6: Sincronizando com Google Drive..."

if ! command -v rclone &> /dev/null; then
    log_error "Fase 6: rclone nao instalado — sync remoto ignorado"
elif ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:"; then
    log_error "Fase 6: Remote '${RCLONE_REMOTE}' nao configurado — sync remoto ignorado"
else
    if rclone copy "$BACKUP_DIR" "${RCLONE_REMOTE}:${REMOTE_DIR}" \
        --include "chirpstack_*.dump" \
        --include "redis_*.rdb" \
        --include "configs_*.tar.gz" \
        --retries 3 \
        --retries-sleep 10s \
        --low-level-retries 10 \
        --log-file "$LOG_FILE" \
        --log-level NOTICE \
        2>> "$LOG_FILE"; then
        log "Fase 6: Sync remoto concluido"
    else
        log_error "Fase 6: Falha no sync remoto (rclone copy)"
    fi

    # ===========================================================================
    # FASE 7: Retencao remota
    # ===========================================================================

    log "Fase 7: Limpando backups remotos com mais de ${RETENTION_DAYS} dias..."

    if rclone delete "${RCLONE_REMOTE}:${REMOTE_DIR}" \
        --min-age "${RETENTION_DAYS}d" \
        --retries 3 \
        2>> "$LOG_FILE"; then
        log "Fase 7: Retencao remota concluida"
    else
        log_error "Fase 7: Falha na limpeza remota"
    fi
fi

# =============================================================================
# FASE 8: Resumo
# =============================================================================

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
TODAY_COUNT=$(find "$BACKUP_DIR" -name "*_${DATE}.*" -type f 2>/dev/null | wc -l)

log "Resumo: ${TODAY_COUNT} artefato(s) gerado(s) hoje, diretorio total: ${TOTAL_SIZE}"
log "=== Backup finalizado (exit code: ${EXIT_CODE}) ==="

exit "$EXIT_CODE"
