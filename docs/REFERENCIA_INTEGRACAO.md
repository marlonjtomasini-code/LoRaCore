# Referencia de Integracao — Como Consumir Dados do LoRaCore

Guia para projetos consumidores que precisam receber dados de devices LoRaWAN e/ou gerenciar dispositivos programaticamente. Cobre tres mecanismos de integracao: **MQTT** (dados em tempo real), **REST API** (gerenciamento) e **gRPC** (downlinks programaticos).

---

## 1. Visao Geral

```
                          ┌─────────────────────────┐
                          │    Projeto Consumidor    │
                          │   (seu backend/app)      │
                          └──┬──────────┬─────────┬──┘
                             │          │         │
                  MQTT :1883 │ REST :8090│  gRPC :8080
                 (tempo real)│ (gestao)  │ (downlinks)
                             │          │         │
                          ┌──┴──────────┴─────────┴──┐
                          │      LoRaCore (RPi5)      │
                          │  Mosquitto ← ChirpStack   │
                          └──────────────────────────┘
```

| Mecanismo | Quando usar | Protocolo | Porta |
|-----------|-------------|-----------|-------|
| **MQTT** | Receber uplinks, joins, status em tempo real | TCP (pub/sub) | 1883 |
| **REST API** | Criar/listar/remover devices, enviar downlinks, consultar estado | HTTP | 8090 |
| **gRPC** | Downlinks programaticos em backends de producao | HTTP/2 (Protobuf) | 8080 |

---

## 2. Integracao MQTT (Dados em Tempo Real)

### 2.1 Conexao

| Parametro | Valor |
|-----------|-------|
| Host | `192.168.1.186` (ou hostname do RPi) |
| Porta | `1883` |
| Autenticacao | Nenhuma (`allow_anonymous true` no Mosquitto) |
| QoS recomendado | 1 (at least once) |
| clean_session | `false` (preserva fila durante reconexao) |

### 2.2 Topicos de Aplicacao

Todos os eventos de aplicacao sao publicados em **JSON** pelo ChirpStack:

| Topico | Evento | Descricao |
|--------|--------|-----------|
| `application/<app_id>/device/<dev_eui>/event/up` | Uplink | Dados decodificados do device |
| `application/<app_id>/device/<dev_eui>/event/join` | Join | Notificacao de OTAA join |
| `application/<app_id>/device/<dev_eui>/event/status` | Status | Margem de link e nivel de bateria |
| `application/<app_id>/device/<dev_eui>/event/ack` | ACK | Confirmacao de downlink recebido pelo device |
| `application/<app_id>/device/<dev_eui>/event/log` | Log | Frame log (uplink/downlink raw) |

**Wildcards uteis:**

```bash
# Todos os uplinks de todos os devices de uma aplicacao
application/<app_id>/device/+/event/up

# Todos os eventos de um device especifico
application/<app_id>/device/<dev_eui>/event/#

# Todos os uplinks de todas as aplicacoes
application/+/device/+/event/up
```

### 2.3 Schema JSON — Uplink

Exemplo completo de um uplink recebido:

```json
{
  "deduplicationId": "a1b2c3d4-...",
  "time": "2026-03-29T14:30:00.123Z",
  "deviceInfo": {
    "tenantId": "6ab88d75-...",
    "tenantName": "ChirpStack",
    "applicationId": "e7e90971-...",
    "applicationName": "minha-aplicacao",
    "deviceProfileId": "ed752293-...",
    "deviceProfileName": "CubeCell-ClassA-Sensor",
    "deviceName": "sensor-01",
    "devEui": "3daa1dd8e5ceb357",
    "tags": {}
  },
  "devAddr": "01ABCDEF",
  "adr": true,
  "dr": 3,
  "fCnt": 42,
  "fPort": 2,
  "confirmed": false,
  "data": "DhQAKg==",
  "txInfo": {
    "frequency": 902500000,
    "modulation": {
      "lora": {
        "bandwidth": 125000,
        "spreadingFactor": 9,
        "codeRate": "CR_4_5"
      }
    }
  },
  "rxInfo": [
    {
      "gatewayId": "2ccf67fffe576a1d",
      "uplinkId": 12345,
      "rssi": -62,
      "snr": 13.5,
      "channel": 1,
      "location": {}
    }
  ],
  "object": {
    "battery_mv": 3700,
    "battery_v": 3.7,
    "uptime_s": 42
  }
}
```

