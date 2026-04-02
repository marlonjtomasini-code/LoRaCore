#!/usr/bin/env bash
# Template LoRaCore — Script de automacao de deploy
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 19
# Destino: executar no RPi5 como root
#
# Prerequisitos:
#   - Raspberry Pi 5 com Ubuntu 24.04 ou Raspberry Pi OS (Bookworm)
#   - Conectividade de rede (para instalar pacotes — apos deploy, funciona offline)
#   - Concentrador LoRa (RAK2287) conectado via SPI/USB
#   - Clone do LoRaCore disponivel no host
#
# Uso:
#   sudo bash setup-loracore.sh --loracore-dir /path/to/LoRaCore
#
# Opcoes:
#   --loracore-dir DIR   Path do clone do LoRaCore (obrigatorio)
#   --non-interactive    Usar defaults sem prompts (para automacao)
#   --skip-pktfwd        Pular compilacao do packet forwarder
#   --dry-run            Mostrar o que seria feito sem executar

set -euo pipefail

# =============================================================================
# Variaveis globais
# =============================================================================

LORACORE_DIR=""
INTERACTIVE=true
SKIP_PKTFWD=false
DRY_RUN=false

# Configuracoes coletadas via prompts
CFG_USER=""
CFG_GATEWAY_ID=""
CFG_SECRET=""
CFG_PG_PASSWORD="chirpstack"
CFG_PKT_FWD_PATH=""
CFG_BACKUP_DIR=""

# =============================================================================
# Funcoes de UI
# =============================================================================

msg()      { echo -e "\033[1;34m[INFO]\033[0m $1"; }
msg_ok()   { echo -e "\033[1;32m[OK]\033[0m $1"; }
msg_warn() { echo -e "\033[1;33m[AVISO]\033[0m $1"; }
msg_err()  { echo -e "\033[1;31m[ERRO]\033[0m $1"; }
msg_step() { echo -e "\n\033[1;36m=== $1 ===\033[0m"; }

prompt() {
    local var_name="$1" prompt_text="$2" default="$3"
    if $INTERACTIVE; then
        read -r -p "${prompt_text} [${default}]: " value
        printf -v "$var_name" '%s' "${value:-$default}"
    else
        printf -v "$var_name" '%s' "$default"
    fi
}

# Escapar valor para uso seguro como replacement em sed
sed_escape_replacement() {
    printf '%s' "$1" | sed -e 's/[&\\/|]/\\&/g'
}

run() {
    if $DRY_RUN; then
        msg "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# =============================================================================
# Parse de argumentos
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --loracore-dir) LORACORE_DIR="$2"; shift 2 ;;
        --non-interactive) INTERACTIVE=false; shift ;;
        --skip-pktfwd) SKIP_PKTFWD=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) msg_err "Argumento desconhecido: $1"; exit 1 ;;
    esac
done

if [ -z "$LORACORE_DIR" ]; then
    msg_err "Uso: sudo bash setup-loracore.sh --loracore-dir /path/to/LoRaCore"
    exit 1
fi

if [ ! -d "$LORACORE_DIR/templates" ]; then
    msg_err "Diretorio LoRaCore invalido: $LORACORE_DIR (templates/ nao encontrado)"
    exit 1
fi

if [ "$(id -u)" -ne 0 ] && ! $DRY_RUN; then
    msg_err "Este script deve ser executado como root (sudo)"
    exit 1
fi

# =============================================================================
# Fase 0: Coletar configuracoes
# =============================================================================

msg_step "Fase 0: Configuracao"

prompt CFG_USER "Usuario do sistema" "$(logname 2>/dev/null || echo 'loracore')"
prompt CFG_GATEWAY_ID "Gateway ID (16 hex, ex: 2CCF67FFFE576A1D)" "0000000000000000"
prompt CFG_PG_PASSWORD "Senha do PostgreSQL para ChirpStack" "chirpstack"

if $INTERACTIVE; then
    read -r -p "Secret do ChirpStack (Enter para auto-gerar): " CFG_SECRET
    if [ -z "$CFG_SECRET" ]; then
        CFG_SECRET=$(openssl rand -base64 32)
        msg "Secret auto-gerado (salvo na configuracao)"
    fi
