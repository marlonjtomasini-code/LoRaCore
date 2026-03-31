#!/usr/bin/env bash
# Template LoRaCore — Monitor de devices offline
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 17.3
# Destino: /home/<USER>/device_monitor.sh
#
# Substituir:
#   <USER>              — usuario do sistema (ex: seuusuario)
#   <CHIRPSTACK_HOST>   — host do ChirpStack REST API (ex: localhost)
#   <CHIRPSTACK_PORT>   — porta do ChirpStack REST API (ex: 8090)
#   <CHIRPSTACK_TOKEN>  — API key do ChirpStack (gerar via Web UI ou psql)
#   <OFFLINE_THRESHOLD> — segundos sem report para considerar offline (ex: 180)
#   <APPLICATION_ID>    — UUID da application no ChirpStack (obter via Web UI ou API)
#
# Execucao: bash /home/<USER>/device_monitor.sh
# Cron:     */3 * * * * /bin/bash /home/<USER>/device_monitor.sh

set -u

# Alertas externos (opcional — no-op se nao instalado)
# shellcheck source=/dev/null
source "/home/<USER>/alert_dispatch.sh" 2>/dev/null || true

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-health.log"
CHIRPSTACK_HOST="<CHIRPSTACK_HOST>"
CHIRPSTACK_PORT="<CHIRPSTACK_PORT>"
CHIRPSTACK_TOKEN="<CHIRPSTACK_TOKEN>"
OFFLINE_THRESHOLD="<OFFLINE_THRESHOLD>"
APPLICATION_ID="<APPLICATION_ID>"
API_BASE="http://${CHIRPSTACK_HOST}:${CHIRPSTACK_PORT}/api"

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DEVICE_MON] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

log_alert() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DEVICE_MON] [ALERTA] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [DEVICE_MON] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

# Converter ISO 8601 timestamp para epoch (compativel com date GNU e busybox)
iso_to_epoch() {
    date -d "$1" +%s 2>/dev/null
}

# =============================================================================
# Verificacao de dependencias
# =============================================================================

if ! command -v curl &>/dev/null; then
    log_error "curl nao encontrado"
    exit 1
fi

# Verificar se ChirpStack REST API esta acessivel
if ! curl -s --max-time 5 -o /dev/null -w '' "${API_BASE}/devices?limit=1" \
    -H "Authorization: Bearer ${CHIRPSTACK_TOKEN}" 2>/dev/null; then
    log_error "ChirpStack REST API indisponivel em ${API_BASE}"
    exit 1
fi

# =============================================================================
# Main
# =============================================================================

now_epoch=$(date +%s)
offline_count=0
online_count=0

# Buscar devices (limite 100 — ajustar se necessario)
response=$(curl -s --max-time 10 \
    "${API_BASE}/devices?limit=100&applicationId=${APPLICATION_ID}" \
    -H "Authorization: Bearer ${CHIRPSTACK_TOKEN}" 2>/dev/null)

if [ -z "$response" ]; then
    log_error "resposta vazia da API"
    exit 1
fi

# Extrair devices com parsing basico (sem jq para zero dependencias)
# Formato esperado: lista JSON com campos "name", "devEui", "lastSeenAt"
# Usa grep + sed para extrair campos relevantes

# Extrair pares name/devEui/lastSeenAt
device_names=()
device_euis=()
device_lastseen=()

while IFS= read -r line; do
    device_names+=("$line")
done < <(echo "$response" | grep -oP '"name"\s*:\s*"\K[^"]+' || true)

while IFS= read -r line; do
    device_euis+=("$line")
done < <(echo "$response" | grep -oP '"devEui"\s*:\s*"\K[^"]+' || true)

while IFS= read -r line; do
    device_lastseen+=("$line")
done < <(echo "$response" | grep -oP '"lastSeenAt"\s*:\s*"\K[^"]+' || true)

device_count=${#device_euis[@]}

if [ "$device_count" -eq 0 ]; then
    log "nenhum device registrado"
    exit 0
fi

for i in $(seq 0 $((device_count - 1))); do
    name="${device_names[$i]:-unknown}"
    eui="${device_euis[$i]:-unknown}"
    last_seen="${device_lastseen[$i]:-}"

    if [ -z "$last_seen" ] || [ "$last_seen" = "null" ]; then
        log_alert "OFFLINE ${name} (${eui}) — nunca reportou"
        offline_count=$((offline_count + 1))
        continue
    fi

    last_epoch=$(iso_to_epoch "$last_seen")
    if [ -z "$last_epoch" ]; then
        log_error "nao foi possivel converter lastSeenAt para ${name}: ${last_seen}"
        continue
    fi

    delta=$((now_epoch - last_epoch))

    if [ "$delta" -gt "$OFFLINE_THRESHOLD" ]; then
        log_alert "OFFLINE ${name} (${eui}) — ultimo report ha ${delta}s (limite: ${OFFLINE_THRESHOLD}s)"
        offline_count=$((offline_count + 1))
    else
        log "OK ${name} (${eui}) — ultimo report ha ${delta}s"
        online_count=$((online_count + 1))
    fi
done

log "resumo: ${online_count} online, ${offline_count} offline de ${device_count} devices"

if [ "$offline_count" -gt 0 ]; then
    type alert_send &>/dev/null && alert_send WARNING "device_monitor" "${offline_count} device(s) offline de ${device_count} total"
fi
