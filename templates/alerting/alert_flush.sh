#!/usr/bin/env bash
# Template LoRaCore — Flush de alertas em spool para backends externos
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/alert_flush.sh
#
# Substituir:
#   <USER>               — usuario do sistema (ex: seuusuario)
#   <NTFY_TOPIC>         — URL do topico ntfy.sh (ex: https://ntfy.sh/loracore-meusite)
#   <NTFY_TOKEN>         — token de acesso ntfy.sh (opcional, deixar vazio se publico)
#   <ALERT_WEBHOOK_URL>  — URL de webhook generico (opcional, deixar vazio se nao usar)
#
# Execucao: bash /home/<USER>/alert_flush.sh
# Cron:     */5 * * * * /bin/bash /home/<USER>/alert_flush.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

SPOOL_DIR="/var/spool/lorawan-alerts"
LOG_FILE="/var/log/lorawan-recovery.log"
NTFY_TOPIC="<NTFY_TOPIC>"
NTFY_TOKEN="<NTFY_TOKEN>"
WEBHOOK_URL="<ALERT_WEBHOOK_URL>"
PRUNE_HOURS=48

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [ALERT_FLUSH] $1"
    echo "$msg" >> "$LOG_FILE"
}

is_configured() {
    case "$NTFY_TOPIC" in
        *"<"*">"*) NTFY_TOPIC="" ;;
    esac
    case "$WEBHOOK_URL" in
        *"<"*">"*) WEBHOOK_URL="" ;;
    esac
    case "$NTFY_TOKEN" in
        *"<"*">"*) NTFY_TOKEN="" ;;
    esac

    if [ -z "$NTFY_TOPIC" ] && [ -z "$WEBHOOK_URL" ]; then
        return 1
    fi
    return 0
}

# Verificar conectividade (best-effort)
check_connectivity() {
    if [ -n "$NTFY_TOPIC" ]; then
        # Extrair hostname do topic URL
        local host
        host=$(echo "$NTFY_TOPIC" | sed 's|https\?://||' | cut -d/ -f1)
        curl -s --max-time 5 -o /dev/null "https://${host}" 2>/dev/null
        return $?
    fi
    # Fallback: testar resolucao DNS
    host -W 5 google.com &>/dev/null 2>&1
}

# Enviar via ntfy.sh
send_ntfy() {
    local severity="$1"
    local source="$2"
    local host="$3"
    local message="$4"

    local priority
    case "$severity" in
        CRITICAL) priority="urgent" ;;
        WARNING)  priority="high" ;;
        *)        priority="default" ;;
    esac

    local title="[${severity}] ${host} — ${source}"

    local curl_args=(curl -s --connect-timeout 5 --max-time 10
        -H "Title: ${title}"
        -H "Priority: ${priority}"
        -H "Tags: ${severity,,}")
    if [ -n "$NTFY_TOKEN" ]; then
        curl_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
    fi
    curl_args+=(-d "${message}" "${NTFY_TOPIC}")

    "${curl_args[@]}" 2>/dev/null

    return $?
}

# Escapar string para uso seguro em JSON
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

# Enviar via webhook generico
send_webhook() {
    local severity="$1"
    local source="$2"
    local host="$3"
    local message="$4"
    local timestamp="$5"

    local json_body
    json_body=$(printf '{"severity":"%s","source":"%s","host":"%s","message":"%s","timestamp":"%s"}' \
        "$(json_escape "$severity")" \
        "$(json_escape "$source")" \
        "$(json_escape "$host")" \
        "$(json_escape "$message")" \
        "$(json_escape "$timestamp")")

    curl -s --connect-timeout 5 --max-time 10 \
        -H "Content-Type: application/json" \
        -d "$json_body" \
        "${WEBHOOK_URL}" 2>/dev/null

    return $?
}

# Parsear um arquivo de spool
parse_spool() {
    local file="$1"
    # Resetar variaveis
    SPOOL_TIMESTAMP=""
    SPOOL_SEVERITY=""
    SPOOL_SOURCE=""
    SPOOL_HOST=""
    SPOOL_MESSAGE=""

    while IFS='=' read -r key value; do
        case "$key" in
            TIMESTAMP) SPOOL_TIMESTAMP="$value" ;;
            SEVERITY)  SPOOL_SEVERITY="$value" ;;
            SOURCE)    SPOOL_SOURCE="$value" ;;
            HOST)      SPOOL_HOST="$value" ;;
            MESSAGE)   SPOOL_MESSAGE="$value" ;;
        esac
    done < "$file"
}

# =============================================================================
# Main
# =============================================================================

# Verificar configuracao
if ! is_configured; then
    exit 0  # alertas nao configurados
fi

# Verificar se ha spool
if [ ! -d "$SPOOL_DIR" ]; then
    exit 0  # nada no spool
fi

# Contar alertas pendentes
pending=$(find "$SPOOL_DIR" -type f 2>/dev/null | wc -l)
if [ "$pending" -eq 0 ]; then
    exit 0  # spool vazio
fi

# Verificar conectividade
if ! check_connectivity; then
    exit 0  # offline — alertas ficam no spool
fi

# Processar spool
delivered=0
failed=0

for spool_file in "$SPOOL_DIR"/*; do
    [ -f "$spool_file" ] || continue

    parse_spool "$spool_file"

    if [ -z "$SPOOL_MESSAGE" ]; then
        rm -f "$spool_file"
        continue
    fi

    success=false

    # Tentar ntfy.sh
    if [ -n "$NTFY_TOPIC" ]; then
        if send_ntfy "$SPOOL_SEVERITY" "$SPOOL_SOURCE" "$SPOOL_HOST" "$SPOOL_MESSAGE"; then
            success=true
        fi
    fi

    # Tentar webhook (independente do ntfy)
    if [ -n "$WEBHOOK_URL" ]; then
        send_webhook "$SPOOL_SEVERITY" "$SPOOL_SOURCE" "$SPOOL_HOST" "$SPOOL_MESSAGE" "$SPOOL_TIMESTAMP" || true
    fi

    if $success; then
        rm -f "$spool_file"
        delivered=$((delivered + 1))
    else
        failed=$((failed + 1))
    fi
done

if [ "$delivered" -gt 0 ] || [ "$failed" -gt 0 ]; then
    log "flush: ${delivered} entregue(s), ${failed} falha(s) de ${pending} pendente(s)"
fi

# Prunar alertas expirados (>48h)
find "$SPOOL_DIR" -type f -mmin +$((PRUNE_HOURS * 60)) -delete 2>/dev/null || true

# Limpar arquivos de dedup e rate expirados
find /run/lorawan -name "alert_dedup_*" -mmin +60 -delete 2>/dev/null || true
find /run/lorawan -name "alert_rate_*" -mmin +120 -delete 2>/dev/null || true