else
    CFG_SECRET=$(openssl rand -base64 32)
fi

CFG_PKT_FWD_PATH="/home/${CFG_USER}/packet_forwarder"
CFG_BACKUP_DIR="/home/${CFG_USER}/backups"

prompt CFG_PKT_FWD_PATH "Diretorio do packet forwarder" "$CFG_PKT_FWD_PATH"
prompt CFG_BACKUP_DIR "Diretorio de backups" "$CFG_BACKUP_DIR"

msg ""
msg "Resumo da configuracao:"
msg "  Usuario:        $CFG_USER"
msg "  Gateway ID:     $CFG_GATEWAY_ID"
msg "  PG Password:    $CFG_PG_PASSWORD"
msg "  Secret:         ********"
msg "  Pkt Fwd Path:   $CFG_PKT_FWD_PATH"
msg "  Backup Dir:     $CFG_BACKUP_DIR"
msg "  LoRaCore Dir:   $LORACORE_DIR"

if $INTERACTIVE && ! $DRY_RUN; then
    read -r -p "Prosseguir? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN] ]]; then
        msg "Cancelado pelo usuario."
        exit 0
    fi
fi

# =============================================================================
# Fase 1: Swap
# =============================================================================

msg_step "Fase 1: Configurar swap (2GB)"

if swapon --show | grep -q "/swapfile"; then
    msg_ok "Swap ja configurado"
else
    run fallocate -l 2G /swapfile
    run chmod 600 /swapfile
    run mkswap /swapfile
    run swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    msg_ok "Swap 2GB ativado"
fi

# =============================================================================
# Fase 2: Pacotes base
# =============================================================================

msg_step "Fase 2: Instalar pacotes base"

if dpkg -l postgresql redis-server mosquitto &>/dev/null; then
    msg_ok "Pacotes base ja instalados"
else
    run apt-get update -qq
    run apt-get install -y -qq postgresql redis-server mosquitto mosquitto-clients \
        git build-essential apt-transport-https curl
    msg_ok "Pacotes base instalados"
fi

# =============================================================================
# Fase 3: PostgreSQL
# =============================================================================

msg_step "Fase 3: Configurar PostgreSQL"

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='chirpstack'" 2>/dev/null | grep -q 1; then
    msg_ok "Role chirpstack ja existe"
else
    escaped_pw="${CFG_PG_PASSWORD//\'/\'\'}"
    run sudo -u postgres psql -c "CREATE ROLE chirpstack WITH LOGIN PASSWORD '${escaped_pw}';"
    msg_ok "Role chirpstack criada"
fi

if sudo -u postgres psql -lqt 2>/dev/null | cut -d\| -f1 | grep -qw chirpstack; then
    msg_ok "Database chirpstack ja existe"
else
    run sudo -u postgres psql -c "CREATE DATABASE chirpstack WITH OWNER chirpstack;"
    run sudo -u postgres psql -d chirpstack -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
    msg_ok "Database chirpstack criada"
fi

# =============================================================================
# Fase 4: Redis
# =============================================================================

msg_step "Fase 4: Configurar Redis"

run systemctl enable redis-server
run systemctl restart redis-server
msg_ok "Redis ativo"

# =============================================================================
# Fase 5: Mosquitto
# =============================================================================

msg_step "Fase 5: Configurar Mosquitto"

if [ -f /etc/mosquitto/conf.d/production.conf ]; then
    msg_ok "Mosquitto ja configurado"
else
    run cp "${LORACORE_DIR}/templates/mosquitto/production.conf" /etc/mosquitto/conf.d/
    msg_ok "Mosquitto configurado"
fi

run systemctl enable mosquitto
run systemctl restart mosquitto
msg_ok "Mosquitto ativo"

# =============================================================================
# Fase 6: ChirpStack (repositorio + pacotes)
# =============================================================================

msg_step "Fase 6: Instalar ChirpStack"

if dpkg -l chirpstack &>/dev/null; then
    msg_ok "ChirpStack ja instalado"