**Campos mais relevantes para integracao:**

| Campo | Tipo | Descricao |
|-------|------|-----------|
| `deviceInfo.devEui` | string | Identificador unico do device |
| `deviceInfo.deviceName` | string | Nome amigavel do device |
| `fPort` | int | Porta LoRaWAN (identifica tipo de payload) |
| `fCnt` | int | Frame counter (sequencial, detecta perda) |
| `dr` | int | Data rate usado (DR0-DR5) |
| `data` | string | Payload bruto em base64 (antes do codec) |
| `object` | object | **Dados decodificados pelo codec** — este e o campo principal para consumo |
| `rxInfo[].rssi` | int | Potencia do sinal em dBm |
| `rxInfo[].snr` | float | Relacao sinal/ruido em dB |
| `time` | string | Timestamp ISO 8601 |

### 2.4 Schema JSON — Join

Publicado quando um device completa o OTAA join:

```json
{
  "deduplicationId": "...",
  "time": "2026-03-29T14:25:00Z",
  "deviceInfo": {
    "devEui": "3daa1dd8e5ceb357",
    "deviceName": "sensor-01",
    "deviceProfileName": "CubeCell-ClassA-Sensor"
  },
  "devAddr": "01ABCDEF"
}
```

**Uso**: detectar quando um device (re)entra na rede. Um join inesperado pode indicar reset do device ou perda de sessao.

### 2.5 Schema JSON — Status

Publicado periodicamente com informacoes de saude do device:

```json
{
  "deduplicationId": "...",
  "deviceInfo": {
    "devEui": "3daa1dd8e5ceb357",
    "deviceName": "sensor-01"
  },
  "margin": 15,
  "externalPowerSource": false,
  "batteryLevel": 85.5
}
```

| Campo | Descricao |
|-------|-----------|
| `margin` | Margem de demodulacao em dB (quanto acima do minimo necessario) |
| `batteryLevel` | Nivel de bateria (0-100%). Depende do firmware reportar via MAC command. |
| `externalPowerSource` | `true` se o device reporta alimentacao externa |

### 2.6 Schema JSON — ACK

Publicado quando o device confirma recebimento de um downlink:

```json
{
  "deduplicationId": "...",
  "deviceInfo": {
    "devEui": "3daa1dd8e5ceb357",
    "deviceName": "sensor-01"
  },
  "queueItemId": "...",
  "acknowledged": true,
  "fCntDown": 5
}
```

**Importante**: o ACK confirma que o frame chegou ao device, **nao** que o comando foi executado. Para confirmacao de execucao, o firmware deve enviar um uplink de confirmacao (ver Secao 15.6 do DOC_PROTOCOLO).

### 2.7 Padrao de Consumo Recomendado

```
1. Conectar ao Mosquitto com QoS 1 e clean_session=false
2. Subscribir em: application/+/device/+/event/up
3. Para cada mensagem:
   a. Parsear JSON
   b. Rotear por deviceInfo.devEui ou fPort
   c. Extrair dados de object (payload decodificado)
   d. Processar/armazenar conforme logica da aplicacao
4. Tratar reconexao automatica (o broker preserva a fila)
```

---

## 3. REST API (Gerenciamento)

Base URL: `http://192.168.1.186:8090/api`

### 3.1 Autenticacao

Gerar API key:

```bash
ssh marlon@192.168.1.186 "sudo chirpstack -c /etc/chirpstack create-api-key --name meu-backend"
```

Incluir em toda requisicao:

