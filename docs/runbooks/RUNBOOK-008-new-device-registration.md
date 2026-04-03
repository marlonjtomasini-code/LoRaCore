# RUNBOOK-008: Cadastro de Novo Dispositivo

**Trigger:** Novo dispositivo LoRaWAN precisa ser registrado na infraestrutura (gateway + ChirpStack).

**Tempo estimado:** 15-30 minutos

> **Placeholders:** Substituir `<LORACORE_HOST>` pelo IP/hostname do gateway e `<USER>` pelo usuario SSH antes de executar os comandos.

---

## 1. Pre-requisitos

Antes de iniciar, confirme:

- [ ] Acesso SSH ao RPi5
- [ ] Tipo do device definido (Class A sensor ou Class C actuator)
- [ ] Firmware do device pronto para compilar
- [ ] Codec JavaScript pronto (ou usar um existente)

```bash
# Conectar ao gateway
$ ssh <USER>@<LORACORE_HOST>
```

### 1.1 Verificar saude da stack

```bash
# Smoke test rapido — todos os servicos devem estar ativos
$ sudo systemctl is-active lora-pkt-fwd chirpstack mosquitto postgresql redis-server
# Esperado: 5 linhas "active"

# Verificar Web UI respondendo
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
# Esperado: 200
```

Se algum servico estiver inativo, seguir [RUNBOOK-001](RUNBOOK-001-service-failure.md) antes de continuar.

### 1.2 Obter API Token

Se voce ainda nao tem um token para a REST API:

```bash
# Gerar token via CLI
$ sudo chirpstack -c /etc/chirpstack create-api-key --name my-backend
# Anotar o token retornado

# Exportar para uso nos comandos seguintes
$ export TOKEN="<TOKEN_GERADO>"
```

Ou use um token existente:

```bash
$ export TOKEN="<SEU_TOKEN>"
```

---

## 2. Gerar Credenciais OTAA

```bash
# DevEUI — identificador unico do device (8 bytes hex)
$ openssl rand -hex 8
# Exemplo: 3daa1dd8e5ceb357

# AppKey — chave de encriptacao OTAA (16 bytes hex)
$ openssl rand -hex 16
# Exemplo: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
```

Anote os valores gerados:

| Credencial | Valor |
|------------|-------|
| DevEUI | `<anotar>` |
| AppKey | `<anotar>` |
| JoinEUI (AppEUI) | `0000000000000000` (fixo) |

> **Importante:** O JoinEUI e sempre zeros no ChirpStack v4. Nao alterar.

---

## 3. Device Profile

### 3.1 Verificar profiles existentes

```bash
$ curl -s "http://localhost:8090/api/device-profiles?limit=50" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" | \
    python3 -c "import sys,json; [print(p['id'], p['name']) for p in json.load(sys.stdin).get('result',[])]"
```

Se ja existe um profile adequado para o seu device, anote o `id` e pule para o passo 4.

### 3.2 Criar novo Device Profile (se necessario)

Escolha o template conforme o tipo de device:

- **Sensor (Class A):** `templates/chirpstack/device-profiles/class-a-sensor-otaa.json`
- **Atuador (Class C):** `templates/chirpstack/device-profiles/class-c-actuator-otaa.json`

```bash
# Copiar template e editar
$ cp templates/chirpstack/device-profiles/class-a-sensor-otaa.json /tmp/my-profile.json

# Editar: nome, descricao, e colar o codec JS no campo payloadCodecScript
$ nano /tmp/my-profile.json
```

Campos que voce **deve** editar no JSON:

| Campo | O que colocar |
|-------|---------------|
| `name` | Nome descritivo (ex: `MeuProjeto-Sensor-OTAA`) |
| `description` | Descricao do device |
| `payloadCodecScript` | Codigo JavaScript do codec (ES5, completo) |

Campos que voce **nao deve** alterar:

| Campo | Valor fixo | Motivo |
|-------|-----------|--------|
| `region` | `US915` | Sub-band 1 |
| `macVersion` | `LORAWAN_1_0_3` | Versao padrao |
| `supportsOtaa` | `true` | ABP nao suportado |

