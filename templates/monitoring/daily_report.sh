#!/usr/bin/env bash
# Template LoRaCore — Relatorio diario da infraestrutura LoRaWAN
# Fonte: TASK-2026-0006 (observabilidade leve)
# Destino: /home/<USER>/daily_report.sh
#
# Substituir:
#   <USER>              — usuario do sistema (ex: seuusuario)
#   <CHIRPSTACK_HOST>   — host do ChirpStack REST API (ex: localhost)
#   <CHIRPSTACK_PORT>   — porta do ChirpStack REST API (ex: 8090)
#   <CHIRPSTACK_TOKEN>  — API key do ChirpStack
#   <BACKUP_DIR>        — diretorio de backups (ex: /home/seuusuario/backups)
#   <APPLICATION_ID>    — UUID da application no ChirpStack (obter via Web UI ou API)
#
# Execucao: bash /home/<USER>/daily_report.sh
# Cron:     0 7 * * * /bin/bash /home/<USER>/daily_report.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-daily-report.log"
CHIRPSTACK_HOST="<CHIRPSTACK_HOST>"
CHIRPSTACK_PORT="<CHIRPSTACK_PORT>"
CHIRPSTACK_TOKEN="<CHIRPSTACK_TOKEN>"
BACKUP_DIR="<BACKUP_DIR>"
APPLICATION_ID="<APPLICATION_ID>"
API_BASE="http://${CHIRPSTACK_HOST}:${CHIRPSTACK_PORT}/api"

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

separator() {
    log "============================================================"
}

# =============================================================================
# Cabecalho
# =============================================================================

separator
log "RELATORIO DIARIO — $(date '+%Y-%m-%d %A')"
separator

# =============================================================================
# Uptime do sistema
# =============================================================================

log "UPTIME: $(uptime -p 2>/dev/null || uptime)"

# =============================================================================
# Status dos servicos
# =============================================================================

log ""
log "SERVICOS:"

SERVICES=(
    lora-pkt-fwd
    chirpstack-mqtt-forwarder
    mosquitto
    chirpstack
    chirpstack-rest-api
    postgresql
    redis-server
)

for svc in "${SERVICES[@]}"; do
    if ! systemctl is-enabled "$svc" &>/dev/null; then
        continue
    fi
    if systemctl is-active --quiet "$svc"; then
        runtime=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null)
        log "  [OK]   $svc (desde $runtime)"
    else
        log "  [FAIL] $svc INATIVO"
    fi
done

# =============================================================================
# Memoria
# =============================================================================

log ""
log "MEMORIA:"
mem_total=$(awk '/^MemTotal:/ {printf "%.0f", $2/1024}' /proc/meminfo)
mem_available=$(awk '/^MemAvailable:/ {printf "%.0f", $2/1024}' /proc/meminfo)
mem_used=$((mem_total - mem_available))
mem_pct=$((mem_used * 100 / mem_total))
log "  Usada: ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"

# =============================================================================
# Disco
# =============================================================================

log ""
log "DISCO:"
disk_info=$(df -h / | awk 'NR==2 {print "  Usado: "$3" / "$2" ("$5")"}')
log "$disk_info"

# =============================================================================
# Temperatura
# =============================================================================

if command -v vcgencmd &>/dev/null; then
    temp=$(vcgencmd measure_temp 2>/dev/null | sed "s/temp=//;s/'C//")
    log ""
    log "TEMPERATURA SoC: ${temp}C"
elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp=$((raw_temp / 1000))
    log ""
    log "TEMPERATURA SoC: ${temp}C"
fi

# =============================================================================
# Load average
# =============================================================================

log ""
read -r load1 load5 load15 _ < /proc/loadavg
log "LOAD AVERAGE: ${load1} ${load5} ${load15}"

# =============================================================================
# Gateway — PULL_ACK nas ultimas 24h
# =============================================================================

log ""
log "GATEWAY (ultimas 24h):"

if systemctl is-active --quiet lora-pkt-fwd 2>/dev/null; then
    pull_ack_24h=$(journalctl -u lora-pkt-fwd --since "24 hours ago" --no-pager -q 2>/dev/null | grep -c "PULL_ACK" || true)
    log "  PULL_ACK recebidos: ${pull_ack_24h}"
else
    log "  lora-pkt-fwd nao ativo"
fi

# =============================================================================
# Devices — last seen
# =============================================================================

log ""
log "DEVICES:"

if command -v curl &>/dev/null; then
    response=$(curl -s --max-time 10 \
        "${API_BASE}/devices?limit=100&applicationId=${APPLICATION_ID}" \
        -H "Authorization: Bearer ${CHIRPSTACK_TOKEN}" 2>/dev/null)

    if [ -n "$response" ]; then
        device_names=()
        device_lastseen=()

        while IFS= read -r line; do
            device_names+=("$line")
        done < <(echo "$response" | grep -oP '"name"\s*:\s*"\K[^"]+' || true)

        while IFS= read -r line; do
            device_lastseen+=("$line")
        done < <(echo "$response" | grep -oP '"lastSeenAt"\s*:\s*"\K[^"]+' || true)

        device_count=${#device_names[@]}
        now_epoch=$(date +%s)

        if [ "$device_count" -gt 0 ]; then
            for i in $(seq 0 $((device_count - 1))); do
                name="${device_names[$i]:-unknown}"
                last_seen="${device_lastseen[$i]:-never}"
                if [ "$last_seen" != "never" ] && [ "$last_seen" != "null" ]; then
                    last_epoch=$(date -d "$last_seen" +%s 2>/dev/null || echo "")
                    if [ -n "$last_epoch" ]; then
                        delta=$((now_epoch - last_epoch))
                        if [ "$delta" -lt 60 ]; then
                            ago="${delta}s"
                        elif [ "$delta" -lt 3600 ]; then
                            ago="$((delta / 60))min"
                        else
                            ago="$((delta / 3600))h"
                        fi
                        log "  ${name}: ultimo report ha ${ago}"
                    else
                        log "  ${name}: last seen ${last_seen}"
                    fi
                else
                    log "  ${name}: nunca reportou"
                fi
            done
        else
            log "  nenhum device registrado"
        fi
    else
        log "  ChirpStack REST API indisponivel"
    fi
else
    log "  curl nao encontrado — skip"
fi

# =============================================================================
# Status do ultimo backup
# =============================================================================

log ""
log "BACKUP:"

backup_log="/var/log/lorawan-backup.log"
if [ -f "$backup_log" ]; then
    last_backup=$(grep "backup finalizado" "$backup_log" 2>/dev/null | tail -1)
    if [ -n "$last_backup" ]; then
        log "  Ultimo: $last_backup"
    else
        log "  Nenhum backup finalizado encontrado no log"
    fi
else
    log "  Log de backup nao encontrado"
fi

if [ -d "$BACKUP_DIR" ]; then
    backup_count=$(find "$BACKUP_DIR" -name "chirpstack_*.dump" -mtime -1 2>/dev/null | wc -l)
    log "  Dumps das ultimas 24h: ${backup_count}"
    backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    log "  Tamanho total: ${backup_size}"
else
    log "  Diretorio de backup nao encontrado: ${BACKUP_DIR}"
fi

separator
log "FIM DO RELATORIO DIARIO"
separator
