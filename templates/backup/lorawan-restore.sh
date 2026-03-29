#!/usr/bin/env bash
# Template LoRaCore — Restauracao guiada da infraestrutura LoRaWAN
# Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 17.6
# Destino: /home/<USER>/lorawan-restore.sh
#
# Substituir:
#   <USER>             — usuario do sistema (ex: marlon)
#   <BACKUP_DIR>       — diretorio de backup local (ex: /home/marlon/backups)
#   <RCLONE_REMOTE>    — nome do remote rclone (ex: gdrive)
#   <REMOTE_DIR>       — pasta no Google Drive (ex: LoRaCore-backups)
#   <PG_DATABASE>      — nome do banco PostgreSQL (ex: chirpstack)
#
# Execucao: sudo bash /home/<USER>/lorawan-restore.sh --date YYYYMMDD
# Opcoes:
#   --date YYYYMMDD    Data do backup a restaurar (obrigatorio)
#   --from-remote      Baixar artefatos do Google Drive antes de restaurar
#   --dry-run          Mostrar o que seria feito sem executar

set -u

# =============================================================================
# Configuracao
# =============================================================================

BACKUP_DIR="<BACKUP_DIR>"
RCLONE_REMOTE="<RCLONE_REMOTE>"
REMOTE_DIR="<REMOTE_DIR>"
PG_DATABASE="<PG_DATABASE>"

RESTORE_DATE=""
FROM_REMOTE=false
DRY_RUN=false

# Servicos que serao parados durante o restore
SERVICES_STOP=(chirpstack chirpstack-mqtt-forwarder lora-pkt-fwd)
# Todos os servicos da stack (ordem de restart)
SERVICES_ALL=(postgresql redis-server mosquitto chirpstack chirpstack-mqtt-forwarder lora-pkt-fwd)

# =============================================================================
# Funcoes
# =============================================================================

msg() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
msg_warn() { echo -e "\033[1;33m[AVISO]\033[0m $1"; }
msg_error() { echo -e "\033[1;31m[ERRO]\033[0m $1"; }
msg_ok() { echo -e "\033[1;32m[OK]\033[0m $1"; }

confirm() {
    local prompt="$1"
    if $DRY_RUN; then
        msg "[DRY-RUN] Pulando: ${prompt}"
        return 1
    fi
    read -r -p "${prompt} [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

usage() {
    echo "Uso: sudo bash $0 --date YYYYMMDD [--from-remote] [--dry-run]"
    echo ""
    echo "Opcoes:"
    echo "  --date YYYYMMDD    Data do backup a restaurar (obrigatorio)"
    echo "  --from-remote      Baixar artefatos do Google Drive antes"
    echo "  --dry-run          Mostrar o que seria feito sem executar"
    exit 1
}

# =============================================================================
# Parse de argumentos
# =============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date)
            RESTORE_DATE="$2"
            shift 2
            ;;
        --from-remote)
            FROM_REMOTE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            msg_error "Argumento desconhecido: $1"
            usage
            ;;
    esac
done

if [ -z "$RESTORE_DATE" ]; then
    msg_error "Parametro --date e obrigatorio"
    usage
fi

# Validar formato da data
if ! [[ "$RESTORE_DATE" =~ ^[0-9]{8}$ ]]; then
    msg_error "Formato de data invalido: ${RESTORE_DATE} (esperado: YYYYMMDD)"
    exit 1
fi

# Verificar que esta rodando como root
if [ "$(id -u)" -ne 0 ]; then
    msg_error "Este script deve ser executado como root (sudo)"
    exit 1
fi

# Artefatos esperados
PG_DUMP="${BACKUP_DIR}/chirpstack_${RESTORE_DATE}.dump"
REDIS_SNAP="${BACKUP_DIR}/redis_${RESTORE_DATE}.rdb"
CONFIG_TAR="${BACKUP_DIR}/configs_${RESTORE_DATE}.tar.gz"

echo ""
echo "============================================="
echo "  LoRaCore — Restauracao de Backup"
echo "============================================="
echo ""
msg "Data do backup: ${RESTORE_DATE}"
msg "Diretorio: ${BACKUP_DIR}"
msg "Banco: ${PG_DATABASE}"
if $FROM_REMOTE; then msg "Origem: Google Drive (${RCLONE_REMOTE}:${REMOTE_DIR})"; fi
if $DRY_RUN; then msg_warn "Modo DRY-RUN ativo — nenhuma alteracao sera feita"; fi
echo ""

# =============================================================================
# FASE 1: Obter artefatos
# =============================================================================

if $FROM_REMOTE; then
    msg "Fase 1: Baixando artefatos do Google Drive..."

    if $DRY_RUN; then
        msg "[DRY-RUN] rclone copy ${RCLONE_REMOTE}:${REMOTE_DIR} ${BACKUP_DIR}"
    else
        mkdir -p "$BACKUP_DIR"
        rclone copy "${RCLONE_REMOTE}:${REMOTE_DIR}" "$BACKUP_DIR" \
            --include "chirpstack_${RESTORE_DATE}.dump" \
            --include "redis_${RESTORE_DATE}.rdb" \
            --include "configs_${RESTORE_DATE}.tar.gz" \
            --retries 3 \
            --progress

        if [ $? -ne 0 ]; then
            msg_error "Falha ao baixar artefatos do Google Drive"
            exit 1
        fi
        msg_ok "Download concluido"
    fi
fi

# =============================================================================
# FASE 2: Verificar artefatos
# =============================================================================

msg "Fase 2: Verificando artefatos..."

