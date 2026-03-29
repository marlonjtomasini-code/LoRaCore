# RUNBOOK-005: Device Offline

**Trigger:** `device_monitor.sh` reporta `[ALERTA] OFFLINE <nome> (<dev_eui>)`, ou device sem dados no ChirpStack.

**Tempo estimado:** 10-15 minutos

---

## 1. Deteccao

Sinais de device offline:

```bash
# Alertas no log de monitoramento
$ grep "OFFLINE" /var/log/lorawan-health.log | tail -10

# Verificar last seen via API
$ curl -s http://localhost:8090/api/devices?limit=50 \
    -H "Authorization: Bearer <CHIRPSTACK_TOKEN>" | \
    python3 -c "import sys,json; [print(d['name'], d.get('lastSeenAt','never')) for d in json.load(sys.stdin).get('result',[])]"
```

---

## 2. Triagem — Um device ou todos?

Esta e a pergunta critica. A resposta determina a direcao do diagnostico.

### Todos os devices offline?

```bash
# Verificar se o gateway esta recebendo
$ journalctl -u lora-pkt-fwd --since "5 minutes ago" | grep -c "PULL_ACK"
```

Se zero PULL_ACK → **o problema e no gateway, nao nos devices**. Seguir [RUNBOOK-003](RUNBOOK-003-gateway-not-receiving.md).

### Apenas um device offline?

O problema e no device ou na comunicacao RF desse device especifico. Continue abaixo.

---

## 3. Recovery — Device individual offline

### 3.1 Verificar no ChirpStack

```bash
# Ultimo uplink do device
$ curl -s "http://localhost:8090/api/devices/<DEV_EUI>" \
    -H "Authorization: Bearer <CHIRPSTACK_TOKEN>" | python3 -m json.tool

# Verificar se o device esta ativado (joined)
# Se lastSeenAt = null → device nunca fez join com sucesso
```

### 3.2 Device nunca fez join

Se `lastSeenAt` e nulo, o device nunca completou OTAA:

```bash
# Verificar join requests no ChirpStack
$ journalctl -u chirpstack --since "30 minutes ago" | grep -i "joinrequest"

# Se nenhum join request → device nao esta transmitindo ou frequencia errada
# Se join request mas sem accept → DevEUI ou AppKey incorretos
```

Verificacoes:
- DevEUI no firmware coincide com o registrado no ChirpStack?
- AppKey no firmware coincide com o registrado no ChirpStack?
- Device esta configurado para US915 sub-band 1 (canais 0-7)?

### 3.3 Device fez join mas parou de reportar

Causas provaveis:

| Causa | Como verificar |
|-------|---------------|
| Bateria esgotada | Ultimo payload tinha `battery_mv` baixo? |
| Device travou | Reset fisico (botao ou power cycle) |
| Device fora de alcance | Moveu de posicao desde ultimo report? |
| Firmware crash | Conectar serial e verificar output |

```bash
# Se tem acesso serial ao device
# $ pio device monitor --baud 115200
# Verificar se o device esta tentando transmitir
```

### 3.4 Interferencia RF ou alcance

Se o device parou de reportar apos mudanca de posicao:

- Verificar distancia ao gateway (LoRa indoor: 50-200m, outdoor: 2-5km)
- Verificar obstrucoes metalicas (paredes metalicas, maquinas industriais)
- Verificar se antena do device e do gateway estao conectadas

### 3.5 Confirmed mode sob carga

O stress test v3 demonstrou que devices em **confirmed mode** colapsam de 74% para 11% de entrega sob carga de CPU. Se o device usa confirmed mode:

```bash
# Verificar Device Profile no ChirpStack
# Se confirmed mode + muitos devices → considerar trocar para unconfirmed
```

Recomendacao: usar **unconfirmed mode** para telemetria de sensores. Reservar confirmed mode apenas para atuadores criticos com < 5 devices e < 1 msg/min.

---

## 4. Pos-incidente

```bash
# Confirmar que o device voltou a reportar
$ grep "<DEV_EUI>" /var/log/lorawan-health.log | tail -5

# Ou via ChirpStack
$ journalctl -u chirpstack --since "10 minutes ago" | grep -i "<DEV_EUI>"

# Monitorar por 15 minutos para confirmar estabilidade
$ journalctl -u chirpstack -f | grep -i "uplink"
```

### Referencia rapida: sinais no firmware CubeCell

| Comportamento do LED | Significado |
|---------------------|-------------|
| Piscando rapido | Tentando join |
| Piscando lento | Transmitindo (uplink) |
| Apagado | Deep sleep entre transmissoes |
| Fixo | Possivel travamento |

Se o device travou, um reset fisico (botao RST ou power cycle) geralmente resolve. Se recorrente, investigar firmware via serial.
