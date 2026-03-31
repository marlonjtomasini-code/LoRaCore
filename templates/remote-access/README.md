# Templates de Acesso Remoto

Reverse SSH tunnel via autossh para acessar o RPi5 quando instalado em local de dificil acesso.

## Como Funciona

O RPi5 inicia uma conexao SSH para um servidor relay e estabelece um port-forwarding reverso. O operador conecta no relay, que encaminha a conexao de volta para o RPi5.

```
Operador → ssh relay:RELAY_PORT → tunnel → RPi5:22
               (RPi5 iniciou este tunnel)
```

Funciona atras de NAT, firewalls e IPs dinamicos — o RPi5 e o iniciador da conexao.

## Pre-requisitos

- Servidor relay com SSH acessivel pela internet (VPS, home server, etc.)
- autossh no RPi5 (`sudo apt install autossh`)

## Arquivos

| Arquivo | Funcao |
|---------|--------|
| `loracore-tunnel.service` | Unidade systemd para autossh com auto-reconnect |
| `setup-tunnel.sh` | Script interativo de setup (gera chave, testa, habilita) |

## Placeholders

| Placeholder | Descricao | Exemplo |
|-------------|-----------|---------|
| `<USER>` | Usuario do RPi5 | `seuusuario` |
| `<RELAY_HOST>` | Hostname/IP do relay | `relay.example.com` |
| `<RELAY_SSH_PORT>` | Porta SSH do relay | `22` |
| `<RELAY_PORT>` | Porta reversa (SSH do RPi5 exposto aqui no relay) | `20022` |
| `<RELAY_USER>` | Usuario no relay | `tunnel-loracore` |

## Deploy

### 1. Configurar o relay server

No servidor relay:

```bash
# Criar usuario dedicado para o tunnel
sudo useradd -m -s /bin/bash tunnel-loracore
sudo mkdir -p /home/tunnel-loracore/.ssh
sudo chmod 700 /home/tunnel-loracore/.ssh
```

### 2. Instalar o service no RPi5

```bash
# Copiar e substituir placeholders
sudo cp loracore-tunnel.service /etc/systemd/system/
sudo sed -i 's|<USER>|seuusuario|g; s|<RELAY_HOST>|relay.example.com|g; s|<RELAY_SSH_PORT>|22|g; s|<RELAY_PORT>|20022|g; s|<RELAY_USER>|tunnel-loracore|g' /etc/systemd/system/loracore-tunnel.service
```

### 3. Executar setup interativo

```bash
bash setup-tunnel.sh
```

O script:
1. Instala autossh (se ausente)
2. Gera chave SSH dedicada (ed25519)
3. Exibe chave publica para instalar no relay
4. Testa conectividade
5. Habilita e inicia o servico

### 4. Instalar chave no relay

No relay, adicionar a chave publica com restricoes:

```bash
# No arquivo /home/tunnel-loracore/.ssh/authorized_keys:
restrict,port-forwarding,command="/bin/false" ssh-ed25519 AAAA... loracore-tunnel@rpi5
```

Restricoes de seguranca:
- `restrict`: desabilita tudo por padrao
- `port-forwarding`: permite apenas port-forwarding
- `command="/bin/false"`: impede execucao de comandos no relay

### 5. Acessar remotamente

```bash
ssh -p 20022 seuusuario@relay.example.com
```

## Seguranca

- Chave SSH dedicada (`loracore_tunnel_key`) — revogavel independentemente
- Usuario do relay restrito a port-forwarding (sem shell, sem execucao)
- Porta reversa bind em localhost por padrao no relay
- Tunnel roda como usuario (nao root)
- autossh usa ~3-5MB RAM e CPU negligivel

## Troubleshooting

```bash
# Status do tunnel
systemctl status loracore-tunnel.service

# Logs
journalctl -u loracore-tunnel.service -f

# Testar manualmente
autossh -M 0 -N -v -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
    -R 20022:localhost:22 tunnel-loracore@relay.example.com \
    -i ~/.ssh/loracore_tunnel_key
```