```
Header: Grpc-Metadata-Authorization: Bearer <TOKEN>
```

### 3.2 Endpoints de Dispositivos

**Listar devices:**
```bash
curl -s http://192.168.1.186:8090/api/devices?limit=100&applicationId=<APP_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

**Criar device:**
```bash
curl -X POST http://192.168.1.186:8090/api/devices \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "device": {
      "devEui": "<DEV_EUI>",
      "name": "sensor-novo",
      "applicationId": "<APP_ID>",
      "deviceProfileId": "<PROFILE_ID>",
      "isDisabled": false,
      "skipFcntCheck": false
    }
  }'
```

**Definir chaves OTAA:**
```bash
curl -X POST http://192.168.1.186:8090/api/devices/<DEV_EUI>/keys \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceKeys": {
      "devEui": "<DEV_EUI>",
      "nwkKey": "<APP_KEY>",
      "appKey": "<APP_KEY>"
    }
  }'
```

**Consultar device:**
```bash
curl -s http://192.168.1.186:8090/api/devices/<DEV_EUI> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

**Remover device:**
```bash
curl -X DELETE http://192.168.1.186:8090/api/devices/<DEV_EUI> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

**Enfileirar downlink:**
```bash
curl -X POST http://192.168.1.186:8090/api/devices/<DEV_EUI>/queue \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "queueItem": {
      "devEui": "<DEV_EUI>",
      "confirmed": false,
      "fPort": 2,
      "data": "<PAYLOAD_BASE64>"
    }
  }'
```

**Listar fila de downlinks:**
```bash
curl -s http://192.168.1.186:8090/api/devices/<DEV_EUI>/queue \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

### 3.3 Endpoints de Aplicacoes

```bash
# Listar
curl -s http://192.168.1.186:8090/api/applications?limit=100&tenantId=<TENANT_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"

# Criar
curl -X POST http://192.168.1.186:8090/api/applications \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "application": {
      "name": "nova-aplicacao",
      "tenantId": "<TENANT_ID>"
    }
  }'
```

### 3.4 Endpoints de Device Profiles

```bash
# Listar
curl -s http://192.168.1.186:8090/api/device-profiles?limit=100&tenantId=<TENANT_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

### 3.5 Endpoints de Gateways

```bash
# Listar
curl -s http://192.168.1.186:8090/api/gateways?limit=100&tenantId=<TENANT_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

---

## 4. gRPC API (Downlinks Programaticos)

O ChirpStack v4 expoe uma API gRPC na mesma porta da web UI (8080). Para backends de producao que enviam downlinks com frequencia, gRPC oferece tipagem nativa (Protobuf), menor overhead que REST e stubs gerados automaticamente.

### 4.1 Conexao

| Parametro | Valor |
|-----------|-------|
| Host | `192.168.1.186` (ou hostname do RPi) |
| Porta | `8080` (mesma da web UI — gRPC e HTTP/2 compartilham) |
| Protocolo | gRPC sobre HTTP/2 (insecure em rede local) |
| Pacote Python | `chirpstack-api` (`pip install chirpstack-api grpcio`) |
| Autenticacao | Bearer token via metadata gRPC |

### 4.2 Enfileirar Downlink (Python sincrono)

Exemplo completo e funcional para enviar um downlink a um device:

```python
import grpc
from chirpstack_api import api as chirpstack_api

CHIRPSTACK_GRPC = "192.168.1.186:8080"
API_TOKEN = "<SEU_TOKEN>"

# Abrir canal gRPC (insecure para rede local)
channel = grpc.insecure_channel(CHIRPSTACK_GRPC)
device_service = chirpstack_api.DeviceServiceStub(channel)
metadata = [("authorization", f"Bearer {API_TOKEN}")]

# Montar request de downlink
request = chirpstack_api.EnqueueDeviceQueueItemRequest(
    queue_item=chirpstack_api.DeviceQueueItem(
        dev_eui="<DEV_EUI>",
        confirmed=False,       # True para exigir ACK do device
        f_port=2,              # Porta LoRaWAN (1-223)
        data=bytes([0x01, 0x02]),  # Payload binario
    )
)

# Enviar
response = device_service.Enqueue(request, metadata=metadata)
print(f"Downlink enfileirado: id={response.id}")

channel.close()
```

