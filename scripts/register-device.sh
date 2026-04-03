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
  MATCH_NAME="$PROFILE_NAME" python3 -c "
import sys,json,os
data = json.load(sys.stdin)
name = os.environ['MATCH_NAME']
for p in data.get('result',[]):
    if p.get('name') == name:
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

  SUPPORTS_CLASS_C=$([[ "$DEVICE_TYPE" == "actuator" ]] && echo "true" || echo "false")
  PROFILE_JSON=$(P_NAME="$PROFILE_NAME" P_TENANT="$TENANT_ID" P_MAC="$MAC_VERSION" \
    P_REG="$REG_PARAMS" P_CLASS_C="$SUPPORTS_CLASS_C" P_CODEC_RT="$CODEC_RUNTIME" \
    P_CODEC_SCRIPT="${CODEC_SCRIPT:-\"\"}" python3 -c "
import json,os
profile = {
    'deviceProfile': {
        'name': os.environ['P_NAME'],
        'description': 'Auto-gerado por register-device.sh',
        'tenantId': os.environ['P_TENANT'],
        'region': 'US915',
        'macVersion': os.environ['P_MAC'],
        'regParamsRevision': os.environ['P_REG'],
        'supportsOtaa': True,
        'supportsClassC': os.environ['P_CLASS_C'] == 'true',
        'payloadCodecRuntime': os.environ['P_CODEC_RT'],
        'payloadCodecScript': json.loads(os.environ['P_CODEC_SCRIPT']),
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
  MATCH_NAME="$APP_NAME" python3 -c "
import sys,json,os
data = json.load(sys.stdin)
name = os.environ['MATCH_NAME']
for a in data.get('result',[]):
    if a.get('name') == name:
        print(a['id'])
        break
" 2>/dev/null || true)

if [[ -n "$EXISTING_APP" ]]; then
  APP_ID="$EXISTING_APP"
  log "Application existente: ${APP_ID}"
else
  log "Criando application '${APP_NAME}'..."
  APP_JSON=$(A_NAME="$APP_NAME" A_TENANT="$TENANT_ID" python3 -c "
import json,os
app = {
    'application': {
        'name': os.environ['A_NAME'],
        'description': 'Auto-gerado por register-device.sh',
        'tenantId': os.environ['A_TENANT']
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
DEVICE_JSON=$(D_EUI="$DEV_EUI" D_NAME="$DEVICE_NAME" D_APP="$APP_ID" D_PROFILE="$PROFILE_ID" python3 -c "
import json,os
device = {
    'device': {
        'devEui': os.environ['D_EUI'],
        'name': os.environ['D_NAME'],
        'applicationId': os.environ['D_APP'],
        'deviceProfileId': os.environ['D_PROFILE'],
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
KEYS_JSON=$(K_EUI="$DEV_EUI" K_KEY="$APP_KEY" python3 -c "
import json,os
keys = {
    'deviceKeys': {
        'devEui': os.environ['K_EUI'],
        'nwkKey': os.environ['K_KEY'],
        'appKey': os.environ['K_KEY']
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
  J_DEV_EUI="$DEV_EUI" J_APP_KEY="$APP_KEY" J_JOIN_EUI="$JOIN_EUI" \
  J_DEV_NAME="$DEVICE_NAME" J_DEV_TYPE="$DEVICE_TYPE" J_APP_ID="$APP_ID" \
  J_APP_NAME="$APP_NAME" J_PROFILE_ID="$PROFILE_ID" J_DEV_CLASS="$DEVICE_CLASS" \
  J_EUI_BYTES="$DEV_EUI_BYTES" J_KEY_BYTES="$APP_KEY_BYTES" \
  J_AE_BYTES="$APP_EUI_BYTES" J_HOST="$HOST" python3 -c "
import json,os
e = os.environ
result = {
    'devEui': e['J_DEV_EUI'],
    'appKey': e['J_APP_KEY'],
    'joinEui': e['J_JOIN_EUI'],
    'deviceName': e['J_DEV_NAME'],
    'deviceType': e['J_DEV_TYPE'],
    'applicationId': e['J_APP_ID'],
    'applicationName': e['J_APP_NAME'],
    'deviceProfileId': e['J_PROFILE_ID'],
    'deviceClass': e['J_DEV_CLASS'],
    'devEuiBytes': e['J_EUI_BYTES'],
    'appKeyBytes': e['J_KEY_BYTES'],
    'appEuiBytes': e['J_AE_BYTES'],
    'host': e['J_HOST']
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
