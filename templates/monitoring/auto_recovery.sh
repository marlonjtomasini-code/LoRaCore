#!/usr/bin/env bash
# Template LoRaCore — Auto-recovery orquestrado da stack LoRaWAN
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: /home/<USER>/auto_recovery.sh
#
# Substituir:
#   <USER> — usuario do sistema (ex: seuusuario)
#
# Execucao: sudo bash /home/<USER>/auto_recovery.sh
# Cron:     */2 * * * * /bin/bash /home/<USER>/auto_recovery.sh

set -u

# =============================================================================
# Configuracao
# =============================================================================

LOG_FILE="/var/log/lorawan-recovery.log"
RUN_DIR="/run/lorawan"
LOCK_FILE="${RUN_DIR}/auto_recovery.lock"

# Limites do circuit breaker
CB_MAX_RESTARTS=3           # max restarts por servico antes de abrir circuit
CB_WINDOW_SECONDS=900       # janela de 15 minutos
CB_COOLDOWN_SECONDS=1800    # cooldown de 30 minutos apos circuit abrir
CB_FULLSTACK_THRESHOLD=3    # quantos circuits abertos para tentar full-stack restart

# Ordem de dependencia (restart de baixo para cima)
ORDERED_SERVICES=(
    postgresql
    redis-server
    mosquitto
    lora-pkt-fwd
    chirpstack-mqtt-forwarder
    chirpstack
    chirpstack-rest-api
)

# Mapa de dependencias: servico -> dependencias (separadas por espaco)
# Se uma dependencia cai, todos os dependentes devem reiniciar tambem
declare -A DEPS=(
    [postgresql]=""
    [redis-server]=""
    [mosquitto]=""
    [lora-pkt-fwd]=""
    [chirpstack-mqtt-forwarder]="mosquitto"
    [chirpstack]="postgresql redis-server mosquitto"
    [chirpstack-rest-api]="chirpstack"
)

# Tempo de espera apos restart (segundos)
declare -A WAIT_AFTER=(
    [postgresql]=3
    [redis-server]=3
    [mosquitto]=2
    [lora-pkt-fwd]=2
    [chirpstack-mqtt-forwarder]=2
    [chirpstack]=3
    [chirpstack-rest-api]=2
)

# =============================================================================
# Funcoes de log
# =============================================================================

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [RECOVERY] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [RECOVERY] [ERRO] $1"
    echo "$msg" >> "$LOG_FILE"
}

log_alert() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="[${ts}] [RECOVERY] [ALERTA] $1"
    echo "$msg" >> "$LOG_FILE"
}

# =============================================================================
# Lock (prevenir execucao concorrente)
# =============================================================================

mkdir -p "$RUN_DIR"

# Lock atomico via flock — previne execucao concorrente
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# =============================================================================
# Circuit Breaker
# =============================================================================

cb_counter_file() {
    echo "${RUN_DIR}/${1}.restart_count"
}

cb_cooldown_file() {
    echo "${RUN_DIR}/${1}.circuit_open"
}

cb_is_open() {
    local svc="$1"
    local cooldown_file
    cooldown_file="$(cb_cooldown_file "$svc")"

    if [ ! -f "$cooldown_file" ]; then
        return 1  # circuit fechado
    fi

    local open_ts
    open_ts=$(cat "$cooldown_file" 2>/dev/null)
    local now
    now=$(date +%s)
    local elapsed=$((now - open_ts))

    if [ "$elapsed" -ge "$CB_COOLDOWN_SECONDS" ]; then
        rm -f "$cooldown_file"
        rm -f "$(cb_counter_file "$svc")"
        log "circuit breaker reset para $svc (cooldown ${CB_COOLDOWN_SECONDS}s expirou)"
        return 1  # circuit fechado (reset)
    fi

    return 0  # circuit aberto
}

cb_record_restart() {
    local svc="$1"
    local counter_file
    counter_file="$(cb_counter_file "$svc")"
    local now
    now=$(date +%s)

    # Limpar entradas fora da janela
    if [ -f "$counter_file" ]; then
        local temp_file="${counter_file}.tmp"
        while IFS= read -r ts; do
            if [ $((now - ts)) -lt "$CB_WINDOW_SECONDS" ]; then
                echo "$ts"
            fi
        done < "$counter_file" > "$temp_file"
        mv "$temp_file" "$counter_file"
    fi

    # Registrar restart atual
    echo "$now" >> "$counter_file"

    # Verificar se atingiu o limite
    local count
    count=$(wc -l < "$counter_file")
    if [ "$count" -ge "$CB_MAX_RESTARTS" ]; then
        echo "$now" > "$(cb_cooldown_file "$svc")"
        log_alert "CIRCUIT_OPEN para $svc ($count restarts em ${CB_WINDOW_SECONDS}s)"

        # Enviar alerta externo (se disponivel)
        if type alert_send &>/dev/null; then
            alert_send CRITICAL "auto_recovery" "Circuit breaker aberto para $svc ($count restarts em ${CB_WINDOW_SECONDS}s)"
        fi

        return 1  # circuit abriu
    fi

    return 0  # circuit ainda fechado
}

