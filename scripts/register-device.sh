#!/usr/bin/env bash
# register-device.sh — Registro automatico de dispositivo LoRaWAN no ChirpStack v4
# Uso: register-device.sh --name <nome> --type <sensor|actuator> --app <app> [opcoes]
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
HOST="192.168.1.200"
API_PORT="8090"
SSH_USER="marlon"
DRY_RUN=false
JSON_OUTPUT=false
DEVICE_NAME=""
DEVICE_TYPE=""
APP_NAME=""
CODEC_FILE=""
DEV_EUI=""
APP_KEY=""
TOKEN=""

# ── Parse args ────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Uso: register-device.sh --name <nome> --type <sensor|actuator> --app <application> [opcoes]

Opcoes:
  --name <nome>         Nome do device (obrigatorio)
  --type <sensor|actuator>  Tipo: sensor (Class A) ou actuator (Class C) (obrigatorio)
  --app <application>   Nome da application no ChirpStack (obrigatorio)
  --codec <path.js>     Arquivo codec JS para embutir no device profile
  --deveui <hex>        DevEUI (16 hex chars). Auto-gerado se omitido
  --appkey <hex>        AppKey (32 hex chars). Auto-gerado se omitido
  --token <token>       API token. Default: $CHIRPSTACK_API_TOKEN ou ~/.chirpstack-token
  --host <ip>           IP do gateway. Default: 192.168.1.200
  --dry-run             Mostra comandos sem executar
  --json                Saida JSON para consumo programatico
  -h, --help            Mostra esta ajuda
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)     DEVICE_NAME="$2"; shift 2 ;;
    --type)     DEVICE_TYPE="$2"; shift 2 ;;
    --app)      APP_NAME="$2"; shift 2 ;;
    --codec)    CODEC_FILE="$2"; shift 2 ;;
    --deveui)   DEV_EUI="$2"; shift 2 ;;
    --appkey)   APP_KEY="$2"; shift 2 ;;
    --token)    TOKEN="$2"; shift 2 ;;
    --host)     HOST="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --json)     JSON_OUTPUT=true; shift ;;
    -h|--help)  usage ;;
    *)          echo "Erro: argumento desconhecido: $1" >&2; exit 1 ;;
  esac
done

# ── Validacao ─────────────────────────────────────────────────────────────────
fail() { echo "ERRO: $1" >&2; exit 1; }
log()  { $JSON_OUTPUT || echo ">> $1"; }

[[ -n "$DEVICE_NAME" ]] || fail "—name obrigatorio"
[[ -n "$DEVICE_TYPE" ]] || fail "—type obrigatorio (sensor|actuator)"
[[ -n "$APP_NAME" ]]    || fail "—app obrigatorio"
[[ "$DEVICE_TYPE" == "sensor" || "$DEVICE_TYPE" == "actuator" ]] || fail "--type deve ser sensor ou actuator"

# ── Token ─────────────────────────────────────────────────────────────────────
if [[ -z "$TOKEN" ]]; then
  TOKEN="${CHIRPSTACK_API_TOKEN:-}"
fi
if [[ -z "$TOKEN" && -f "$HOME/.chirpstack-token" ]]; then
  TOKEN=$(cat "$HOME/.chirpstack-token" | tr -d '[:space:]')
fi
[[ -n "$TOKEN" ]] || fail "Token nao encontrado. Use --token, \$CHIRPSTACK_API_TOKEN, ou ~/.chirpstack-token"

API_BASE="http://${HOST}:${API_PORT}/api"
AUTH_HEADER="Grpc-Metadata-Authorization: Bearer ${TOKEN}"