```bash
# Importar o profile
$ curl -s -X POST "http://localhost:8090/api/device-profiles" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @/tmp/my-profile.json | python3 -m json.tool

# Anotar o "id" retornado — sera usado no passo 5
```

---

## 4. Application

### 4.1 Verificar applications existentes

```bash
$ curl -s "http://localhost:8090/api/applications?limit=50&tenantId=<TENANT_ID>" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" | \
    python3 -c "import sys,json; [print(a['id'], a['name']) for a in json.load(sys.stdin).get('result',[])]"
```

Se ja existe uma application adequada, anote o `id` e pule para o passo 5.

### 4.2 Criar nova Application (se necessario)

```bash
$ curl -s -X POST "http://localhost:8090/api/applications" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "application": {
        "name": "<NOME_DA_APPLICATION>",
        "description": "<DESCRICAO>",
        "tenantId": "<TENANT_ID>"
      }
    }' | python3 -m json.tool

# Anotar o "id" retornado
```

---

## 5. Registrar Device no ChirpStack

### 5.1 Criar device

```bash
$ curl -s -X POST "http://localhost:8090/api/devices" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "device": {
        "devEui": "<DEV_EUI>",
        "name": "<NOME_DO_DEVICE>",
        "applicationId": "<APP_ID>",
        "deviceProfileId": "<PROFILE_ID>",
        "isDisabled": false,
        "skipFcntCheck": false
      }
    }' | python3 -m json.tool
```

### 5.2 Configurar chaves OTAA

```bash
$ curl -s -X POST "http://localhost:8090/api/devices/<DEV_EUI>/keys" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "deviceKeys": {
        "devEui": "<DEV_EUI>",
        "nwkKey": "<APP_KEY>",
        "appKey": "<APP_KEY>"
      }
    }' | python3 -m json.tool
```

> **Critico:** `nwkKey` e `appKey` devem ter o **mesmo valor**. Isso e exigido pelo LoRaWAN 1.0.3.

### 5.3 Confirmar registro

```bash
$ curl -s "http://localhost:8090/api/devices/<DEV_EUI>" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" | python3 -m json.tool

# Verificar: devEui, name, applicationId, deviceProfileId estao corretos
```

---

## 6. Configurar e Flashar Firmware

### 6.1 Atualizar credenciais no codigo

No arquivo fonte do firmware, configurar:

```cpp
/* OTAA Keys — devem coincidir com o ChirpStack */
uint8_t devEui[] = { 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX };
uint8_t appEui[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }; /* sempre zeros */
uint8_t appKey[] = { 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX,
                     0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX };

/* US915 Sub-band 1 — nao alterar */
uint16_t userChannelsMask[6] = { 0x00FF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 };

/* Configuracao LoRaWAN */
LoRaMacRegion_t loraWanRegion = LORAMAC_REGION_US915;
DeviceClass_t   loraWanClass  = CLASS_A;       /* CLASS_A para sensores, CLASS_C para atuadores */
bool     overTheAirActivation = true;          /* OTAA obrigatorio */
```

**Checklist do firmware:**

- [ ] DevEUI coincide com o registrado no ChirpStack
- [ ] AppKey coincide com o registrado no ChirpStack
- [ ] AppEUI (JoinEUI) e `0x00` em todos os bytes
- [ ] Channel mask e `0x00FF` (sub-band 1)
- [ ] Regiao e `LORAMAC_REGION_US915`
- [ ] `overTheAirActivation = true`

### 6.2 Compilar e flashar

```bash
# Na maquina de desenvolvimento (nao no RPi5)
$ cd <DIRETORIO_DO_FIRMWARE>

# Compilar
$ pio run
# Deve terminar com SUCCESS

# Flashar no device (device conectado via USB)
$ pio run -t upload

# Abrir monitor serial para acompanhar
$ pio device monitor --baud 115200
```

No monitor serial, voce deve ver o device tentando join:

```
Joining...
Join accepted!
```

---

## 7. Validar Join OTAA

Volte ao terminal SSH do RPi5 e monitore o join:

```bash
# Opcao 1: Logs do ChirpStack
$ journalctl -u chirpstack -f | grep -i "join"

# Opcao 2: MQTT (mais limpo)
$ mosquitto_sub -h localhost -t "application/+/device/+/event/join" -v
```

