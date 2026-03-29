#!/usr/bin/env bash
# Template LoRaCore — Watchdog do concentrador LoRa
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 17.2
# Destino: /home/<USER>/watchdog_concentrator.sh
#
# Substituir:
#   <USER>             — usuario do sistema (ex: seuusuario)
#   <PULL_ACK_TIMEOUT> — segundos sem PULL_ACK para reiniciar (ex: 90)
#
# Execucao: sudo bash /home/<USER>/watchdog_concentrator.sh
# Cron:     */2 * * * * /bin/bash /home/<USER>/watchdog_concentrator.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-health.log"
PULL_ACK_TIMEOUT="<PULL_ACK_TIMEOUT>"
SERVICE="lora-pkt-fwd"

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [WATCHDOG] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [WATCHDOG] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >&2
}

# =============================================================================
# Main
# =============================================================================

# Verificar se o servico esta instalado
if ! systemctl is-enabled "$SERVICE" &>/dev/null; then
    exit 0  # servico nao instalado, nada a fazer
fi

# Verificar se o servico esta ativo
if ! systemctl is-active --quiet "$SERVICE"; then
    log "servico $SERVICE inativo — tentando iniciar"
    systemctl start "$SERVICE" 2>/dev/null || log_error "falha ao iniciar $SERVICE"
    exit 0
fi

# Verificar PULL_ACK nos ultimos N segundos
pull_ack=$(journalctl -u "$SERVICE" --since "${PULL_ACK_TIMEOUT} seconds ago" --no-pager -q 2>/dev/null | grep -c "PULL_ACK" || true)

if [ "$pull_ack" -gt 0 ]; then
    log "OK concentrador ativo (${pull_ack} PULL_ACK em ${PULL_ACK_TIMEOUT}s)"
    exit 0
fi

# Sem PULL_ACK — reiniciar servico
log "ALERTA sem PULL_ACK em ${PULL_ACK_TIMEOUT}s — reiniciando $SERVICE"
systemctl restart "$SERVICE" 2>/dev/null

# Aguardar e verificar se voltou
sleep 5
if systemctl is-active --quiet "$SERVICE"; then
    log "OK $SERVICE reiniciado com sucesso"
else
    log_error "$SERVICE nao voltou apos restart"
fi
