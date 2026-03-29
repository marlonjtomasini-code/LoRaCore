# Guia do Consumidor — Como Usar LoRaCore no Seu Projeto

Guia passo a passo para projetos que desejam adotar o LoRaCore como base de infraestrutura LoRaWAN. Cobre desde a escolha de banco de dados ate a integracao completa do backend.

---

## 1. O que e um Projeto Consumidor

Um **projeto consumidor** e qualquer sistema que usa a infraestrutura LoRaCore para transmitir e receber dados via LoRaWAN. O LoRaCore fornece a base; o consumidor constroi em cima dela.

```
┌─────────────────────────────────────────────┐
│           Projeto Consumidor                │
│  ┌──────────┐  ┌────────────┐  ┌─────────┐ │
│  │ Firmware  │  │  Backend   │  │  Codec  │ │
│  │ (devices) │  │ (logica)   │  │  (JS)   │ │
│  └─────┬─────┘  └──────┬─────┘  └────┬────┘ │
└────────┼───────────────┼──────────────┼──────┘
         │               │              │
    LoRaWAN         MQTT/gRPC     Device Profile
         │               │              │
┌────────┴───────────────┴──────────────┴──────┐
│              LoRaCore (RPi5)                  │
│  Gateway ← ChirpStack ← Mosquitto ← Redis   │
└──────────────────────────────────────────────┘
```

| LoRaCore fornece | Consumidor fornece |
|---|---|
| Gateway + Network Server (ChirpStack) | Firmware dos devices |
| Templates de configuracao | Backend e logica de negocio |
| Framework de codecs (esqueleto + exemplos) | Codecs especificos do protocolo |
| Documentacao de integracao (MQTT, REST, gRPC) | Mapeamento device ↔ funcao |
| Device profiles genericos (Class A/C) | Regras de controle e UI |

---

## 2. Pre-requisitos

Antes de iniciar a integracao:

- [ ] Infraestrutura LoRaCore instalada e operacional (ver [QUICK_START.md](QUICK_START.md), Step 1)
- [ ] Servicos rodando: ChirpStack, Mosquitto, Redis, Packet Forwarder
- [ ] Hardware do device em maos (MCU + modulo LoRa)
- [ ] Firmware do device minimamente funcional (join OTAA + envio de payload)

---

## 3. Passo a Passo de Adocao

### 3.1 Escolher Banco de Dados

O ChirpStack v4 suporta PostgreSQL e SQLite. Escolha conforme seu cenario:

| Criterio | PostgreSQL | SQLite |
|----------|-----------|--------|
| Devices | 100+ | < 100 |
| Concorrencia | Multi-processo | Single-writer |
| Setup | Requer servico PostgreSQL | Arquivo unico |
| Caso de uso | Producao | Edge, dev/teste |

**Arquivos de template:**
- PostgreSQL: [`templates/chirpstack/chirpstack.toml`](../templates/chirpstack/chirpstack.toml)
- SQLite: [`templates/chirpstack/chirpstack-sqlite.toml`](../templates/chirpstack/chirpstack-sqlite.toml)

Copie o template escolhido para `/etc/chirpstack/chirpstack.toml` e substitua o placeholder `<SECRET>`.

### 3.2 Criar Device Profiles

Device profiles definem o comportamento LoRaWAN dos seus devices (classe, codec, intervalos). O LoRaCore fornece dois templates:

| Template | Classe | Uso |
|----------|--------|-----|
| [`class-a-sensor-otaa.json`](../templates/chirpstack/device-profiles/class-a-sensor-otaa.json) | A | Sensores a bateria, transmissao periodica |
| [`class-c-actuator-otaa.json`](../templates/chirpstack/device-profiles/class-c-actuator-otaa.json) | C | Atuadores alimentados, recepcao continua |

**Opcao A — Importar via REST API:**

```bash
TOKEN="<SEU_TOKEN>"

# Importar device profile Class A
curl -X POST http://192.168.1.129:8090/api/device-profiles \
  -H "Grpc-Metadata-Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @templates/chirpstack/device-profiles/class-a-sensor-otaa.json
```

**Opcao B — Criar manualmente na web UI:**

1. Acesse `http://<HOST>:8080` > Device Profiles > Create
2. Preencha nome, regiao (US915), MAC version (1.0.3), OTAA
3. Na aba Codec, selecione "JavaScript functions" e cole seu codec
4. Salve

Apos criar, personalize o nome, descricao e codec conforme seu projeto.

### 3.3 Criar Codecs para Seu Protocolo

Codecs convertem payload binario LoRaWAN em JSON legivel. Cada device profile tem seu codec.

**Passo a passo:**

1. Copie [`templates/codecs/CODEC_TEMPLATE.js`](../templates/codecs/CODEC_TEMPLATE.js) e renomeie
2. Documente o layout de bytes do seu protocolo no header
3. Implemente `decodeUplink()` (obrigatorio) e opcionalmente `encodeDownlink()`/`decodeDownlink()`
4. Teste localmente com Node.js:

```bash
node -e "
$(cat meu-codec.js)

var input = { bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x00], fPort: 1 };
console.log(JSON.stringify(decodeUplink(input), null, 2));
"
```

5. Cole no Device Profile > Codec no ChirpStack

**Exemplos de referencia:**
- Sensor unidirecional: [`example-thermal-sensor.js`](../templates/codecs/example-thermal-sensor.js)
- Atuador bidirecional: [`example-actuator-bidirectional.js`](../templates/codecs/example-actuator-bidirectional.js)
- Guia completo: [`templates/codecs/README.md`](../templates/codecs/README.md)

### 3.4 Registrar Dispositivos

Com o device profile criado, registre seus devices no ChirpStack:

1. Crie uma **Application** (agrupamento logico de devices)
2. Registre cada device com DevEUI e AppKey
3. Grave as credenciais no firmware

Siga os Steps 2-4 do [QUICK_START.md](QUICK_START.md) para o procedimento detalhado.

### 3.5 Integrar Seu Backend

Tres mecanismos de integracao, cada um com seu caso de uso:

| Operacao | Mecanismo recomendado | Referencia |
|----------|----------------------|------------|
| Receber uplinks em tempo real | MQTT (subscribe) | [REFERENCIA Secao 2](REFERENCIA_INTEGRACAO.md#2-integracao-mqtt-dados-em-tempo-real) |
| Enviar downlinks (scripts/prototipos) | REST API | [REFERENCIA Secao 3](REFERENCIA_INTEGRACAO.md#3-rest-api-gerenciamento) |
| Enviar downlinks (producao) | gRPC | [REFERENCIA Secao 4](REFERENCIA_INTEGRACAO.md#4-grpc-api-downlinks-programaticos) |
| Gerenciar devices (CRUD) | REST API | [REFERENCIA Secao 3](REFERENCIA_INTEGRACAO.md#3-rest-api-gerenciamento) |

**Configuracao tipica do backend:**

```toml
# Exemplo de config.toml para um projeto consumidor

[transport.lorawan]
mqtt_broker = "192.168.1.129"
mqtt_port = 1883
mqtt_topic = "application/+/device/+/event/up"
chirpstack_grpc = "192.168.1.129:8080"
chirpstack_api_token = "<SEU_TOKEN>"
```

**Padrao minimo de integracao (Python):**

```python
# 1. Receber uplinks via MQTT
import json
import paho.mqtt.client as mqtt

def on_message(client, userdata, msg):
    payload = json.loads(msg.payload.decode())
    dev_eui = payload["deviceInfo"]["devEui"]
    data = payload.get("object", {})  # Dados decodificados pelo codec
    print(f"[{dev_eui}] {data}")

client = mqtt.Client(client_id="meu-backend", clean_session=False)
client.on_message = on_message
client.connect("192.168.1.129", 1883, keepalive=60)
client.subscribe("application/+/device/+/event/up", qos=1)
client.loop_forever()
```

```python
# 2. Enviar downlinks via gRPC
import grpc
from chirpstack_api import api as chirpstack_api

channel = grpc.insecure_channel("192.168.1.129:8080")
device_service = chirpstack_api.DeviceServiceStub(channel)
metadata = [("authorization", f"Bearer {API_TOKEN}")]

request = chirpstack_api.EnqueueDeviceQueueItemRequest(
    queue_item=chirpstack_api.DeviceQueueItem(
        dev_eui="<DEV_EUI>", confirmed=False, f_port=2,
        data=bytes([0x01, 0x02]),
    )
)
device_service.Enqueue(request, metadata=metadata)
```

### 3.6 Padroes de Integracao Recomendados

**Hot path sem banco de dados:** Para controle em tempo real, mantenha o caminho critico (receber uplink → decodificar → decidir → enviar downlink) sem dependencias de banco de dados. Carregue configuracao na memoria ao iniciar.

**Codec em duas camadas:** Implemente o codec tanto em JavaScript (ChirpStack auto-decode) quanto na linguagem do backend (decode/encode para logica de negocio). Ambos devem produzir resultados identicos.

**ACK tracking para atuadores:** Se seu projeto usa atuadores Class C, implemente rastreamento de ACK: numere comandos com sequence, monitore respostas, trate timeout com retry.

**Monitoramento de link:** Detecte devices offline comparando o timestamp do ultimo uplink com o intervalo esperado de transmissao (multiplicador tipico: 2.5x).

---

## 4. Checklist de Adocao

- [ ] Banco de dados escolhido (PostgreSQL ou SQLite)
- [ ] ChirpStack configurado com o template escolhido
- [ ] Device profile(s) criado(s) com codec JavaScript
- [ ] Application criada no ChirpStack
- [ ] Device(s) registrado(s) com DevEUI + AppKey
- [ ] Firmware flashed e device completou OTAA join
- [ ] Primeiro uplink visivel no ChirpStack (web UI)
- [ ] Backend recebendo uplinks via MQTT
- [ ] Dados decodificados pelo codec aparecem no campo `object`
- [ ] Backend consegue enviar downlinks (REST ou gRPC)
- [ ] Monitoramento em operacao (logs, MQTT events)

---

## 5. Exemplo Completo: Projeto SmartIrrigation

Cenario ficticio para ilustrar o fluxo completo de adocao.

**Dominio:** Sistema de irrigacao inteligente para agricultura.

**Devices:**
- **Sensor de umidade do solo** (Class A, bateria, uplink a cada 5 min)
- **Valvula solenoide** (Class C, alimentacao externa, abre/fecha sob comando)

### 5.1 Codec do Sensor de Umidade

```javascript
// Payload: [moisture_hi, moisture_lo, temp_hi, temp_lo, battery_mv_hi, battery_mv_lo]
function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 6) { return { data: {} }; }

  var moisture = (bytes[0] << 8) | bytes[1];  // x10, ex: 425 = 42.5%
  var tempRaw = (bytes[2] << 8) | bytes[3];
  if (tempRaw > 0x7FFF) { tempRaw = tempRaw - 0x10000; }
  var batteryMv = (bytes[4] << 8) | bytes[5];

  return {
    data: {
      soil_moisture_pct: moisture / 10.0,
      soil_temperature_c: tempRaw / 100.0,
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0
    }
  };
}
```

### 5.2 Codec da Valvula

```javascript
// Uplink: [state, flow_hi, flow_lo, fault_flags]
// Downlink: [command] — 0x01=open, 0x02=close
function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) { return { data: {} }; }
  return {
    data: {
      valve_state: bytes[0] === 1 ? "open" : "closed",
      flow_lpm: ((bytes[1] << 8) | bytes[2]) / 10.0,
      fault: (bytes[3] & 0x01) !== 0
    }
  };
}

function encodeDownlink(input) {
  var cmd = input.data.command === "open" ? 0x01 : 0x02;
  return { bytes: [cmd] };
}

function decodeDownlink(input) {
  return { data: { command: input.bytes[0] === 0x01 ? "open" : "close" } };
}
```

### 5.3 Fluxo de Operacao

```
1. Sensor mede umidade do solo → transmite uplink Class A
2. ChirpStack decodifica via codec → publica JSON no MQTT
3. Backend recebe via MQTT, extrai soil_moisture_pct
4. Logica de negocio: se umidade < 30% → abrir valvula
5. Backend envia downlink via gRPC: { command: "open" }
6. ChirpStack entrega imediatamente ao atuador Class C
7. Valvula abre e reporta estado via uplink
8. Backend monitora e fecha quando umidade > 60%
```

---

## 6. Referencia Cruzada

| Passo | Documento/Template |
|-------|-------------------|
| Infraestrutura base | [QUICK_START.md](QUICK_START.md) |
| Escolha de banco | [templates/chirpstack/](../templates/chirpstack/) |
| Device profiles | [templates/chirpstack/device-profiles/](../templates/chirpstack/device-profiles/) |
| Desenvolvimento de codecs | [templates/codecs/README.md](../templates/codecs/README.md) |
| Esqueleto de codec | [templates/codecs/CODEC_TEMPLATE.js](../templates/codecs/CODEC_TEMPLATE.js) |
| Integracao MQTT | [REFERENCIA_INTEGRACAO.md Secao 2](REFERENCIA_INTEGRACAO.md#2-integracao-mqtt-dados-em-tempo-real) |
| Integracao REST | [REFERENCIA_INTEGRACAO.md Secao 3](REFERENCIA_INTEGRACAO.md#3-rest-api-gerenciamento) |
| Integracao gRPC | [REFERENCIA_INTEGRACAO.md Secao 4](REFERENCIA_INTEGRACAO.md#4-grpc-api-downlinks-programaticos) |
| Exemplos completos | [REFERENCIA_INTEGRACAO.md Secao 5](REFERENCIA_INTEGRACAO.md#5-exemplos-completos) |
| Referencia da infraestrutura | [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) |
| Termos tecnicos | [GLOSSARIO.md](GLOSSARIO.md) |

---

## Ver Tambem

- [REFERENCIA_INTEGRACAO.md](REFERENCIA_INTEGRACAO.md) — Referencia completa dos mecanismos de integracao
- [QUICK_START.md](QUICK_START.md) — Do zero ao primeiro uplink em 30 minutos
- [templates/README.md](../templates/README.md) — Indice de todos os templates disponiveis
- [FAQ.md](FAQ.md) — Perguntas frequentes sobre capacidade e operacao