cb_count_open() {
    local count=0
    for svc in "${ORDERED_SERVICES[@]}"; do
        if cb_is_open "$svc"; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# =============================================================================
# Recuperacao de servicos
# =============================================================================

restart_service() {
    local svc="$1"
    local wait_time="${WAIT_AFTER[$svc]:-2}"

    # Tentar reset-failed caso systemd tenha desistido (StartLimitBurst)
    systemctl reset-failed "$svc" 2>/dev/null || true

    log "reiniciando $svc..."
    if systemctl start "$svc" 2>/dev/null; then
        sleep "$wait_time"
        if systemctl is-active --quiet "$svc"; then
            log "OK $svc reiniciado com sucesso"
            return 0
        fi
    fi

    log_error "falha ao reiniciar $svc"
    return 1
}

# Dado um servico que caiu, determinar quais dependentes tambem precisam reiniciar
get_dependents() {
    local failed_svc="$1"
    local dependents=()

    for svc in "${ORDERED_SERVICES[@]}"; do
        local deps="${DEPS[$svc]:-}"
        if [ -n "$deps" ]; then
            for dep in $deps; do
                if [ "$dep" = "$failed_svc" ]; then
                    dependents+=("$svc")
                    break
                fi
            done
        fi
    done

    echo "${dependents[*]}"
}

# =============================================================================
# Verificacao e recuperacao
# =============================================================================

check_and_recover() {
    local failed_services=()
    local recovered=0

    # Fase 1: Detectar servicos inativos
    for svc in "${ORDERED_SERVICES[@]}"; do
        if ! systemctl is-enabled "$svc" &>/dev/null; then
            continue  # servico nao instalado
        fi
        if ! systemctl is-active --quiet "$svc"; then
            failed_services+=("$svc")
        fi
    done

    if [ ${#failed_services[@]} -eq 0 ]; then
        return 0  # tudo OK
    fi

    log_alert "${#failed_services[@]} servico(s) inativo(s): ${failed_services[*]}"

    # Fase 2: Determinar conjunto completo de servicos a reiniciar
    # (servico que caiu + todos os dependentes)
    declare -A restart_set=()
    for failed in "${failed_services[@]}"; do
        restart_set["$failed"]=1
        local dependents
        dependents=$(get_dependents "$failed")
        for dep in $dependents; do
            restart_set["$dep"]=1
        done
    done

    # Fase 3: Reiniciar na ordem correta, respeitando circuit breaker
    for svc in "${ORDERED_SERVICES[@]}"; do
        if [ "${restart_set[$svc]:-0}" != "1" ]; then
            continue
        fi

        # Se ja esta ativo (dependente que nao caiu), pular
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            continue
        fi

        # Verificar circuit breaker
        if cb_is_open "$svc"; then
            log "SKIP $svc — circuit breaker aberto"
            continue
        fi

        if restart_service "$svc"; then
            recovered=$((recovered + 1))
            cb_record_restart "$svc" || true
        else
            cb_record_restart "$svc" || true
        fi
    done

    if [ "$recovered" -gt 0 ]; then
        log "recuperacao concluida: $recovered servico(s) reiniciado(s)"
    fi
}

# =============================================================================
# Full-stack restart (ultimo recurso)
# =============================================================================

fullstack_restart() {
    local cooldown_file="${RUN_DIR}/fullstack.cooldown"
    local now
    now=$(date +%s)

    # Verificar cooldown (1 hora entre full-stack restarts)
    if [ -f "$cooldown_file" ]; then
        local last_ts
        last_ts=$(cat "$cooldown_file" 2>/dev/null)
        if [ $((now - last_ts)) -lt 3600 ]; then
            log "SKIP full-stack restart — cooldown ativo"
            return
        fi
    fi

    log_alert "FULL-STACK RESTART — ${CB_FULLSTACK_THRESHOLD}+ circuits abertos"

    if type alert_send &>/dev/null; then
        alert_send CRITICAL "auto_recovery" "Full-stack restart iniciado — multiplos servicos em falha"
    fi

    # Parar todos na ordem reversa
    local i
    for (( i=${#ORDERED_SERVICES[@]}-1; i>=0; i-- )); do
        local svc="${ORDERED_SERVICES[$i]}"
        if systemctl is-enabled "$svc" &>/dev/null; then
            systemctl stop "$svc" 2>/dev/null || true
        fi
    done

    sleep 3

    # Reiniciar todos na ordem correta
    for svc in "${ORDERED_SERVICES[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            systemctl reset-failed "$svc" 2>/dev/null || true
            systemctl start "$svc" 2>/dev/null || true
            sleep "${WAIT_AFTER[$svc]:-2}"
        fi
    done

    # Limpar todos os circuit breakers
    rm -f "${RUN_DIR}"/*.restart_count
    rm -f "${RUN_DIR}"/*.circuit_open

    echo "$now" > "$cooldown_file"
    log "full-stack restart concluido"
}

# =============================================================================
# Main
# =============================================================================

# Validar que placeholders foram substituidos pelo setup
if grep -qE '<[A-Z_]+>' "$0" 2>/dev/null; then
    echo "ERRO: placeholders nao substituidos em $0. Execute setup-loracore.sh primeiro." >&2
    exit 1
fi

# Carregar alertas externos (se disponivel)
# shellcheck source=/dev/null
source "/home/<USER>/alert_dispatch.sh" 2>/dev/null || true

# Verificar e recuperar servicos
check_and_recover

# Se muitos circuits abertos, tentar full-stack restart como ultimo recurso
open_count=$(cb_count_open)
if [ "$open_count" -ge "$CB_FULLSTACK_THRESHOLD" ]; then
    fullstack_restart
fi
