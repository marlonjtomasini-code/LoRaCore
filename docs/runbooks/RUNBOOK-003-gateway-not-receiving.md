# RUNBOOK-003: Gateway Nao Recebe Uplinks

**Trigger:** `watchdog_concentrator.sh` reporta `ALERTA sem PULL_ACK`, ou zero uplinks no ChirpStack.

**Tempo estimado:** 10-15 minutos

---

## 1. Deteccao

Sinais de que o gateway nao esta recebendo:

```bash
# Watchdog alertou
$ grep "sem PULL_ACK" /var/log/lorawan-health.log | tail -5

# Health check mostra gateway inativo
$ grep "gateway sem PULL_ACK" /var/log/lorawan-health.log | tail -5

# Verificacao direta — deve haver PULL_ACK recentes
$ journalctl -u lora-pkt-fwd --since "5 minutes ago" | grep "PULL_ACK"
```

---

## 2. Triagem — Arvore de Decisao

Siga na ordem. Pare no primeiro item que falhar.

### 2.1 Servico esta rodando?

```bash
$ systemctl is-active lora-pkt-fwd
# Se "inactive" → ir para Recovery 3.1
```

### 2.2 Concentrador USB esta visivel?

```bash
$ ls /dev/spidev* 2>/dev/null
# Se nao lista nada:
$ dmesg | tail -20 | grep -iE "usb|spi|rak|sx1302"
# Se USB desconectado → ir para Recovery 3.2
```

### 2.3 Packet forwarder esta recebendo pacotes?

```bash
$ journalctl -u lora-pkt-fwd --since "2 minutes ago" | grep -E "rxpk|PUSH_DATA"
# Se zero rxpk → problema RF (antena, device, frequencia) → ir para 3.3
# Se rxpk presente mas zero PULL_ACK → problema de rede/MQTT → ir para 3.4
```

### 2.4 MQTT Forwarder esta recebendo?

```bash
$ journalctl -u chirpstack-mqtt-forwarder --since "2 minutes ago" | grep -i "uplink\|sending"
# Se nao recebe nada → problema entre pkt-fwd e mqtt-forwarder → ir para 3.4
```

### 2.5 ChirpStack esta processando?

```bash
$ journalctl -u chirpstack --since "2 minutes ago" | grep -iE "uplink\|join"
# Se nao processa → problema interno do ChirpStack → ir para 3.5
```

---

## 3. Recovery

### 3.1 Servico inativo

```bash
$ sudo systemctl restart lora-pkt-fwd
$ sleep 5
$ journalctl -u lora-pkt-fwd --since "10 seconds ago" | grep "PULL_ACK"
```

Se nao inicia, ver log detalhado:

```bash
$ journalctl -u lora-pkt-fwd -n 30 --no-pager
```

### 3.2 Concentrador USB desconectado

1. Verificar conexao fisica do RAK2287 no RPi5
2. Se o hat esta bem conectado, tentar reset:

```bash
# Reset do USB
$ sudo modprobe -r spidev && sudo modprobe spidev
$ ls /dev/spidev*

# Se ainda nao aparece, reboot
$ sudo reboot
```

3. Apos reboot, verificar se o concentrador e detectado:

```bash
$ dmesg | grep -i "spi\|rak\|sx1302"
$ sudo systemctl status lora-pkt-fwd
```

### 3.3 Problema RF (zero rxpk)

O concentrador esta rodando mas nao recebe nenhum pacote RF:

```bash
# Verificar que o device esta transmitindo (via serial se disponivel)
# $ pio device monitor --baud 115200

# Verificar sub-band configurada no concentrador
$ grep -A2 "chan_multiSF" ~/packet_forwarder/global_conf.json | head -20

# Verificar que frequencias coincidem com US915 sub-band 1
# Canais 0-7: 902.3 a 903.7 MHz (200kHz steps)
# Canal 64: 903.0 MHz (500kHz)
```

Causas possiveis:
- Antena desconectada ou danificada
- Device configurado em sub-band diferente
- Distancia excessiva entre device e gateway
- Interferencia RF no local

### 3.4 Problema na cadeia MQTT

O packet forwarder recebe pacotes (rxpk), mas eles nao chegam ao ChirpStack:

```bash
# Verificar MQTT forwarder
$ systemctl is-active chirpstack-mqtt-forwarder
$ journalctl -u chirpstack-mqtt-forwarder -n 20 --no-pager

# Verificar Mosquitto
$ systemctl is-active mosquitto
$ cat /var/log/mosquitto/mosquitto.log | tail -10

# Verificar topic_prefix consistente
$ grep "topic_prefix" /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
$ grep "topic_prefix" /etc/chirpstack/region_us915_0.toml
# Devem ser identicos

# Restart da cadeia MQTT
$ sudo systemctl restart mosquitto
$ sleep 2
$ sudo systemctl restart chirpstack-mqtt-forwarder
$ sudo systemctl restart chirpstack
```

### 3.5 ChirpStack nao processa

```bash
# Verificar log do ChirpStack
$ journalctl -u chirpstack -n 30 --no-pager

# Verificar se PostgreSQL e Redis estao OK
$ systemctl is-active postgresql redis-server

# Restart do ChirpStack
$ sudo systemctl restart chirpstack
$ sleep 3
$ journalctl -u chirpstack --since "10 seconds ago"
```

---

## 4. Pos-incidente

```bash
# Confirmar PULL_ACK fluindo
$ journalctl -u lora-pkt-fwd --since "2 minutes ago" | grep -c "PULL_ACK"

# Confirmar uplinks chegando no ChirpStack (se device ativo)
$ journalctl -u chirpstack --since "5 minutes ago" | grep -i "uplink"

# Verificar QoS MQTT (deve ser 1 em todos)
$ grep "qos" /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
$ grep "qos" /etc/chirpstack/region_us915_0.toml
```

Se o problema recorrer, verificar temperatura do RPi5 (`vcgencmd measure_temp`) e carga de CPU (`uptime`). O stress test v3 mostrou que `lora-pkt-fwd` pode crashar sob carga extrema de I/O — se houver processos pesados no RPi, considere reduzir a carga.