MISSING=0
for artifact in "$PG_DUMP" "$REDIS_SNAP" "$CONFIG_TAR"; do
    if [ -f "$artifact" ]; then
        SIZE=$(du -h "$artifact" | cut -f1)
        msg_ok "$(basename "$artifact") (${SIZE})"
    else
        msg_error "Nao encontrado: ${artifact}"
        MISSING=$((MISSING + 1))
    fi
done

if [ "$MISSING" -gt 0 ]; then
    msg_error "${MISSING} artefato(s) ausente(s). Abortando."
    if ! $FROM_REMOTE; then
        msg_warn "Tente com --from-remote para baixar do Google Drive"
    fi
    exit 1
fi

echo ""
msg_warn "ATENCAO: A restauracao vai SUBSTITUIR o estado atual da infraestrutura."
msg_warn "Servicos que serao parados: ${SERVICES_STOP[*]}"
echo ""

if ! confirm "Continuar com a restauracao de ${RESTORE_DATE}?"; then
    msg "Restauracao cancelada."
    exit 0
fi

# =============================================================================
# FASE 3: Parar servicos
# =============================================================================

echo ""
msg "Fase 3: Parando servicos..."

if ! $DRY_RUN; then
    for svc in "${SERVICES_STOP[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc"
            msg_ok "Parado: ${svc}"
        else
            msg_warn "Ja parado: ${svc}"
        fi
    done
else
    msg "[DRY-RUN] systemctl stop ${SERVICES_STOP[*]}"
fi

# =============================================================================
# FASE 4: Restaurar PostgreSQL
# =============================================================================

echo ""
if confirm "Restaurar banco PostgreSQL '${PG_DATABASE}'?"; then
    msg "Fase 4: Restaurando PostgreSQL..."

    if sudo -u postgres pg_restore -d "$PG_DATABASE" -c --if-exists "$PG_DUMP" 2>&1; then
        msg_ok "PostgreSQL restaurado"

        # Verificar integridade basica
        DEVICE_COUNT=$(sudo -u postgres psql -d "$PG_DATABASE" -t -c "SELECT count(*) FROM device" 2>/dev/null | tr -d ' ')
        if [ -n "$DEVICE_COUNT" ]; then
            msg_ok "Verificacao: ${DEVICE_COUNT} device(s) no banco"
        fi
    else
        msg_error "Falha na restauracao do PostgreSQL (alguns erros sao normais em pg_restore -c)"
    fi
else
    msg_warn "Fase 4: PostgreSQL pulado"
fi

# =============================================================================
# FASE 5: Restaurar Redis
# =============================================================================

echo ""
if confirm "Restaurar snapshot do Redis?"; then
    msg "Fase 5: Restaurando Redis..."

    systemctl stop redis-server 2>/dev/null
    cp "$REDIS_SNAP" /var/lib/redis/dump.rdb
    chown redis:redis /var/lib/redis/dump.rdb
    chmod 660 /var/lib/redis/dump.rdb
    systemctl start redis-server

    if systemctl is-active --quiet redis-server; then
        msg_ok "Redis restaurado e rodando"
    else
        msg_error "Redis falhou ao iniciar apos restore"
    fi
else
    msg_warn "Fase 5: Redis pulado"
fi

# =============================================================================
# FASE 6: Restaurar configuracoes
# =============================================================================

echo ""
msg "Fase 6: Conteudo do arquivo de configs:"
tar tzf "$CONFIG_TAR" 2>/dev/null | head -30
echo "..."
echo ""

if confirm "Restaurar arquivos de configuracao (sobrescrever)?"; then
    msg "Fase 6: Restaurando configuracoes..."

    tar xzf "$CONFIG_TAR" -C / --overwrite 2>&1
    systemctl daemon-reload

    msg_ok "Configuracoes restauradas e daemon-reload executado"
else
    msg_warn "Fase 6: Configs pulado"
fi

# =============================================================================
# FASE 7: Reiniciar servicos
# =============================================================================

echo ""
msg "Fase 7: Reiniciando todos os servicos da stack..."

if ! $DRY_RUN; then
    for svc in "${SERVICES_ALL[@]}"; do
        systemctl restart "$svc" 2>/dev/null
        sleep 1
    done

    # Aguardar estabilizacao
    sleep 3

    msg "Status dos servicos:"
    for svc in "${SERVICES_ALL[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            msg_ok "${svc}: ativo"
        else
            msg_error "${svc}: INATIVO"
        fi
    done
else
    msg "[DRY-RUN] systemctl restart ${SERVICES_ALL[*]}"
fi

# =============================================================================
# FASE 8: Verificacao pos-restore
# =============================================================================

echo ""
msg "Fase 8: Verificacao pos-restore..."

if ! $DRY_RUN; then
    # Verificar ChirpStack API
    sleep 2
    if curl -sf http://localhost:8080 > /dev/null 2>&1; then
        msg_ok "ChirpStack Web UI respondendo"
    else
        msg_warn "ChirpStack Web UI nao respondeu (pode levar mais tempo para iniciar)"
    fi

    # Verificar MQTT
    if systemctl is-active --quiet mosquitto 2>/dev/null; then
        msg_ok "Mosquitto MQTT ativo"
    fi

    # Verificar PostgreSQL
    if sudo -u postgres psql -d "$PG_DATABASE" -c "SELECT 1" > /dev/null 2>&1; then
        msg_ok "PostgreSQL acessivel"
    fi
fi

echo ""
echo "============================================="
msg_ok "Restauracao concluida!"
echo "============================================="
echo ""
msg "Proximos passos:"
msg "  1. Verificar ChirpStack Web UI: http://localhost:8080"
msg "  2. Verificar devices: curl http://localhost:8090/api/devices?limit=10"
msg "  3. Monitorar logs: journalctl -u chirpstack -f"
msg "  4. Verificar uplinks: mosquitto_sub -h localhost -t 'application/+/device/+/event/up' -v"
