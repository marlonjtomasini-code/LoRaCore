#!/usr/bin/env bash
# Template LoRaCore — Health check da infraestrutura LoRaWAN
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 17.1
# Destino: /home/<USER>/health_check.sh
#
# Substituir:
#   <USER>       — usuario do sistema (ex: seuusuario)
#   <MEM_THRESH> — percentual de memoria para alerta (ex: 80)
#   <DISK_THRESH> — percentual de disco para alerta (ex: 90)
#
# Execucao: bash /home/<USER>/health_check.sh
# Cron:     */5 * * * * /bin/bash /home/<USER>/health_check.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-health.log"
MEM_THRESH="<MEM_THRESH>"
DISK_THRESH="<DISK_THRESH>"

SERVICES=(
    lora-pkt-fwd
    chirpstack-mqtt-forwarder
    mosquitto
    chirpstack
    chirpstack-rest-api
    postgresql
    redis-server
)

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
}

log_alert() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [ALERTA] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

# =============================================================================
# Verificacao de servicos
# =============================================================================

check_services() {
    local failed=0
    for svc in "${SERVICES[@]}"; do
        if ! systemctl is-enabled "$svc" &>/dev/null; then
            continue  # servico nao instalado, ignorar
        fi
        if systemctl is-active --quiet "$svc"; then
            log "OK servico $svc ativo"
        else
            log_alert "servico $svc INATIVO"
            failed=$((failed + 1))
        fi
    done
    if [ "$failed" -eq 0 ]; then
        log "OK todos os servicos ativos"
    fi
}

# =============================================================================
# Verificacao de memoria
# =============================================================================

check_memory() {
    local mem_total mem_available mem_used_pct
    mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

    if [ "$mem_total" -gt 0 ] 2>/dev/null; then
        mem_used_pct=$(( (mem_total - mem_available) * 100 / mem_total ))
        if [ "$mem_used_pct" -ge "$MEM_THRESH" ]; then
            log_alert "memoria em ${mem_used_pct}% (limite: ${MEM_THRESH}%)"
        else
            log "OK memoria em ${mem_used_pct}%"
        fi
    else
        log_error "nao foi possivel ler /proc/meminfo"
    fi
}

# =============================================================================
# Verificacao de disco
# =============================================================================

check_disk() {
    local disk_used_pct
    disk_used_pct=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')

    if [ -n "$disk_used_pct" ]; then
        if [ "$disk_used_pct" -ge "$DISK_THRESH" ]; then
            log_alert "disco em ${disk_used_pct}% (limite: ${DISK_THRESH}%)"
        else
            log "OK disco em ${disk_used_pct}%"
        fi
    else
        log_error "nao foi possivel ler uso de disco"
    fi
}

# =============================================================================
# Verificacao de atividade do gateway (PULL_ACK)
# =============================================================================

check_gateway_activity() {
    if ! systemctl is-active --quiet lora-pkt-fwd 2>/dev/null; then
        log "SKIP verificacao PULL_ACK — lora-pkt-fwd nao ativo"
        return
    fi

    local pull_ack
    pull_ack=$(journalctl -u lora-pkt-fwd --since "2 minutes ago" --no-pager -q 2>/dev/null | grep -c "PULL_ACK" || true)

    if [ "$pull_ack" -gt 0 ]; then
        log "OK gateway ativo (${pull_ack} PULL_ACK nos ultimos 2 min)"
    else
        log_alert "gateway sem PULL_ACK nos ultimos 2 minutos"
    fi
}

# =============================================================================
# Temperatura do SoC (RPi5)
# =============================================================================

check_temperature() {
    if command -v vcgencmd &>/dev/null; then
        local temp
        temp=$(vcgencmd measure_temp 2>/dev/null | sed "s/temp=//;s/'C//")
        if [ -n "$temp" ]; then
            log "OK temperatura SoC: ${temp}C"
        fi
    elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local raw_temp temp
        raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((raw_temp / 1000))
        log "OK temperatura SoC: ${temp}C"
    fi
}

# =============================================================================
# Load average
# =============================================================================

check_load() {
    local load1 load5 load15
    read -r load1 load5 load15 _ < /proc/loadavg
    log "OK load average: ${load1} ${load5} ${load15}"
}

# =============================================================================
# Main
# =============================================================================

log "--- health check iniciado ---"
check_services
check_memory
check_disk
check_gateway_activity
check_temperature
check_load
log "--- health check finalizado ---"
