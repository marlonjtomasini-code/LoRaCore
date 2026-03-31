#!/usr/bin/env bash
# Template LoRaCore — Limpeza automatica de disco
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/disk_cleanup.sh
#
# Substituir:
#   <USER>           — usuario do sistema (ex: seuusuario)
#   <BACKUP_DIR>     — diretorio de backups (ex: /home/seuusuario/backups)
#   <RETENTION_DAYS> — dias de retencao de backups (ex: 30)
#
# Execucao: sudo bash /home/<USER>/disk_cleanup.sh
# Cron:     */30 * * * * /bin/bash /home/<USER>/disk_cleanup.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-recovery.log"
BACKUP_DIR="<BACKUP_DIR>"
RETENTION_DAYS="<RETENTION_DAYS>"

TIER1_THRESHOLD=80
TIER2_THRESHOLD=90
TIER3_THRESHOLD=95

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DISK] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_alert() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DISK] [ALERTA] $1"
    echo "$msg" >> "$LOG_FILE"
}

get_disk_pct() {
    df / | awk 'NR==2 {gsub(/%/,""); print $5}'
}

get_avail_mb() {
    df -m / | awk 'NR==2 {print $4}'
}

# =============================================================================
# Tiers de limpeza
# =============================================================================

tier1_cleanup() {
    log "Tier 1: limpeza padrao (disco > ${TIER1_THRESHOLD}%)"
    local freed=0

    # Journal: manter apenas ultimos 7 dias
    local before_mb
    before_mb=$(get_avail_mb)
    journalctl --vacuum-time=7d &>/dev/null || true
    local after_mb
    after_mb=$(get_avail_mb)
    freed=$((after_mb - before_mb))
    [ "$freed" -gt 0 ] && log "journal vacuum: ${freed}MB liberados"

    # Backups locais alem da retencao
    if [ -d "$BACKUP_DIR" ]; then
        local count=0
        while IFS= read -r -d '' file; do
            rm -f "$file"
            count=$((count + 1))
        done < <(find "$BACKUP_DIR" \( -name "chirpstack_*.dump" -o -name "redis_*.rdb" -o -name "configs_*.tar.gz" \) -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
        [ "$count" -gt 0 ] && log "backups antigos: ${count} arquivo(s) removido(s)"
    fi

    # Force logrotate
    logrotate -f /etc/logrotate.d/lorawan 2>/dev/null || true
    log "logrotate forcado"
}

tier2_cleanup() {
    log "Tier 2: limpeza agressiva (disco > ${TIER2_THRESHOLD}%)"

    # Journal: limitar a 100MB
    journalctl --vacuum-size=100M &>/dev/null || true
    log "journal truncado para 100MB"

    # Apt cache
    apt-get clean 2>/dev/null || true
    log "apt cache limpo"

    # Temporarios com mais de 1 dia
    local count=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        count=$((count + 1))
    done < <(find /tmp -type f -mtime +1 -print0 2>/dev/null)
    [ "$count" -gt 0 ] && log "/tmp: ${count} arquivo(s) antigo(s) removido(s)"
}

tier3_cleanup() {
    log_alert "Tier 3: limpeza critica (disco > ${TIER3_THRESHOLD}%)"

    # Truncar logs lorawan para ultimas 1000 linhas
    for logfile in /var/log/lorawan-health.log /var/log/lorawan-backup.log /var/log/lorawan-daily-report.log /var/log/lorawan-recovery.log; do
        if [ -f "$logfile" ]; then
            local lines
            lines=$(wc -l < "$logfile")
            if [ "$lines" -gt 1000 ]; then
                tail -1000 "$logfile" > "${logfile}.tmp"
                mv "${logfile}.tmp" "$logfile"
                log "truncado ${logfile} de ${lines} para 1000 linhas"
            fi
        fi
    done

    # Alerta externo
    # shellcheck source=/dev/null
    source "/home/<USER>/alert_dispatch.sh" 2>/dev/null || true
    if type alert_send &>/dev/null; then
        local pct
        pct=$(get_disk_pct)
        alert_send CRITICAL "disk_cleanup" "Disco em ${pct}% apos limpeza critica — intervencao manual necessaria"
    fi
}

# =============================================================================
# Main
# =============================================================================

disk_pct=$(get_disk_pct)

if [ "$disk_pct" -lt "$TIER1_THRESHOLD" ]; then
    exit 0  # disco saudavel
fi

log "disco em ${disk_pct}% — iniciando limpeza"

if [ "$disk_pct" -ge "$TIER1_THRESHOLD" ]; then
    tier1_cleanup
fi

# Re-checar apos tier 1
disk_pct=$(get_disk_pct)

if [ "$disk_pct" -ge "$TIER2_THRESHOLD" ]; then
    tier2_cleanup
fi

# Re-checar apos tier 2
disk_pct=$(get_disk_pct)

if [ "$disk_pct" -ge "$TIER3_THRESHOLD" ]; then
    tier3_cleanup
fi

final_pct=$(get_disk_pct)
avail_mb=$(get_avail_mb)
log "limpeza concluida: disco em ${final_pct}% (${avail_mb}MB disponivel)"