else
    run curl -fsSL https://artifacts.chirpstack.io/packages/chirpstack.key -o /tmp/chirpstack.key
    run gpg --dearmor --yes -o /usr/share/keyrings/chirpstack-archive-keyring.gpg /tmp/chirpstack.key
    echo "deb [signed-by=/usr/share/keyrings/chirpstack-archive-keyring.gpg] https://artifacts.chirpstack.io/packages/4.x/deb stable main" | tee /etc/apt/sources.list.d/chirpstack.list
    run apt-get update -qq
    run apt-get install -y -qq chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api
    msg_ok "ChirpStack instalado"
fi

# =============================================================================
# Fase 7: Copiar templates de configuracao
# =============================================================================

msg_step "Fase 7: Aplicar templates de configuracao"

TEMPLATES_DIR="${LORACORE_DIR}/templates"

# ChirpStack config
if [ -f "${TEMPLATES_DIR}/chirpstack/chirpstack.toml" ]; then
    cp "${TEMPLATES_DIR}/chirpstack/chirpstack.toml" /etc/chirpstack/chirpstack.toml
    sed -i "s|<SECRET>|$(sed_escape_replacement "$CFG_SECRET")|g" /etc/chirpstack/chirpstack.toml
    sed -i "s|<PG_PASSWORD>|$(sed_escape_replacement "$CFG_PG_PASSWORD")|g" /etc/chirpstack/chirpstack.toml
    msg_ok "chirpstack.toml aplicado"
fi

# Region config — customizar o arquivo default do pacote (nao sobrescrever)
# O pacote chirpstack instala region_us915_0.toml com ~3000 linhas.
# Sobrescrever com arquivo parcial causa erro "duplicate key".
if [ -f /etc/chirpstack/region_us915_0.toml ]; then
    sed -i '/regions.gateway.backend.mqtt/,/qos/{s/qos = 0/qos = 1/}' /etc/chirpstack/region_us915_0.toml
    msg_ok "region_us915_0.toml customizado (qos=1)"
else
    msg_warn "region_us915_0.toml nao encontrado — instalar pacote chirpstack primeiro"
fi

# MQTT Forwarder config
if [ -f "${TEMPLATES_DIR}/mqtt-forwarder/chirpstack-mqtt-forwarder.toml" ]; then
    cp "${TEMPLATES_DIR}/mqtt-forwarder/chirpstack-mqtt-forwarder.toml" /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
    msg_ok "chirpstack-mqtt-forwarder.toml aplicado"
fi

# Substituir placeholders comuns em todos os configs
for conf in /etc/chirpstack/chirpstack.toml /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml; do
    if [ -f "$conf" ]; then
        sed -i "s|<GATEWAY_ID>|${CFG_GATEWAY_ID}|g" "$conf"
        sed -i "s|<USER>|${CFG_USER}|g" "$conf"
    fi
done

msg_ok "Placeholders substituidos"

# =============================================================================
# Fase 8: Systemd overrides e tuning
# =============================================================================

msg_step "Fase 8: Aplicar systemd overrides e tuning"

# Systemd overrides
for override in chirpstack-priority.conf mosquitto-priority.conf chirpstack-mqtt-fwd-priority.conf postgresql-io-priority.conf; do
    src="${TEMPLATES_DIR}/systemd/${override}"
    if [ -f "$src" ]; then
        # Determinar servico alvo pelo nome do override
        case "$override" in
            chirpstack-priority.conf) dest_dir="/etc/systemd/system/chirpstack.service.d" ;;
            mosquitto-priority.conf) dest_dir="/etc/systemd/system/mosquitto.service.d" ;;
            chirpstack-mqtt-fwd-priority.conf) dest_dir="/etc/systemd/system/chirpstack-mqtt-forwarder.service.d" ;;
            postgresql-io-priority.conf) dest_dir="/etc/systemd/system/postgresql@.service.d" ;;
        esac
        run mkdir -p "$dest_dir"
        run cp "$src" "${dest_dir}/${override}"
    fi
done

# Sysctl tuning
if [ -f "${TEMPLATES_DIR}/sysctl/90-lorawan.conf" ]; then
    run cp "${TEMPLATES_DIR}/sysctl/90-lorawan.conf" /etc/sysctl.d/
    run sysctl --system -q 2>/dev/null || true
    msg_ok "Sysctl tuning aplicado"
