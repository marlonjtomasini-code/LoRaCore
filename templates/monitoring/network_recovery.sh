#!/usr/bin/env bash
# Template LoRaCore — Recuperacao automatica de conectividade de rede
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/network_recovery.sh
#
# Substituir:
#   <USER> — usuario do sistema (ex: seuusuario)
#
# Execucao: sudo bash /home/<USER>/network_recovery.sh
# Cron:     */5 * * * * /bin/bash /home/<USER>/network_recovery.sh
#
# Nota: A stack LoRaWAN NAO depende de rede (tudo localhost).
# Este script recupera rede apenas para SSH e backup sync.

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-recovery.log"
RUN_DIR="/run/lorawan"
COOLDOWN_FILE="${RUN_DIR}/network_recovery.cooldown"
COOLDOWN_SECONDS=1800    # 30 minutos de cooldown apos 3 ciclos falhados
PING_COUNT=3
PING_INTERVAL=2
PING_TIMEOUT=5

# =============================================================================
# Funcoes
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [NETWORK] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [NETWORK] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
}

# Obter IP do default gateway
get_gateway() {
    ip route 2>/dev/null | awk '/default/ {print $3; exit}'
}

# Obter interface da rota default
get_interface() {
    ip route 2>/dev/null | awk '/default/ {print $5; exit}'
}

# Testar conectividade
test_connectivity() {
    local gw="$1"
    ping -c "$PING_COUNT" -i "$PING_INTERVAL" -W "$PING_TIMEOUT" "$gw" &>/dev/null
}

# Verificar cooldown
is_in_cooldown() {
    if [ ! -f "$COOLDOWN_FILE" ]; then
        return 1
    fi
    local cooldown_ts
    cooldown_ts=$(cat "$COOLDOWN_FILE" 2>/dev/null)
    local now
    now=$(date +%s)
    if [ $((now - cooldown_ts)) -ge "$COOLDOWN_SECONDS" ]; then
        rm -f "$COOLDOWN_FILE"
        return 1  # cooldown expirou
    fi
    return 0  # ainda em cooldown
}

# =============================================================================
# Main
# =============================================================================

mkdir -p "$RUN_DIR"

# Se nao ha gateway, estamos em modo offline — exit silencioso
gateway=$(get_gateway)
if [ -z "$gateway" ]; then
    exit 0
fi

interface=$(get_interface)

# Verificar cooldown
if is_in_cooldown; then
    exit 0
fi

# Testar conectividade
if test_connectivity "$gateway"; then
    # Limpar estado de falha se existir
    rm -f "${RUN_DIR}/network_recovery.failures"
    exit 0
fi

# Rede caiu — iniciar recuperacao
log "gateway ${gateway} inacessivel via ${interface} — iniciando recuperacao"

# Ciclo 1: Reconfigurar interface
if command -v networkctl &>/dev/null; then
    log "tentativa 1: networkctl reconfigure ${interface}"
    networkctl reconfigure "$interface" 2>/dev/null || true
else
    log "tentativa 1: ip link reset ${interface}"
    ip link set "$interface" down 2>/dev/null || true
    sleep 2
    ip link set "$interface" up 2>/dev/null || true
fi

sleep 10
if test_connectivity "$gateway"; then
    log "OK rede recuperada apos reconfigure"
    exit 0
fi

# Ciclo 2: Reiniciar networkd/NetworkManager
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    log "tentativa 2: reiniciando NetworkManager"
    systemctl restart NetworkManager 2>/dev/null || true
elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
    log "tentativa 2: reiniciando systemd-networkd"
    systemctl restart systemd-networkd 2>/dev/null || true
fi

sleep 15
if test_connectivity "$gateway"; then
    log "OK rede recuperada apos restart do servico de rede"
    exit 0
fi

# Ciclo 3: Ultimo recurso — DHCP release/renew
log "tentativa 3: DHCP release/renew em ${interface}"
if command -v dhclient &>/dev/null; then
    dhclient -r "$interface" 2>/dev/null || true
    sleep 2
    dhclient "$interface" 2>/dev/null || true
fi

sleep 10
if test_connectivity "$gateway"; then
    log "OK rede recuperada apos DHCP renew"
    exit 0
fi

# Todas as tentativas falharam — registrar e entrar em cooldown
log_error "rede nao recuperada apos 3 tentativas — cooldown de ${COOLDOWN_SECONDS}s"
echo "$(date +%s)" > "$COOLDOWN_FILE"

# Contar falhas consecutivas
local_failures="${RUN_DIR}/network_recovery.failures"
if [ -f "$local_failures" ]; then
    count=$(wc -l < "$local_failures")
else
    count=0
fi
echo "$(date +%s)" >> "$local_failures"

# Alertar apos 3 falhas consecutivas (se alerta disponivel e online por outra via)
if [ "$count" -ge 2 ]; then
    # shellcheck source=/dev/null
    source "/home/<USER>/alert_dispatch.sh" 2>/dev/null || true
    if type alert_send &>/dev/null; then
        alert_send WARNING "network_recovery" "Rede inacessivel ha $((count + 1)) ciclos em ${interface}"
    fi
fi
