#!/usr/bin/env bash
# Template LoRaCore — Biblioteca de despacho de alertas externos
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/alert_dispatch.sh
#
# Substituir:
#   <USER>               — usuario do sistema (ex: seuusuario)
#   <NTFY_TOPIC>         — URL do topico ntfy.sh (ex: https://ntfy.sh/loracore-meusite)
#   <NTFY_TOKEN>         — token de acesso ntfy.sh (opcional, deixar vazio se publico)
#   <ALERT_WEBHOOK_URL>  — URL de webhook generico (opcional, deixar vazio se nao usar)
#   <ALERT_HOST_NAME>    — nome legivel do gateway (ex: fazenda-norte-gw01)
#   <ALERT_RATE_LIMIT>   — max alertas por hora por source (ex: 10)
#   <ALERT_DEDUP_MINUTES> — minutos para deduplicacao (ex: 30)
#
# Uso: source /home/<USER>/alert_dispatch.sh
#       alert_send CRITICAL "auto_recovery" "Circuit breaker aberto para chirpstack"
#
# Este arquivo e uma biblioteca (sourceable), NAO um executavel.
# Se os placeholders nao foram configurados, todas as funcoes viram no-ops.

# Guard: nao executar, apenas source
if [ "${_ALERT_DISPATCH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || true
fi
_ALERT_DISPATCH_LOADED=1

# =============================================================================
# Configuracao
# =============================================================================

_ALERT_SPOOL_DIR="/var/spool/lorawan-alerts"
_ALERT_LOG_FILE="/var/log/lorawan-recovery.log"
_ALERT_NTFY_TOPIC="<NTFY_TOPIC>"
_ALERT_NTFY_TOKEN="<NTFY_TOKEN>"
_ALERT_WEBHOOK_URL="<ALERT_WEBHOOK_URL>"
_ALERT_HOST_NAME="<ALERT_HOST_NAME>"
_ALERT_RATE_LIMIT="<ALERT_RATE_LIMIT>"
_ALERT_DEDUP_MINUTES="<ALERT_DEDUP_MINUTES>"
_ALERT_RUN_DIR="/run/lorawan"

# =============================================================================
# Funcoes internas
# =============================================================================

_alert_log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] [ALERT] $1" >> "$_ALERT_LOG_FILE" 2>/dev/null || true
}

_alert_is_configured() {
    # Verificar se placeholders foram substituidos
    # Se o topic contem < e >, ainda e placeholder
    case "$_ALERT_NTFY_TOPIC" in
        *"<"*">"*) return 1 ;;
    esac
    case "$_ALERT_WEBHOOK_URL" in
        *"<"*">"*) _ALERT_WEBHOOK_URL="" ;;
    esac

    if [ -z "$_ALERT_NTFY_TOPIC" ] && [ -z "$_ALERT_WEBHOOK_URL" ]; then
        return 1
    fi
    return 0
}

_alert_hash() {
    # Hash simples para deduplicacao (source + message)
    echo -n "${1}${2}" | md5sum 2>/dev/null | cut -d' ' -f1 || echo -n "${1}${2}" | cksum | cut -d' ' -f1
}

_alert_check_dedup() {
    local hash="$1"
    local dedup_file="${_ALERT_RUN_DIR}/alert_dedup_${hash}"
    local now
    now=$(date +%s)

    if [ -f "$dedup_file" ]; then
        local last_ts
        last_ts=$(cat "$dedup_file" 2>/dev/null)
        local elapsed=$(( now - last_ts ))
        local window=$(( _ALERT_DEDUP_MINUTES * 60 ))
        if [ "$elapsed" -lt "$window" ]; then
            return 1  # duplicado dentro da janela
        fi
    fi

    echo "$now" > "$dedup_file"
    return 0
}

_alert_check_rate() {
    local source="$1"
    local rate_file="${_ALERT_RUN_DIR}/alert_rate_${source}"
    local now
    now=$(date +%s)
    local hour_ago=$((now - 3600))

    # Limpar entradas antigas
    if [ -f "$rate_file" ]; then
        local temp="${rate_file}.tmp"
        while IFS= read -r ts; do
            if [ "$ts" -gt "$hour_ago" ] 2>/dev/null; then
                echo "$ts"
            fi
        done < "$rate_file" > "$temp"
        mv "$temp" "$rate_file"
    fi

    # Contar
    local count=0
    if [ -f "$rate_file" ]; then
        count=$(wc -l < "$rate_file")
    fi

    if [ "$count" -ge "$_ALERT_RATE_LIMIT" ]; then
        return 1  # rate limit atingido
    fi

    echo "$now" >> "$rate_file"
    return 0
}

# Mapear severidade para prioridade ntfy.sh
_alert_ntfy_priority() {
    case "$1" in
        CRITICAL) echo "urgent" ;;
        WARNING)  echo "high" ;;
        INFO)     echo "default" ;;
        *)        echo "default" ;;
    esac
}

# =============================================================================
# Funcao publica: alert_send
# =============================================================================

# alert_send <SEVERITY> <SOURCE> <MESSAGE>
# SEVERITY: CRITICAL, WARNING, INFO
# SOURCE: nome do script chamador (ex: auto_recovery, watchdog)
# MESSAGE: descricao do alerta
alert_send() {
    local severity="${1:-INFO}"
    local source="${2:-unknown}"
    local message="${3:-}"

    # Verificar se alertas estao configurados
    if ! _alert_is_configured; then
        return 0  # no-op silencioso
    fi

    if [ -z "$message" ]; then
        return 0
    fi

    # Verificar deduplicacao
    local hash
    hash=$(_alert_hash "$source" "$message")
    if ! _alert_check_dedup "$hash"; then
        _alert_log "dedup: alerta suprimido ($source: $message)"
        return 0
    fi

    # Verificar rate limit
    if ! _alert_check_rate "$source"; then
        _alert_log "rate limit: alerta suprimido ($source)"
        return 0
    fi

    # Criar spool directory se necessario
    mkdir -p "$_ALERT_SPOOL_DIR" 2>/dev/null || true

    # Gerar arquivo de spool
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
    local spool_file="${_ALERT_SPOOL_DIR}/${timestamp}_${source}_${hash}"

    cat > "$spool_file" <<SPOOL
TIMESTAMP=${timestamp}
SEVERITY=${severity}
SOURCE=${source}
HOST=${_ALERT_HOST_NAME}
MESSAGE=${message}
HASH=${hash}
SPOOL

    _alert_log "spool: ${severity} de ${source} — ${message}"
    return 0
}