**Dependencias**: `pip install chirpstack-api grpcio`

**Gerar API token**:
```bash
ssh marlon@192.168.1.186 "sudo chirpstack -c /etc/chirpstack create-api-key --name meu-backend"
```

### 4.3 Variante Assincrona (para backends de producao)

Para backends baseados em asyncio (FastAPI, aiohttp):

```python
import grpc.aio
from chirpstack_api import api as chirpstack_api

CHIRPSTACK_GRPC = "192.168.1.186:8080"
API_TOKEN = "<SEU_TOKEN>"

async def enqueue_downlink(dev_eui: str, f_port: int, data: bytes, confirmed: bool = False):
    async with grpc.aio.insecure_channel(CHIRPSTACK_GRPC) as channel:
        device_service = chirpstack_api.DeviceServiceStub(channel)
        metadata = [("authorization", f"Bearer {API_TOKEN}")]

        request = chirpstack_api.EnqueueDeviceQueueItemRequest(
            queue_item=chirpstack_api.DeviceQueueItem(
                dev_eui=dev_eui,
                confirmed=confirmed,
                f_port=f_port,
                data=data,
            )
        )

        response = await device_service.Enqueue(request, metadata=metadata)
        return response.id
```

**Dependencias**: `pip install chirpstack-api grpcio`

### 4.4 Flush e Consulta de Fila

```python
# Limpar fila de downlinks pendentes
flush_req = chirpstack_api.FlushDeviceQueueRequest(dev_eui="<DEV_EUI>")
device_service.FlushQueue(flush_req, metadata=metadata)

# Consultar fila atual
list_req = chirpstack_api.GetDeviceQueueItemsRequest(dev_eui="<DEV_EUI>")
queue = device_service.GetQueue(list_req, metadata=metadata)
for item in queue.result:
    print(f"  fPort={item.f_port} confirmed={item.confirmed} pending={item.is_pending}")
```

### 4.5 gRPC vs REST para Downlinks

| Aspecto | REST API (`:8090`) | gRPC (`:8080`) |
|---------|-------------------|----------------|
| Simplicidade | `curl` / `requests` | Requer `chirpstack-api` |
| Performance | HTTP/1.1 + JSON | HTTP/2 + Protobuf |
| Tipagem | Sem (JSON dinamico) | Protobuf (stubs tipados) |
| Caso de uso | Scripts, automacao simples | Backend de producao, alto volume |
| Dependencias | Nenhuma especial | `grpcio` + `chirpstack-api` |
| Streaming | Nao | Suportado |

**Recomendacao**: use REST para scripts e prototipos, gRPC para backends de producao.

---

## 5. Exemplos Completos

### 5.1 Python: Subscriber MQTT para Processar Uplinks

```python
import json
import paho.mqtt.client as mqtt

BROKER = "192.168.1.186"
PORT = 1883
TOPIC = "application/+/device/+/event/up"

def on_connect(client, userdata, flags, rc):
    print(f"Conectado ao MQTT broker (rc={rc})")
    client.subscribe(TOPIC, qos=1)

def on_message(client, userdata, msg):
    payload = json.loads(msg.payload.decode())
    dev_eui = payload["deviceInfo"]["devEui"]
    device_name = payload["deviceInfo"]["deviceName"]
    data = payload.get("object", {})
    rssi = payload["rxInfo"][0]["rssi"] if payload.get("rxInfo") else None

    print(f"[{device_name}] devEui={dev_eui} RSSI={rssi}dBm dados={data}")

    # Sua logica aqui:
    # - Salvar no banco de dados
    # - Verificar thresholds e gerar alertas
    # - Encaminhar para dashboard

client = mqtt.Client(client_id="meu-backend", clean_session=False)
client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, keepalive=60)
client.loop_forever()
```