fi

# Udev rules
if [ -f "${TEMPLATES_DIR}/udev/60-scheduler.rules" ]; then
    run cp "${TEMPLATES_DIR}/udev/60-scheduler.rules" /etc/udev/rules.d/
    run udevadm control --reload-rules 2>/dev/null || true
    msg_ok "Udev rules aplicadas"
fi

# Operacao offline
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/local.conf <<'DNSEOF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=
DNSEOF

systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

run systemctl daemon-reload

# Restart throttling para servicos LoRaWAN
if [ -f "${TEMPLATES_DIR}/systemd/lorawan-restart-limits.conf" ]; then
    for svc_dir in chirpstack.service.d mosquitto.service.d chirpstack-mqtt-forwarder.service.d lora-pkt-fwd.service.d; do
        run mkdir -p "/etc/systemd/system/${svc_dir}"
        run cp "${TEMPLATES_DIR}/systemd/lorawan-restart-limits.conf" "/etc/systemd/system/${svc_dir}/"
    done
    msg_ok "Restart throttling aplicado"
fi

# Hardware watchdog
if [ -f "${TEMPLATES_DIR}/systemd/watchdog-hardware.conf" ]; then
    run mkdir -p /etc/systemd/system.conf.d
    run cp "${TEMPLATES_DIR}/systemd/watchdog-hardware.conf" /etc/systemd/system.conf.d/
    msg_ok "Hardware watchdog configurado"
fi

if [ -f "${TEMPLATES_DIR}/systemd/bcm2835-wdt.conf" ]; then
    run cp "${TEMPLATES_DIR}/systemd/bcm2835-wdt.conf" /etc/modules-load.d/
    msg_ok "Modulo bcm2835_wdt habilitado no boot"
fi

run systemctl daemon-reload
msg_ok "Systemd overrides e offline mode aplicados"

# =============================================================================
# Fase 9: Packet Forwarder (opcional)
# =============================================================================

msg_step "Fase 9: Packet Forwarder"

if $SKIP_PKTFWD; then
    msg_warn "Compilacao do packet forwarder pulada (--skip-pktfwd)"
elif [ -f "${CFG_PKT_FWD_PATH}/lora_pkt_fwd" ]; then
    msg_ok "Packet forwarder ja compilado em ${CFG_PKT_FWD_PATH}"
else
    msg "Compilando sx1302_hal (pode demorar alguns minutos)..."
    WORK_DIR=$(mktemp -d)
    run git clone --depth 1 https://github.com/Lora-net/sx1302_hal.git "$WORK_DIR/sx1302_hal"
    (cd "$WORK_DIR/sx1302_hal" && run make all)
    run mkdir -p "$CFG_PKT_FWD_PATH"
    run cp "$WORK_DIR/sx1302_hal/packet_forwarder/lora_pkt_fwd" "$CFG_PKT_FWD_PATH/"
    run cp "$WORK_DIR/sx1302_hal/mcu_bin/"* "$CFG_PKT_FWD_PATH/"
    run chown -R "${CFG_USER}:${CFG_USER}" "$CFG_PKT_FWD_PATH"
    rm -rf "$WORK_DIR"
    msg_ok "Packet forwarder compilado"
fi

# Copiar global_conf.json
if [ -f "${TEMPLATES_DIR}/packet-forwarder/global_conf.json" ] && [ -d "$CFG_PKT_FWD_PATH" ]; then
    run cp "${TEMPLATES_DIR}/packet-forwarder/global_conf.json" "${CFG_PKT_FWD_PATH}/"
    sed -i "s|<GATEWAY_ID>|${CFG_GATEWAY_ID}|g" "${CFG_PKT_FWD_PATH}/global_conf.json"
    msg_ok "global_conf.json aplicado"
fi

# Criar servico systemd do packet forwarder
if [ -f "${TEMPLATES_DIR}/systemd/lora-pkt-fwd.service" ]; then
    run cp "${TEMPLATES_DIR}/systemd/lora-pkt-fwd.service" /etc/systemd/system/
    sed -i "s|<USER>|$(sed_escape_replacement "$CFG_USER")|g; s|<PKT_FWD_PATH>|$(sed_escape_replacement "$CFG_PKT_FWD_PATH")|g" /etc/systemd/system/lora-pkt-fwd.service
    run systemctl daemon-reload
    run systemctl enable lora-pkt-fwd
    msg_ok "Servico lora-pkt-fwd configurado"