**Join com sucesso** — voce vera uma mensagem com o `devEui` e `devAddr` atribuido.

### 7.1 Troubleshooting — Join nao acontece

| Sintoma | Causa provavel | Acao |
|---------|---------------|------|
| Nenhum join request nos logs | Device nao transmite ou frequencia errada | Verificar sub-band no firmware, verificar antena |
| Join request mas sem accept | DevEUI ou AppKey incorretos | Comparar credenciais firmware vs ChirpStack |
| Join request mas `MIC invalid` | AppKey nao coincide | Refazer passo 5.2 com a AppKey correta |
| Join request intermitente | Sinal fraco | Aproximar device do gateway, verificar antenas |

```bash
# Verificar se o gateway esta recebendo pacotes
$ journalctl -u lora-pkt-fwd --since "5 minutes ago" | grep -c "PULL_ACK"
# Se zero → problema no gateway, seguir RUNBOOK-003
```

---

## 8. Validar Primeiro Uplink

Apos o join, o device deve comecar a enviar uplinks no intervalo configurado (default: 60s).

```bash
# Monitorar uplinks via MQTT
$ mosquitto_sub -h localhost -t "application/+/device/<DEV_EUI>/event/up" -v

# Ou todos os devices
$ mosquitto_sub -h localhost -t "application/+/device/+/event/up" -v
```

**Uplink valido** — o JSON deve conter:

```json
{
  "deviceInfo": {
    "devEui": "<DEV_EUI>",
    "deviceName": "<NOME>"
  },
  "fPort": 2,
  "object": {
    "battery_mv": 3700,
    "uptime_s": 60
  },
  "rxInfo": [
    {
      "rssi": -62,
      "snr": 13.5
    }
  ]
}
```

Verificar:

| Campo | O que verificar |
|-------|----------------|
| `object` | Dados decodificados pelo codec (nao vazio) |
| `rxInfo[].rssi` | Acima de -120 dBm (ideal: acima de -90 dBm) |
| `rxInfo[].snr` | Acima de -7.5 dB (ideal: acima de 5 dB) |
| `fPort` | Porta esperada pelo firmware |

### 8.1 Verificar erros de codec

```bash
# Se object estiver vazio, verificar erros de decodificacao
$ mosquitto_sub -h localhost -t "application/+/device/<DEV_EUI>/event/error" -v
```

Se houver erros de codec, verificar:

- Payload do firmware coincide com o formato esperado pelo codec
- Codec usa ES5 (sem `let`, `const`, arrow functions)
- Codec retorna `{ data: {...} }` e nao `{ errors: [...] }` para payloads validos

### 8.2 Confirmar via REST API

```bash
$ curl -s "http://localhost:8090/api/devices/<DEV_EUI>" \
    -H "Grpc-Metadata-Authorization: Bearer $TOKEN" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print('lastSeenAt:', d.get('lastSeenAt','NUNCA'))"
# Deve mostrar timestamp recente, nao "NUNCA"
```

---

## 9. Checklist Final

Antes de considerar o cadastro completo, confirme todos os itens:

- [ ] Device aparece no ChirpStack Web UI (`http://<LORACORE_HOST>:8080`)
- [ ] Join OTAA completado com sucesso
- [ ] Uplinks chegando com dados decodificados no campo `object`
- [ ] RSSI e SNR em niveis aceitaveis
- [ ] Nenhum erro no topic `event/error`
- [ ] `lastSeenAt` atualizado na API
- [ ] Credenciais anotadas em local seguro

---

## Referencia rapida

| Item | Valor |
|------|-------|
| SSH | `<USER>@<LORACORE_HOST>` |
| ChirpStack Web UI | `http://<LORACORE_HOST>:8080` |
| REST API | `http://<LORACORE_HOST>:8090/api` |
| MQTT | `<LORACORE_HOST>:1883` |
| Auth header | `Grpc-Metadata-Authorization: Bearer <TOKEN>` |
| JoinEUI | `0000000000000000` (fixo) |
| Regiao | US915 sub-band 1 (canais 0-7) |
| LoRaWAN | 1.0.3, OTAA only |
| nwkKey = appKey | Obrigatorio (mesmo valor) |
