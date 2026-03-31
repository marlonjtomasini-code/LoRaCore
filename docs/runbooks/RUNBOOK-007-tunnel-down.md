# RUNBOOK-007: Tunnel de Acesso Remoto Inativo

**Trigger:** Operador nao consegue conectar via tunnel reverso (`ssh -p RELAY_PORT user@relay` falha).

**Tempo estimado:** 5-15 minutos

---

## 1. Deteccao

Sinais de que o tunnel esta inativo:

```bash
# Do lado do operador (fora da LAN)
$ ssh -p 20022 usuario@relay.example.com
# Se "Connection refused" ou timeout, tunnel esta inativo

# Se tiver acesso ao relay server
$ ss -tlnp | grep 20022
# Se nao aparece nada, o tunnel nao esta estabelecido
```

---

## 2. Triagem (requer acesso ao RPi5 via LAN ou console)

### 2.1. Verificar status do servico

```bash
$ systemctl status loracore-tunnel.service
$ journalctl -u loracore-tunnel.service -n 30 --no-pager
```

### 2.2. Causas comuns

| Sintoma no journal | Causa | Solucao |
|-------------------|-------|---------|
| `Connection refused` | Relay SSH nao esta rodando | Verificar relay server |
| `Permission denied (publickey)` | Chave nao instalada no relay | Reinstalar chave publica |
| `Warning: remote port forwarding failed for listen port` | Porta ja em uso (conexao anterior stale) | Matar sessao stale no relay |
| `Network is unreachable` | RPi5 sem internet | Verificar rede primeiro |
| `start request repeated too quickly` | StartLimitBurst atingido | `systemctl reset-failed` |

---

## 3. Recovery

### Servico em failed state (StartLimitBurst)

```bash
$ sudo systemctl reset-failed loracore-tunnel.service
$ sudo systemctl restart loracore-tunnel.service
```

### Porta stale no relay

No relay server:
```bash
# Encontrar e matar sessoes SSH stale
$ ps aux | grep "sshd.*tunnel-loracore"
$ kill <PID>
```

### Chave SSH rejeitada

```bash
# Verificar chave
$ ssh -i ~/.ssh/loracore_tunnel_key -p 22 tunnel-loracore@relay.example.com echo test

# Se falhar, reinstalar chave publica no relay
$ cat ~/.ssh/loracore_tunnel_key.pub
# Copiar e adicionar ao authorized_keys do relay
```

### RPi5 sem internet

Seguir primeiro: network_recovery.sh ou troubleshooting de rede.

### Testar tunnel manualmente

```bash
$ autossh -M 0 -N -v \
    -o "ServerAliveInterval 30" \
    -o "ServerAliveCountMax 3" \
    -R 20022:localhost:22 \
    tunnel-loracore@relay.example.com \
    -i ~/.ssh/loracore_tunnel_key
# -v mostra debug de conexao
```

---

## 4. Pos-incidente

```bash
# Verificar que tunnel reconectou
$ systemctl status loracore-tunnel.service
# Deve mostrar "active (running)"

# Do lado do operador, testar SSH via tunnel
$ ssh -p 20022 usuario@relay.example.com hostname
# Deve retornar o hostname do RPi5

# Verificar que auto-reconnect funciona
$ journalctl -u loracore-tunnel.service --since "10 minutes ago" --no-pager
```