fi

# =============================================================================
# Fase 10: Ativar servicos ChirpStack
# =============================================================================

msg_step "Fase 10: Ativar servicos"

for svc in chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api; do
    run systemctl enable "$svc"
    run systemctl restart "$svc"
done
msg_ok "Servicos ChirpStack ativos"

# =============================================================================
# Fase 11: Monitoramento (opcional)
# =============================================================================

msg_step "Fase 11: Monitoramento (opcional)"

SETUP_MONITORING=true
if $INTERACTIVE; then
    read -r -p "Configurar scripts de monitoramento? [Y/n]: " mon_confirm
    if [[ "$mon_confirm" =~ ^[nN] ]]; then
        SETUP_MONITORING=false
    fi
fi

if $SETUP_MONITORING && [ -d "${TEMPLATES_DIR}/monitoring" ]; then
    USER_HOME="/home/${CFG_USER}"
    for script in health_check.sh watchdog_concentrator.sh device_monitor.sh daily_report.sh auto_recovery.sh disk_cleanup.sh db_maintenance.sh network_recovery.sh; do
        if [ -f "${TEMPLATES_DIR}/monitoring/${script}" ]; then
            run cp "${TEMPLATES_DIR}/monitoring/${script}" "${USER_HOME}/"
            run chmod +x "${USER_HOME}/${script}"
            sed -i "s|<USER>|${CFG_USER}|g" "${USER_HOME}/${script}"
        fi
    done

    # Logrotate
    if [ -f "${TEMPLATES_DIR}/monitoring/logrotate-lorawan.conf" ]; then
        run cp "${TEMPLATES_DIR}/monitoring/logrotate-lorawan.conf" /etc/logrotate.d/lorawan
    fi

    msg_ok "Scripts de monitoramento copiados para ${USER_HOME}/"
    msg_warn "Configure placeholders restantes (CHIRPSTACK_TOKEN, thresholds) e crontab manualmente"
    msg "  Ver: ${LORACORE_DIR}/templates/monitoring/README.md"
else
    msg "Monitoramento pulado"
fi

# =============================================================================
# Fase 12: Backup (opcional)
# =============================================================================

msg_step "Fase 12: Backup (opcional)"

SETUP_BACKUP=true
if $INTERACTIVE; then
    read -r -p "Configurar scripts de backup? [Y/n]: " bkp_confirm
    if [[ "$bkp_confirm" =~ ^[nN] ]]; then
        SETUP_BACKUP=false
    fi
fi

if $SETUP_BACKUP && [ -d "${TEMPLATES_DIR}/backup" ]; then
    USER_HOME="/home/${CFG_USER}"
    run mkdir -p "$CFG_BACKUP_DIR"
    run chown "${CFG_USER}:${CFG_USER}" "$CFG_BACKUP_DIR"

    for script in lorawan-backup.sh lorawan-restore.sh; do
        if [ -f "${TEMPLATES_DIR}/backup/${script}" ]; then
            run cp "${TEMPLATES_DIR}/backup/${script}" "${USER_HOME}/"
            run chmod +x "${USER_HOME}/${script}"
            sed -i "s|<USER>|$(sed_escape_replacement "$CFG_USER")|g; s|<BACKUP_DIR>|$(sed_escape_replacement "$CFG_BACKUP_DIR")|g; s|<PG_DATABASE>|chirpstack|g" "${USER_HOME}/${script}"
        fi
    done

    msg_ok "Scripts de backup copiados para ${USER_HOME}/"
    msg_warn "Configure rclone e crontab manualmente"
    msg "  Ver: ${LORACORE_DIR}/templates/backup/README.md"
else
    msg "Backup pulado"
fi

# =============================================================================
# Fase 14: Alertas externos (opcional)
# =============================================================================

msg_step "Fase 14: Alertas externos (opcional)"

