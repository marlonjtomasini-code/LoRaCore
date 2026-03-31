# RUNBOOK-001: Servico Systemd Inativo

**Trigger:** `health_check.sh` reporta `[ALERTA] servico <nome> INATIVO` ou observacao direta via `systemctl status`.

**Nota:** O `auto_recovery.sh` tenta recuperar servicos automaticamente a cada 2 minutos com circuit breaker. Este runbook e para quando a auto-recuperacao falhou (circuit breaker aberto) ou o operador quer investigar a causa raiz.

**Tempo estimado:** 5-10 minutos

---

## 1. Deteccao

Sinais de que um servico esta inativo:

```bash
# Via log de monitoramento
$ grep "ALERTA.*INATIVO" /var/log/lorawan-health.log | tail -5

# Via systemctl direto
$ systemctl is-active lora-pkt-fwd chirpstack-mqtt-forwarder mosquitto chirpstack chirpstack-rest-api postgresql redis-server
```

---

## 2. Triagem

Identifique qual servico caiu e por que:

```bash
# Status detalhado (mostra PID, memoria, ultimo log)
$ systemctl status <servico>

# Ultimas 50 linhas de log do servico
$ journalctl -u <servico> -n 50 --no-pager

# Verificar se foi OOM kill
$ journalctl -k | grep -i "oom\|killed process" | tail -5

# Verificar memoria disponivel
$ free -h
```

### Causas comuns por servico

| Servico | Causa provavel | Sinal no log |
|---------|---------------|--------------|
| `lora-pkt-fwd` | Crash sob carga I/O, concentrador USB desconectado | `SPI read error`, `failed to start` |
| `chirpstack` | OOM kill sob carga extrema | `signal: killed` no journal |
| `postgresql` | Disco cheio, corrupcao | `no space left`, `PANIC` |
| `redis-server` | Disco cheio (snapshot) | `Can't save in background` |
| `mosquitto` | Configuracao invalida apos editar | `Error: Invalid configuration` |
| `chirpstack-mqtt-forwarder` | Broker MQTT indisponivel | `Connection refused` |
| `chirpstack-rest-api` | ChirpStack gRPC indisponivel | `transport: Error` |

---

## 3. Recovery

### 3.1 Restart simples

Na maioria dos casos, um restart resolve:

```bash
# Restart do servico especifico
$ sudo systemctl restart <servico>

# Verificar se voltou
$ systemctl is-active <servico>
```

### 3.2 Servico com dependencia falhou

Se o servico depende de outro que tambem esta inativo, reinicie na ordem correta:

```bash
# postgresql caiu → chirpstack tambem cai
$ sudo systemctl restart postgresql
$ sleep 3
$ sudo systemctl restart chirpstack
$ sudo systemctl restart chirpstack-rest-api

# mosquitto caiu → chirpstack-mqtt-forwarder e chirpstack perdem MQTT
$ sudo systemctl restart mosquitto
$ sleep 2
$ sudo systemctl restart chirpstack
$ sudo systemctl restart chirpstack-mqtt-forwarder
```

### 3.3 OOM kill (memoria insuficiente)

Se `journalctl -k` mostra OOM kill:

```bash
# Verificar qual processo foi morto
$ journalctl -k | grep "oom\|Killed" | tail -5

# Verificar uso de memoria atual
$ free -h

# Verificar se swap esta ativo (deve estar)
$ swapon --show

# Restart do servico morto
$ sudo systemctl restart <servico>
```

Se OOM kill recorre, verificar se os limites systemd estao corretos:

```bash
$ systemctl show <servico> | grep -E "MemoryHigh|MemoryMax"
```

### 3.4 lora-pkt-fwd nao inicia (concentrador USB)

```bash
# Verificar se o concentrador USB esta visivel
$ ls /dev/spidev* 2>/dev/null || ls /dev/ttyACM* 2>/dev/null

# Se nao aparece, verificar USB
$ dmesg | tail -20

# Reset fisico: desconectar e reconectar o concentrador
# Depois:
$ sudo systemctl restart lora-pkt-fwd
```

### 3.5 Restart completo da stack

Se multiplos servicos falharam, reinicie todos na ordem:

```bash
$ sudo systemctl restart postgresql && sleep 3
$ sudo systemctl restart redis-server
$ sudo systemctl restart mosquitto && sleep 2
$ sudo systemctl restart chirpstack && sleep 3
$ sudo systemctl restart chirpstack-rest-api
$ sudo systemctl restart chirpstack-mqtt-forwarder
$ sudo systemctl restart lora-pkt-fwd
```

---

## 4. Pos-incidente

```bash
# Confirmar que todos os servicos estao ativos
$ systemctl is-active lora-pkt-fwd chirpstack-mqtt-forwarder mosquitto chirpstack chirpstack-rest-api postgresql redis-server

# Verificar que o gateway esta recebendo
$ journalctl -u lora-pkt-fwd --since "2 minutes ago" | grep "PULL_ACK"

# Verificar disco (causa raiz frequente)
$ df -h /

# Verificar temperatura
$ vcgencmd measure_temp
```

Se o servico continua caindo apos restart, escalar para investigacao detalhada do log com `journalctl -u <servico> --since "1 hour ago"`.