**Dependencia**: `pip install paho-mqtt`

### 5.2 Bash: Registrar Device e Monitorar

```bash
#!/bin/bash
# Registrar um novo device e monitorar uplinks

API="http://192.168.1.186:8090/api"
TOKEN="<SEU_TOKEN>"
AUTH="Grpc-Metadata-Authorization: Bearer $TOKEN"

APP_ID="<APP_ID>"
PROFILE_ID="<PROFILE_ID>"

# Gerar credenciais
DEV_EUI=$(openssl rand -hex 8)
APP_KEY=$(openssl rand -hex 16)

echo "DevEUI:  $DEV_EUI"
echo "AppKey:  $APP_KEY"

# Criar device
curl -s -X POST "$API/devices" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"device\":{\"devEui\":\"$DEV_EUI\",\"name\":\"sensor-auto\",\"applicationId\":\"$APP_ID\",\"deviceProfileId\":\"$PROFILE_ID\",\"isDisabled\":false}}"

# Definir chaves OTAA
curl -s -X POST "$API/devices/$DEV_EUI/keys" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"deviceKeys\":{\"devEui\":\"$DEV_EUI\",\"nwkKey\":\"$APP_KEY\",\"appKey\":\"$APP_KEY\"}}"

echo ""
echo "Device registrado. Grave estas credenciais no firmware."
echo "Monitorando uplinks..."
mosquitto_sub -h 192.168.1.186 -t "application/+/device/$DEV_EUI/event/up" -v
```

### 5.3 Padrao de Integracao para Backend (FastAPI)

```python
import json
import threading
from fastapi import FastAPI
import paho.mqtt.client as mqtt

app = FastAPI()
latest_data = {}

# --- MQTT subscriber em thread separada ---

def on_message(client, userdata, msg):
    payload = json.loads(msg.payload.decode())
    dev_eui = payload["deviceInfo"]["devEui"]
    latest_data[dev_eui] = {
        "device_name": payload["deviceInfo"]["deviceName"],
        "data": payload.get("object", {}),
        "rssi": payload["rxInfo"][0]["rssi"] if payload.get("rxInfo") else None,
        "time": payload.get("time"),
        "fCnt": payload.get("fCnt"),
    }

def mqtt_thread():
    client = mqtt.Client(client_id="fastapi-backend", clean_session=False)
    client.on_message = on_message
    client.connect("192.168.1.186", 1883, keepalive=60)
    client.subscribe("application/+/device/+/event/up", qos=1)
    client.loop_forever()

threading.Thread(target=mqtt_thread, daemon=True).start()

# --- Endpoints REST do seu backend ---

@app.get("/devices")
def list_devices():
    return latest_data

@app.get("/devices/{dev_eui}")
def get_device(dev_eui: str):
    return latest_data.get(dev_eui, {"error": "device not found"})
```

**Dependencias**: `pip install fastapi uvicorn paho-mqtt`

---

## Ver Tambem

- [DOC_PROTOCOLO Secao 14](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#14-topicos-mqtt-e-integracao-de-dados) — Topicos MQTT e formato de payload
- [DOC_PROTOCOLO Secao 20](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#20-registro-de-dispositivos) — Registro de devices via API
- [DOC_PROTOCOLO Secao 15.6](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#156-confirmacao-de-comandos-class-c-camada-de-aplicacao) — Confirmacao de comandos Class C
- [GUIA_CONSUMIDOR.md](GUIA_CONSUMIDOR.md) — Guia completo de adocao do LoRaCore por projetos externos
- [GLOSSARIO.md](GLOSSARIO.md) — Definicoes dos termos tecnicos
- [ChirpStack REST API docs](https://www.chirpstack.io/docs/chirpstack/api/) — Referencia completa da API upstream
- [ChirpStack gRPC API](https://www.chirpstack.io/docs/chirpstack/api/grpc/) — Referencia gRPC upstream