# ── Funcoes auxiliares ────────────────────────────────────────────────────────
api_get() {
  local endpoint="$1"
  if $DRY_RUN; then
    echo "[DRY-RUN] GET ${API_BASE}${endpoint}" >&2
    # Retorna mock com estrutura minima para o parser funcionar
    case "$endpoint" in
      /tenants*)       echo '{"result":[{"id":"dry-run-tenant"}]}' ;;
      /device-profiles*) echo '{"result":[]}' ;;
      /applications*)  echo '{"result":[]}' ;;
      /devices/*)      echo "{\"device\":{\"name\":\"${DEVICE_NAME}\"}}" ;;
      *)               echo '{}' ;;
    esac
    return
  fi
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" "${API_BASE}${endpoint}" -H "$AUTH_HEADER")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$http_code" -ge 400 ]]; then
    fail "API GET ${endpoint} retornou HTTP ${http_code}: ${body}"
  fi
  echo "$body"
}

api_post() {
  local endpoint="$1" data="$2"
  if $DRY_RUN; then
    echo "[DRY-RUN] POST ${API_BASE}${endpoint}" >&2
    echo "[DRY-RUN] Body: ${data}" >&2
    echo '{"id":"dry-run-id"}'
    return
  fi
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}${endpoint}" \
    -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$data")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$http_code" -ge 400 ]]; then
    fail "API POST ${endpoint} retornou HTTP ${http_code}: ${body}"
  fi
  echo "$body"
}

hex_to_bytes() {
  # Converte "3daa1dd8e5ceb357" para "0x3D,0xAA,0x1D,0xD8,0xE5,0xCE,0xB3,0x57"
  local hex="$1"
  local result=""
  for ((i=0; i<${#hex}; i+=2)); do
    [[ -n "$result" ]] && result+=","
    result+="0x${hex:$i:2}"
  done
  echo "$result" | tr '[:lower:]' '[:upper:]' | sed 's/0X/0x/g'
}

# ── 1. Health check ──────────────────────────────────────────────────────────
log "Verificando saude da stack em ${HOST}..."
if ! $DRY_RUN; then
  SERVICES="lora-pkt-fwd chirpstack mosquitto postgresql redis-server"
  HEALTH=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${HOST}" \
    "systemctl is-active ${SERVICES} 2>/dev/null" 2>/dev/null) || fail "SSH falhou para ${SSH_USER}@${HOST}"
  INACTIVE=$(echo "$HEALTH" | grep -v "^active$" || true)
  if [[ -n "$INACTIVE" ]]; then
    fail "Servicos inativos detectados. Verifique com RUNBOOK-001."
  fi
  log "Stack saudavel (5/5 servicos ativos)"
else
  echo "[DRY-RUN] ssh ${SSH_USER}@${HOST} systemctl is-active ..." >&2
fi

# ── 2. Gerar credenciais ─────────────────────────────────────────────────────
if [[ -z "$DEV_EUI" ]]; then
  DEV_EUI=$(openssl rand -hex 8)
  log "DevEUI gerado: ${DEV_EUI}"
else
  DEV_EUI=$(echo "$DEV_EUI" | tr '[:upper:]' '[:lower:]')
fi

if [[ -z "$APP_KEY" ]]; then
  APP_KEY=$(openssl rand -hex 16)
  log "AppKey gerada: ${APP_KEY}"
else
  APP_KEY=$(echo "$APP_KEY" | tr '[:upper:]' '[:lower:]')
fi

# Validar formato
[[ ${#DEV_EUI} -eq 16 && "$DEV_EUI" =~ ^[0-9a-f]+$ ]] || fail "DevEUI invalido: deve ter 16 chars hex (tem ${#DEV_EUI})"
[[ ${#APP_KEY} -eq 32 && "$APP_KEY" =~ ^[0-9a-f]+$ ]] || fail "AppKey invalida: deve ter 32 chars hex (tem ${#APP_KEY})"

JOIN_EUI="0000000000000000"

# ── 3. Descobrir tenant ID ────────────────────────────────────────────────────
log "Descobrindo tenant ID..."
TENANT_ID=$(api_get "/tenants?limit=1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',[{}])[0].get('id',''))" 2>/dev/null)
[[ -n "$TENANT_ID" ]] || fail "Nao foi possivel descobrir tenant ID"
log "Tenant ID: ${TENANT_ID}"

# ── 4. Device Profile ────────────────────────────────────────────────────────
if [[ "$DEVICE_TYPE" == "sensor" ]]; then
  PROFILE_NAME="${APP_NAME}-ClassA-Sensor-OTAA"
  DEVICE_CLASS="CLASS_A"
  MAC_VERSION="LORAWAN_1_0_3"
  REG_PARAMS="RP002_1_0_3"
else
  PROFILE_NAME="${APP_NAME}-ClassC-Actuator-OTAA"
  DEVICE_CLASS="CLASS_C"
  MAC_VERSION="LORAWAN_1_0_3"
  REG_PARAMS="RP002_1_0_3"
fi

log "Buscando device profile '${PROFILE_NAME}'..."
EXISTING_PROFILE=$(api_get "/device-profiles?limit=100&tenantId=${TENANT_ID}" | \
  python3 -c "
import sys,json
data = json.load(sys.stdin)
for p in data.get('result',[]):
    if p.get('name') == '${PROFILE_NAME}':
        print(p['id'])
        break
" 2>/dev/null || true)

if [[ -n "$EXISTING_PROFILE" ]]; then
  PROFILE_ID="$EXISTING_PROFILE"
  log "Device profile existente: ${PROFILE_ID}"
else
  log "Criando device profile '${PROFILE_NAME}'..."

  # Codec
  CODEC_RUNTIME="NONE"
  CODEC_SCRIPT=""
  if [[ -n "$CODEC_FILE" && -f "$CODEC_FILE" ]]; then
    CODEC_RUNTIME="JS"
    CODEC_SCRIPT=$(python3 -c "import json,sys; print(json.dumps(open(sys.argv[1]).read()))" "$CODEC_FILE")
  fi

  PROFILE_JSON=$(python3 -c "
import json
profile = {
    'deviceProfile': {
        'name': '${PROFILE_NAME}',
        'description': 'Auto-gerado por register-device.sh',
        'tenantId': '${TENANT_ID}',
        'region': 'US915',
        'macVersion': '${MAC_VERSION}',
        'regParamsRevision': '${REG_PARAMS}',
        'supportsOtaa': True,
        'supportsClassC': $([ "$DEVICE_TYPE" == "actuator" ] && echo "True" || echo "False"),
        'payloadCodecRuntime': '${CODEC_RUNTIME}',
        'payloadCodecScript': ${CODEC_SCRIPT:-'\"\"'},
        'uplinkInterval': 3600,
        'flushQueueOnActivate': True
    }
}
print(json.dumps(profile))
")

  PROFILE_RESULT=$(api_post "/device-profiles" "$PROFILE_JSON")
  PROFILE_ID=$(echo "$PROFILE_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  [[ -n "$PROFILE_ID" ]] || fail "Falha ao criar device profile"
  log "Device profile criado: ${PROFILE_ID}"
fi

# ── 5. Application ───────────────────────────────────────────────────────────
log "Buscando application '${APP_NAME}'..."
EXISTING_APP=$(api_get "/applications?limit=100&tenantId=${TENANT_ID}" | \
  python3 -c "
import sys,json
data = json.load(sys.stdin)
for a in data.get('result',[]):
    if a.get('name') == '${APP_NAME}':
        print(a['id'])
        break
" 2>/dev/null || true)

if [[ -n "$EXISTING_APP" ]]; then
  APP_ID="$EXISTING_APP"
  log "Application existente: ${APP_ID}"
else
  log "Criando application '${APP_NAME}'..."
  APP_JSON=$(python3 -c "
import json
app = {
    'application': {
        'name': '${APP_NAME}',
        'description': 'Auto-gerado por register-device.sh',
        'tenantId': '${TENANT_ID}'
    }
}
print(json.dumps(app))
")
  APP_RESULT=$(api_post "/applications" "$APP_JSON")
  APP_ID=$(echo "$APP_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  [[ -n "$APP_ID" ]] || fail "Falha ao criar application"
  log "Application criada: ${APP_ID}"
fi

# ── 6. Registrar device ──────────────────────────────────────────────────────
log "Registrando device '${DEVICE_NAME}' (${DEV_EUI})..."
DEVICE_JSON=$(python3 -c "
import json
device = {
    'device': {
        'devEui': '${DEV_EUI}',
        'name': '${DEVICE_NAME}',
        'applicationId': '${APP_ID}',
        'deviceProfileId': '${PROFILE_ID}',
        'isDisabled': False,
        'skipFcntCheck': False
    }
}
print(json.dumps(device))
")
api_post "/devices" "$DEVICE_JSON" > /dev/null
log "Device registrado"

# ── 7. Configurar chaves OTAA ────────────────────────────────────────────────
log "Configurando chaves OTAA (nwkKey = appKey)..."
KEYS_JSON=$(python3 -c "
import json
keys = {
    'deviceKeys': {
        'devEui': '${DEV_EUI}',
        'nwkKey': '${APP_KEY}',
        'appKey': '${APP_KEY}'
    }
}
print(json.dumps(keys))
")
api_post "/devices/${DEV_EUI}/keys" "$KEYS_JSON" > /dev/null
log "Chaves OTAA configuradas"

# ── 8. Verificar registro ────────────────────────────────────────────────────
log "Verificando registro..."
if ! $DRY_RUN; then
  VERIFY=$(api_get "/devices/${DEV_EUI}")
  VERIFY_NAME=$(echo "$VERIFY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('device',{}).get('name',''))" 2>/dev/null)
  [[ "$VERIFY_NAME" == "$DEVICE_NAME" ]] || fail "Verificacao falhou: nome retornado '${VERIFY_NAME}' != '${DEVICE_NAME}'"
  log "Verificacao OK"
fi

# ── 9. Output ─────────────────────────────────────────────────────────────────
DEV_EUI_BYTES=$(hex_to_bytes "$DEV_EUI")
APP_KEY_BYTES=$(hex_to_bytes "$APP_KEY")
APP_EUI_BYTES="0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00"

if $JSON_OUTPUT; then
  python3 -c "
import json
result = {
    'devEui': '${DEV_EUI}',
    'appKey': '${APP_KEY}',
    'joinEui': '${JOIN_EUI}',
    'deviceName': '${DEVICE_NAME}',
    'deviceType': '${DEVICE_TYPE}',
    'applicationId': '${APP_ID}',
    'applicationName': '${APP_NAME}',
    'deviceProfileId': '${PROFILE_ID}',
    'deviceClass': '${DEVICE_CLASS}',
    'devEuiBytes': '${DEV_EUI_BYTES}',
    'appKeyBytes': '${APP_KEY_BYTES}',
    'appEuiBytes': '${APP_EUI_BYTES}',
    'host': '${HOST}'
}
print(json.dumps(result, indent=2))
"
else
  echo ""
  echo "=========================================="
  echo " Device registrado com sucesso!"
  echo "=========================================="
  echo ""
  echo "  Nome:          ${DEVICE_NAME}"
  echo "  Tipo:          ${DEVICE_TYPE} (${DEVICE_CLASS})"
  echo "  Application:   ${APP_NAME} (${APP_ID})"
  echo "  Profile:       ${PROFILE_ID}"
  echo ""
  echo "  DevEUI:        ${DEV_EUI}"
  echo "  AppKey:        ${APP_KEY}"
  echo "  JoinEUI:       ${JOIN_EUI} (fixo)"
  echo ""
  echo "  --- Para firmware (platformio.ini) ---"
  echo "  -D DEV_EUI_BYTES=${DEV_EUI_BYTES}"
  echo "  -D APP_KEY_BYTES=${APP_KEY_BYTES}"
  echo ""
  echo "  --- Para firmware (C array) ---"
  echo "  uint8_t devEui[] = { ${DEV_EUI_BYTES} };"
  echo "  uint8_t appEui[] = { ${APP_EUI_BYTES} };"
  echo "  uint8_t appKey[] = { ${APP_KEY_BYTES} };"
  echo ""
  echo "  --- Validacao MQTT ---"
  echo "  mosquitto_sub -h ${HOST} -t \"application/+/device/${DEV_EUI}/event/join\" -v"
  echo ""
fi
