#!/bin/bash
# Smoke test pos-deploy — LoRaCore
# Uso: bash scripts/smoke-test.sh [IP]
# IP padrao: 192.168.1.200

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IP="${1:-192.168.1.200}"
FAILS=0

echo "=== Smoke Test LoRaCore ($IP) ==="

# 1. Servicos systemd
for svc in lora-pkt-fwd chirpstack mosquitto postgresql redis-server; do
  if ! ssh marlon@$IP "systemctl is-active $svc" 2>/dev/null | grep -q active; then
    echo "FALHA: $svc inativo"
    FAILS=$((FAILS+1))
  fi
done

# 2. ChirpStack Web UI
if ! curl -sf http://$IP:8080 2>/dev/null | grep -qi chirpstack; then
  echo "FALHA: ChirpStack UI nao responde"
  FAILS=$((FAILS+1))
fi

# 3. MQTT broker
if ! timeout 5 mosquitto_sub -h $IP -t '$SYS/broker/uptime' -C 1 >/dev/null 2>&1; then
  echo "FALHA: MQTT broker nao responde"
  FAILS=$((FAILS+1))
fi

# 4. Logs sem erros
ERRORS=$(ssh marlon@$IP 'journalctl -u chirpstack -n 30 --no-pager 2>/dev/null' | grep -ci "error\|panic" 2>/dev/null || true)
ERRORS="${ERRORS:-0}"
if [ "$ERRORS" -gt 0 ] 2>/dev/null; then
  echo "ALERTA: $ERRORS erros nos logs do chirpstack"
fi

# 5. Codecs (local)
if ls "$REPO_ROOT"/templates/codecs/tests/test-*.js >/dev/null 2>&1; then
  for f in "$REPO_ROOT"/templates/codecs/tests/test-*.js; do
    if ! node "$f" >/dev/null 2>&1; then
      echo "FALHA: codec test $f"
      FAILS=$((FAILS+1))
    fi
  done
fi

echo "=== Resultado: $FAILS falhas ==="
exit $FAILS