SETUP_ALERTING=false
if $INTERACTIVE; then
    read -r -p "Configurar alertas externos (ntfy.sh)? [y/N]: " alert_confirm
    if [[ "$alert_confirm" =~ ^[yY] ]]; then
        SETUP_ALERTING=true
    fi
fi

if $SETUP_ALERTING && [ -d "${TEMPLATES_DIR}/alerting" ]; then
    USER_HOME="/home/${CFG_USER}"
    for script in alert_dispatch.sh alert_flush.sh; do
        if [ -f "${TEMPLATES_DIR}/alerting/${script}" ]; then
            run cp "${TEMPLATES_DIR}/alerting/${script}" "${USER_HOME}/"
            run chmod +x "${USER_HOME}/${script}"
            sed -i "s|<USER>|${CFG_USER}|g" "${USER_HOME}/${script}"
        fi
    done

    run mkdir -p /var/spool/lorawan-alerts
    run chown "${CFG_USER}:${CFG_USER}" /var/spool/lorawan-alerts

    msg_ok "Scripts de alerta copiados para ${USER_HOME}/"
    msg_warn "Configure placeholders restantes (NTFY_TOPIC, ALERT_HOST_NAME) manualmente"
    msg "  Ver: ${LORACORE_DIR}/templates/alerting/README.md"
else
    msg "Alertas externos pulados"
fi

# =============================================================================
# Fase 15: Acesso remoto (opcional)
# =============================================================================

msg_step "Fase 15: Acesso remoto (opcional)"

SETUP_TUNNEL=false
if $INTERACTIVE; then
    read -r -p "Configurar tunnel de acesso remoto (reverse SSH)? [y/N]: " tunnel_confirm
    if [[ "$tunnel_confirm" =~ ^[yY] ]]; then
        SETUP_TUNNEL=true
    fi
fi

if $SETUP_TUNNEL && [ -f "${TEMPLATES_DIR}/remote-access/loracore-tunnel.service" ]; then
    run cp "${TEMPLATES_DIR}/remote-access/loracore-tunnel.service" /etc/systemd/system/
    sed -i "s|<USER>|${CFG_USER}|g" /etc/systemd/system/loracore-tunnel.service
    run systemctl daemon-reload

    msg_ok "loracore-tunnel.service instalado"
    msg_warn "Configure placeholders do relay e execute setup-tunnel.sh"
    msg "  Ver: ${LORACORE_DIR}/templates/remote-access/README.md"
else
    msg "Acesso remoto pulado"
fi

# =============================================================================
# Fase 13: Health check final
# =============================================================================

msg_step "Fase 13: Health check final"

ERRORS=0
for svc in postgresql redis-server mosquitto chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        msg_ok "$svc ativo"
    else
        msg_err "$svc INATIVO"
        ERRORS=$((ERRORS + 1))
    fi
done

if systemctl is-active --quiet lora-pkt-fwd 2>/dev/null; then
    msg_ok "lora-pkt-fwd ativo"
elif $SKIP_PKTFWD; then
    msg_warn "lora-pkt-fwd nao configurado (--skip-pktfwd)"
else
    msg_warn "lora-pkt-fwd inativo (verificar concentrador USB)"
fi

# Disco e memoria
msg ""
msg "Disco: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
msg "Memoria: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
msg "Swap: $(free -h | awk '/^Swap:/ {print $3"/"$2}')"

if [ "$ERRORS" -eq 0 ]; then
    msg_step "Deploy concluido com sucesso"
    msg "ChirpStack Web UI: http://$(hostname -I | awk '{print $1}'):8080"
    msg "ChirpStack REST API: http://$(hostname -I | awk '{print $1}'):8090"
    msg ""
    msg "Proximos passos:"
    msg "  1. Acessar Web UI e criar tenant/application"
    msg "  2. Registrar gateway (ID: ${CFG_GATEWAY_ID})"
    msg "  3. Criar device profiles e registrar devices"
    msg "  4. Configurar crontab para monitoramento e backup"
    msg "  5. Consultar: ${LORACORE_DIR}/docs/LORACORE_AI_INTEGRATION_GUIDE.md"
else
    msg_err "Deploy concluido com ${ERRORS} erro(s). Verificar servicos inativos."
fi
