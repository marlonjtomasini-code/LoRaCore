#!/usr/bin/env bash
# Template LoRaCore — Setup interativo do tunnel de acesso remoto
# Fonte: Plano de auto-recuperacao para operacao remota
# Destino: executar manualmente no RPi5 apos deploy
#
# Uso: bash setup-tunnel.sh
#
# Pre-requisitos:
#   - loracore-tunnel.service ja instalado em /etc/systemd/system/
#   - Acesso SSH ao servidor relay

set -euo pipefail

# =============================================================================
# Funcoes
# =============================================================================

msg() { echo "==> $1"; }
msg_ok() { echo "  [OK] $1"; }
msg_err() { echo "  [ERRO] $1" >&2; }

# =============================================================================
# Verificacoes
# =============================================================================

msg "Verificando pre-requisitos..."

if ! command -v autossh &>/dev/null; then
    msg "autossh nao encontrado. Instalando..."
    sudo apt-get update -qq && sudo apt-get install -y -qq autossh
    msg_ok "autossh instalado"
else
    msg_ok "autossh presente"
fi

if [ ! -f /etc/systemd/system/loracore-tunnel.service ]; then
    msg_err "loracore-tunnel.service nao encontrado em /etc/systemd/system/"
    msg_err "Copie o template e substitua os placeholders antes de executar este script"
    exit 1
fi

# Extrair configuracoes do service file
RELAY_USER=$(grep -oP '(?<=\s)-R\s+\S+\s+\K\S+(?=@)' /etc/systemd/system/loracore-tunnel.service 2>/dev/null | head -1 || true)
RELAY_HOST=$(grep -oP '(?<=@)\S+' /etc/systemd/system/loracore-tunnel.service 2>/dev/null | head -1 || true)

# =============================================================================
# Gerar chave SSH dedicada
# =============================================================================

KEY_PATH="$HOME/.ssh/loracore_tunnel_key"

if [ -f "$KEY_PATH" ]; then
    msg_ok "Chave SSH ja existe: ${KEY_PATH}"
else
    msg "Gerando chave SSH dedicada para o tunnel..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "loracore-tunnel@$(hostname)"
    msg_ok "Chave gerada: ${KEY_PATH}"
fi

# =============================================================================
# Exibir chave publica
# =============================================================================

echo ""
echo "================================================================"
echo "CHAVE PUBLICA (instalar no servidor relay):"
echo "================================================================"
echo ""
cat "${KEY_PATH}.pub"
echo ""
echo "================================================================"
echo ""
echo "No servidor relay, adicione esta chave ao authorized_keys do"
echo "usuario do tunnel com restricoes de seguranca:"
echo ""
echo "  No relay:"
echo '  echo "restrict,port-forwarding,command="/bin/false" $(cat)" >> ~/.ssh/authorized_keys'
echo ""
echo "================================================================"
echo ""

# =============================================================================
# Testar conectividade
# =============================================================================

read -r -p "Chave ja instalada no relay? Testar conexao? [Y/n]: " confirm
if [[ ! "$confirm" =~ ^[nN] ]]; then
    SSH_PORT=$(grep -oP '(?<=-p\s)\d+' /etc/systemd/system/loracore-tunnel.service 2>/dev/null | head -1)
    SSH_PORT="${SSH_PORT:-22}"

    msg "Testando conexao com relay..."
    if ssh -i "$KEY_PATH" -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "${RELAY_USER}@${RELAY_HOST}" "echo tunnel-test-ok" 2>/dev/null | grep -q "tunnel-test-ok"; then
        msg_ok "Conexao com relay OK"
    else
        msg "Conexao com relay falhou (normal se command=/bin/false no authorized_keys)"
        msg "O tunnel de port-forwarding ainda pode funcionar"
    fi
fi

# =============================================================================
# Habilitar servico
# =============================================================================

read -r -p "Habilitar e iniciar o tunnel agora? [Y/n]: " enable_confirm
if [[ ! "$enable_confirm" =~ ^[nN] ]]; then
    sudo systemctl daemon-reload
    sudo systemctl enable loracore-tunnel.service
    sudo systemctl start loracore-tunnel.service

    sleep 3

    if systemctl is-active --quiet loracore-tunnel.service; then
        msg_ok "Tunnel ativo!"

        RELAY_PORT=$(grep -oP '(?<=-R\s)\d+' /etc/systemd/system/loracore-tunnel.service 2>/dev/null | head -1)
        echo ""
        msg "Para acessar o RPi5 remotamente:"
        msg "  ssh -p ${RELAY_PORT} $(whoami)@${RELAY_HOST}"
        echo ""
    else
        msg_err "Tunnel falhou ao iniciar. Verifique: journalctl -u loracore-tunnel.service"
    fi
else
    msg "Servico nao habilitado. Para habilitar manualmente:"
    msg "  sudo systemctl enable --now loracore-tunnel.service"
fi
