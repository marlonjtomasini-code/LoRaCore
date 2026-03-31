#!/usr/bin/env bash
# Template LoRaCore — Manutencao de banco de dados e verificacao Redis
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/db_maintenance.sh
#
# Substituir:
#   <USER>        — usuario do sistema (ex: seuusuario)
#   <PG_DATABASE> — nome do banco PostgreSQL (ex: chirpstack)
#
# Execucao: sudo bash /home/<USER>/db_maintenance.sh
# Cron:     0 4 * * 0 /bin/bash /home/<USER>/db_maintenance.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-recovery.log"
PG_DATABASE="<PG_DATABASE>"

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DB_MAINT] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DB_MAINT] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_alert() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DB_MAINT] [ALERTA] $1"
    echo "$msg" >> "$LOG_FILE"
}

# =============================================================================
# PostgreSQL: VACUUM ANALYZE
# =============================================================================

pg_vacuum() {
    if ! systemctl is-active --quiet postgresql 2>/dev/null; then
        log_error "PostgreSQL nao esta ativo — pulando VACUUM"
        return 1
    fi

    log "iniciando VACUUM ANALYZE em ${PG_DATABASE}..."
    local start_ts
    start_ts=$(date +%s)

    if sudo -u postgres vacuumdb --analyze -d "$PG_DATABASE" 2>> "$LOG_FILE"; then
        local end_ts duration
        end_ts=$(date +%s)
        duration=$((end_ts - start_ts))
        log "VACUUM ANALYZE concluido em ${duration}s"
    else
        log_error "falha no VACUUM ANALYZE"
        return 1
    fi
}

# =============================================================================
# PostgreSQL: REINDEX (mensal — 1o domingo do mes)
# =============================================================================

pg_reindex() {
    local day_of_month
    day_of_month=$(date +%d)

    # Executar apenas se for o 1o domingo do mes (dia <= 7)
    if [ "$day_of_month" -gt 7 ]; then
        return 0
    fi

    log "1o domingo do mes — iniciando REINDEX em ${PG_DATABASE}..."
    local start_ts
    start_ts=$(date +%s)

    if sudo -u postgres reindexdb -d "$PG_DATABASE" 2>> "$LOG_FILE"; then
        local end_ts duration
        end_ts=$(date +%s)
        duration=$((end_ts - start_ts))
        log "REINDEX concluido em ${duration}s"
    else
        log_error "falha no REINDEX"
        return 1
    fi
}

# =============================================================================
# Redis: Verificacao de persistencia
# =============================================================================

redis_verify() {
    if ! systemctl is-active --quiet redis-server 2>/dev/null; then
        log_error "Redis nao esta ativo — pulando verificacao"
        return 1
    fi

    log "verificando persistencia do Redis..."

    # Verificar status do ultimo BGSAVE
    local bgsave_status
    bgsave_status=$(redis-cli INFO persistence 2>/dev/null | grep "rdb_last_bgsave_status" | tr -d '\r' | cut -d: -f2)

    if [ "$bgsave_status" != "ok" ]; then
        log_alert "Redis rdb_last_bgsave_status: ${bgsave_status:-unknown}"
        if type alert_send &>/dev/null; then
            alert_send WARNING "db_maintenance" "Redis BGSAVE status: ${bgsave_status:-unknown}"
        fi
        return 1
    fi

    # Forcar novo BGSAVE e verificar
    local lastsave_before
    lastsave_before=$(redis-cli LASTSAVE 2>/dev/null)

    redis-cli BGSAVE &>/dev/null

    local waited=0
    while [ "$waited" -lt 30 ]; do
        local lastsave_after
        lastsave_after=$(redis-cli LASTSAVE 2>/dev/null)
        if [ "$lastsave_after" != "$lastsave_before" ]; then
            log "Redis BGSAVE concluido com sucesso"
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    if [ "$waited" -ge 30 ]; then
        log_alert "Redis BGSAVE timeout (30s)"
        if type alert_send &>/dev/null; then
            alert_send WARNING "db_maintenance" "Redis BGSAVE timeout apos 30s"
        fi
        return 1
    fi

    # DBSIZE
    local dbsize
    dbsize=$(redis-cli DBSIZE 2>/dev/null | awk '{print $NF}')
    log "Redis DBSIZE: ${dbsize:-unknown}"

    return 0
}

# =============================================================================
# Monitoramento de swap
# =============================================================================

check_swap() {
    local swap_total swap_used
    swap_total=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
    swap_used=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)

    if [ "$swap_total" -eq 0 ] 2>/dev/null; then
        return 0  # sem swap configurado
    fi

    swap_used=$((swap_total - swap_used))
    local swap_used_mb=$((swap_used / 1024))

    if [ "$swap_used_mb" -gt 1024 ]; then
        log_alert "swap critico: ${swap_used_mb}MB usado (risco de instabilidade e desgaste SD)"
        if type alert_send &>/dev/null; then
            alert_send WARNING "db_maintenance" "Swap em ${swap_used_mb}MB — pressao de memoria alta"
        fi
    elif [ "$swap_used_mb" -gt 500 ]; then
        log_alert "swap alto: ${swap_used_mb}MB usado"
    else
        log "swap: ${swap_used_mb}MB usado"
    fi
}

# =============================================================================
# Main
# =============================================================================

# Carregar alertas externos (se disponivel)
# shellcheck source=/dev/null
source "/home/<USER>/alert_dispatch.sh" 2>/dev/null || true

log "=== manutencao de banco iniciada ==="

pg_vacuum
pg_reindex
redis_verify
check_swap

log "=== manutencao de banco finalizada ==="
