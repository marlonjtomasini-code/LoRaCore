# Quick Start — Do Zero ao Primeiro Uplink

Guia pratico para adicionar seu primeiro device e ver dados fluindo. Pressupoe que a infraestrutura LoRaCore **ja esta instalada e rodando** no Raspberry Pi (se nao, siga a Secao 19 do [DOC_PROTOCOLO](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#19-procedimento-de-instalacao-passo-a-passo)).

> **Adotando o LoRaCore em um projeto existente?** Veja o [Guia do Consumidor](GUIA_CONSUMIDOR.md) para o fluxo completo de integracao.

**Tempo estimado**: ~30 minutos
**Material necessario**: CubeCell HTCC-AB01 + cabo USB + notebook com PlatformIO

---

## Passo 1: Verificar Saude da Infra (2 min)

Confirme que todos os servicos estao rodando:

```bash
ssh marlon@192.168.1.129 "systemctl is-active postgresql redis-server mosquitto chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api lora-pkt-fwd"
```

**Esperado**: 7 linhas com `active`. Se algum estiver `inactive` ou `failed`, verifique com `journalctl -u <servico> -n 20`.

Confirme que o gateway esta comunicando:

```bash
ssh marlon@192.168.1.129 "journalctl -u lora-pkt-fwd --since '2 min ago' --no-pager | grep PULL_ACK"
```

**Esperado**: linhas com `PULL_ACK` recentes (a cada ~10s).

---

## Passo 2: Criar Application e Device Profile no ChirpStack (5 min)

Acesse a Web UI: `http://192.168.1.129:8080` (login: `admin` / `admin`).

### 2.1 Criar Application (se ainda nao existe)

1. Menu lateral > **Applications** > **Add application**
2. Nome: `minha-aplicacao` (ou o nome do seu projeto)
3. Salvar — anote o **Application ID** (UUID) que aparece na URL

### 2.2 Criar Device Profile

1. Menu lateral > **Device profiles** > **Add device profile**
2. Aba **General**:
   - Nome: `CubeCell-ClassA-Sensor`
   - Region: `US915`
   - MAC version: `LoRaWAN 1.0.3`
   - Regional parameters revision: `A`
   - ADR algorithm: `Default ADR algorithm`
   - Expected uplink interval: `60` segundos
3. Aba **Join (OTAA/ABP)**:
   - Marcar **Device supports OTAA**
4. Aba **Codec**:
   - Tipo: `JavaScript`
   - Colar o conteudo de `templates/codecs/cubecell-class-a-sensor.js`
5. Salvar

---

## Passo 3: Registrar o Device (3 min)

### 3.1 Gerar credenciais

No seu notebook:

```bash
# DevEUI (8 bytes aleatorios)
openssl rand -hex 8
# Exemplo: 3daa1dd8e5ceb357

# AppKey (16 bytes aleatorios)
openssl rand -hex 16
# Exemplo: ae0a314fd2f6303d18ad170821f37c7d
```

### 3.2 Registrar no ChirpStack

1. Menu lateral > **Applications** > sua aplicacao > **Add device**
2. Nome: `sensor-01`
3. Device EUI: colar o DevEUI gerado
4. Device profile: `CubeCell-ClassA-Sensor`
5. Salvar
6. Na tela seguinte, colar a **Application key** (AppKey gerado)
7. Salvar

---

## Passo 4: Gravar Firmware no CubeCell (5 min)

### 4.1 Preparar o firmware de teste

```bash
cd LoRaCore/examples/firmware/cubecell-otaa-test
```

Editar o codigo-fonte e inserir as credenciais geradas no Passo 3:

```cpp
uint8_t devEui[] = { 0x3D, 0xAA, 0x1D, 0xD8, 0xE5, 0xCE, 0xB3, 0x57 };
uint8_t appKey[] = { 0xAE, 0x0A, 0x31, 0x4F, 0xD2, 0xF6, 0x30, 0x3D,
                     0x18, 0xAD, 0x17, 0x08, 0x21, 0xF3, 0x7C, 0x7D };
```

### 4.2 Compilar e gravar

Conectar o CubeCell via USB e executar:

```bash
# Compilar
pio run

# Upload
pio run -t upload

# Abrir serial monitor
pio device monitor --baud 115200
```

**Esperado no serial**: mensagens de inicializacao e tentativa de join.

---

## Passo 5: Validar Join OTAA (5 min)

### 5.1 No serial monitor

Aguarde o join (pode levar de 5s a 2min na primeira vez):

```
[info] Joining...
[info] Joined! DevAddr: 01XXXXXX
[info] TX #1 bat=3700mV
```

### 5.2 Nos logs do ChirpStack

Em outro terminal:

```bash
ssh marlon@192.168.1.129 "journalctl -u chirpstack -f --no-pager" | grep -i "join\|uplink"
```

**Esperado**: mensagens de `JoinRequest received` seguidas de `JoinAccept sent`.

### 5.3 Se o join falhar

As 3 causas mais comuns:

1. **DevEUI ou AppKey incorretos** — comparar o que esta no firmware com o que esta no ChirpStack
2. **Sub-band errada** — o firmware deve usar canais 0-7 (US915 sub-band 1), mesma configuracao do concentrador
3. **Packet Forwarder sem PULL_ACK** — verificar `journalctl -u lora-pkt-fwd -f`

---

## Passo 6: Validar Uplinks via MQTT (5 min)

Abrir um subscriber MQTT para ver os dados decodificados:

```bash
mosquitto_sub -h 192.168.1.129 -t "application/+/device/+/event/up" -v
```

**Esperado**: JSON com os dados decodificados pelo codec:

```json
{
  "deviceInfo": {
    "deviceName": "sensor-01",
    "devEui": "3daa1dd8e5ceb357",
    "deviceProfileName": "CubeCell-ClassA-Sensor"
  },
  "fPort": 2,
  "fCnt": 1,
  "object": {
    "battery_mv": 3700,
    "battery_v": 3.7,
    "uptime_s": 15
  }
}
```

Se `object` estiver vazio, o codec nao esta configurado corretamente no Device Profile.

---

## Passo 7: Enviar um Downlink (opcional, 5 min)

Testar o envio de um comando do servidor para o device:

```bash
# Gerar API key (se ainda nao tem)
ssh marlon@192.168.1.129 "sudo chirpstack -c /etc/chirpstack create-api-key --name quickstart"

# Enfileirar downlink (base64 de [0x01, 0x02])
curl -X POST http://192.168.1.129:8090/api/devices/3daa1dd8e5ceb357/queue \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "queueItem": {
      "devEui": "3daa1dd8e5ceb357",
      "fPort": 2,
      "data": "AQI="
    }
  }'
```

Para Class A, o downlink sera entregue na proxima janela RX1/RX2 (apos o proximo uplink do device). Verifique no serial monitor se o device recebeu.

---

## Proximo Passo

- **Adotar o LoRaCore no seu projeto**: [GUIA_CONSUMIDOR.md](GUIA_CONSUMIDOR.md) — fluxo completo de integracao
- **Criar firmware customizado**: copiar `examples/firmware/cubecell-otaa-test/` e adaptar para o seu sensor
- **Entender cada componente**: [DOC_PROTOCOLO Secoes 4-9](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#4-camada-1---concentrador-lora-packet-forwarder)
- **Integrar via MQTT/gRPC no seu projeto**: [REFERENCIA_INTEGRACAO.md](REFERENCIA_INTEGRACAO.md)
- **Termos que voce nao conhece**: [GLOSSARIO.md](GLOSSARIO.md)
