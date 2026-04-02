# LoRaCore — AI Integration Guide

Self-contained reference for AI agents building firmware and backends that integrate with a LoRaCore gateway. Everything needed is inline — no external file references required.

**Stack version:** ChirpStack 4.17.0 / PostgreSQL 16 / Redis 7 / Mosquitto 2.0.18
**Generated:** 2026-04-02

---

## 1. Architecture

```
Devices (LoRa radio)
    | LoRaWAN RF (US915 sub-band 1)
    v
[RAK2287 concentrator on RPi5] (SX1302 + SX1250)
    | USB
    v
[Packet Forwarder - sx1302_hal] (C binary)
    | UDP :1700
    v
[ChirpStack MQTT Forwarder] (Rust binary, 3.7MB)
    | MQTT
    v
[Mosquitto MQTT Broker] (:1883)
    | MQTT subscribe
    v
[ChirpStack Network Server v4.17.0]
    |-- PostgreSQL 16 (device registry, session keys)
    |-- Redis 7 (session cache, deduplication)
    |-- REST API :8090
    |-- gRPC + Web UI :8080
```

### Port Map

| Port | Protocol | Service | Use |
|------|----------|---------|-----|
| 1883 | MQTT (TCP) | Mosquitto | Real-time uplinks, events |
| 8080 | HTTP/2 | ChirpStack | Web UI + gRPC API |
| 8090 | HTTP/1.1 | chirpstack-rest-api | REST API (JSON) |

### Services (systemd)

| Unit | Binary |
|------|--------|
| `lora-pkt-fwd` | Packet Forwarder (C) |
| `chirpstack-mqtt-forwarder` | MQTT Forwarder (Rust) |
| `chirpstack` | Network Server |
| `chirpstack-rest-api` | REST API proxy |
| `mosquitto` | MQTT broker |
| `postgresql` | Database |
| `redis-server` | Cache |

All services run natively on the RPi5 (no containers). Consumer backends can run anywhere — integration is over the network.

---

## 2. Network Configuration

### US915 Sub-band 1

| Channel | Frequency (MHz) | Bandwidth | Data Rate |
|---------|-----------------|-----------|-----------|
| 0 | 902.3 | 125 kHz | DR0-DR3 |
| 1 | 902.5 | 125 kHz | DR0-DR3 |
| 2 | 902.7 | 125 kHz | DR0-DR3 |
| 3 | 902.9 | 125 kHz | DR0-DR3 |
| 4 | 903.1 | 125 kHz | DR0-DR3 |
| 5 | 903.3 | 125 kHz | DR0-DR3 |
| 6 | 903.5 | 125 kHz | DR0-DR3 |
| 7 | 903.7 | 125 kHz | DR0-DR3 |
| 64 | 903.0 | 500 kHz | DR4 |

### LoRaWAN Parameters

| Parameter | Value |
|-----------|-------|
| LoRaWAN version | 1.0.3 |
| Activation | OTAA only (no ABP) |
| ADR | Enabled |
| RX1 delay | 1 second |
| RX2 frequency | 923.3 MHz |
| RX2 data rate | DR8 (SF12/500kHz) |

### Data Rate Table (US915 uplink)

| DR | Spreading Factor | Bandwidth | Max Payload (bytes) |
|----|-----------------|-----------|---------------------|
| DR0 | SF10 | 125 kHz | 11 |
| DR1 | SF9 | 125 kHz | 53 |
| DR2 | SF8 | 125 kHz | 125 |
| DR3 | SF7 | 125 kHz | 242 |
| DR4 | SF8 | 500 kHz | 242 |

**Rule of thumb:** Design payloads to fit DR0 (11 bytes) if possible. This ensures delivery even at worst signal conditions. If more bytes are needed, DR1 (53 bytes) is the practical minimum for most use cases.

---

## 3. Payload Format

### Conventions

- **Byte order:** big-endian (MSB first) — this is the LoRaWAN convention and what the codecs below expect
- **fPort routing:** use different fPort values (1-223) to distinguish payload types from the same device (e.g., fPort 1 = telemetry, fPort 2 = status/diagnostic)
- **Keep payloads small:** every byte costs airtime. Use fixed-point integers instead of floats (e.g., temperature × 100 as int16)

### Common Encoding Patterns

| Data type | Encoding | Bytes | Example |
|-----------|----------|-------|---------|
| uint8 | Raw byte | 1 | Humidity 65% → `0x41` |
| uint16 | Big-endian | 2 | Battery 3700 mV → `0x0E 0x74` |
| int16 (signed) | Big-endian + two's complement | 2 | Temperature -5.25°C → `0xFD 0xF3` (raw: -525) |
| Bitmask/flags | Single byte, bit fields | 1 | `bit0=fault, bit1=low_bat, bit2=boot` |
| Fixed-point | Integer × scale factor | 2 | 23.45°C → 2345 as uint16, divide by 100 in codec |

### Max Payload per Data Rate

| DR | Max payload | Recommended use |
|----|-------------|-----------------|
| DR0 | 11 bytes | Minimal telemetry (e.g., 2-3 sensor values) |
| DR1 | 53 bytes | Standard telemetry + diagnostics |
| DR2 | 125 bytes | Extended payloads |
| DR3-DR4 | 242 bytes | Large payloads (firmware status, batch data) |

---

## 4. Codec JavaScript (ChirpStack)

Codecs are JavaScript functions that ChirpStack executes to convert binary payloads to/from JSON. They are pasted into the Device Profile > Codec tab.

### Constraints

- **ES5 only** — no `let`, `const`, arrow functions (`=>`), template literals, destructuring, `import`, `require`
- Use `var` for all variable declarations
- `Math`, `Date`, `Array`, `Object`, `JSON`, `parseInt` are available
- No Node.js modules

### Function Signatures

**`decodeUplink(input)`** — REQUIRED. Called on every uplink.

```
input:  { bytes: Uint8Array, fPort: number, recvTime: Date }
return: { data: { field1: val1, ... } }     (success)
        { errors: ["message"] }             (failure)
```

The `data` object appears in the MQTT JSON field `object` and in the Web UI.

**`encodeDownlink(input)`** — Optional. Called when sending a downlink via API with JSON payload.

```
input:  { data: { field1: val1, ... } }
return: { bytes: [byte0, byte1, ...] }
```

**`decodeDownlink(input)`** — Optional. Inverse of encodeDownlink, used for Web UI display.

```
input:  { bytes: Uint8Array, fPort: number }
return: { data: { field1: val1, ... } }
```

### Error Handling

Always return `{ errors: [...] }` for invalid payloads. Never return `{ data: {} }` on error — that creates silent failures.

```javascript
// CORRECT — error visible in ChirpStack UI and MQTT error topic
if (bytes.length < 6) {
  return { errors: ["payload too short: expected 6 bytes, got " + bytes.length] };
}

// WRONG — silent failure, hard to debug
if (bytes.length < 6) {
  return { data: {} };
}
```

Codec errors are published to MQTT topic `application/<app_id>/device/<dev_eui>/event/error`.

### Testing Locally (Node.js)

```bash
# Test decodeUplink
node -e "
$(cat my-codec.js)

var input = { bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x00], fPort: 1 };
console.log(JSON.stringify(decodeUplink(input), null, 2));
"

# Test roundtrip (encode then decode)
node -e "
$(cat my-codec.js)

var original = { data: { command: 'set_position', position: 75, speed: 50 } };
var encoded = encodeDownlink(original);
console.log('encoded:', encoded.bytes);
var decoded = decodeDownlink({ bytes: encoded.bytes, fPort: 2 });
console.log('decoded:', JSON.stringify(decoded.data));
"
```

### Codec Template

Copy this skeleton and implement the TODO sections:

```javascript
// =============================================================================
// Codec: <YOUR DEVICE NAME>
// Payload Uplink:
//   [TODO: describe byte layout — e.g., byte 0-1 = temperature x100, ...]
// Payload Downlink:
//   [TODO: describe byte layout — e.g., byte 0 = command, byte 1 = value, ...]
// =============================================================================

function decodeUplink(input) {
  var bytes = input.bytes;

  if (bytes.length < 1) {
    return { errors: ["payload too short: expected 1+ bytes, got " + bytes.length] };
  }

  // TODO: extract fields from payload
  // Example (big-endian 16-bit): var value = (bytes[0] << 8) | bytes[1];

  return {
    data: {
      // TODO: return decoded fields
      // example: temperature_c: rawTemp / 100.0,
      // example: battery_mv: rawBattery
    }
  };
}

function encodeDownlink(input) {
  var data = input.data;

  // TODO: convert fields to bytes
  // Example: var cmd = data.command || 0;

  return {
    bytes: [
      // TODO: return byte array
    ]
  };
}

function decodeDownlink(input) {
  var bytes = input.bytes;

  if (bytes.length < 1) {
    return { errors: ["downlink payload too short: expected 1+ bytes, got " + bytes.length] };
  }

  // TODO: decode downlink payload (inverse of encodeDownlink)

  return {
    data: {
      // TODO: return decoded fields
    }
  };
}
```

### Example: Thermal Sensor (decode only, 6 bytes)

```
Uplink (6 bytes, big-endian):
  Byte 0-1: temperature x100 (int16, signed) — e.g., 2345 = 23.45 C
  Byte 2:   humidity (uint8, %)               — e.g., 65 = 65%
  Byte 3-4: battery mV (uint16)               — e.g., 3700 = 3.700 V
  Byte 5:   status flags (uint8, bitmask)
            bit 0: sensor_fault
            bit 1: low_battery
            bit 2: first_boot
```

```javascript
function decodeUplink(input) {
  var bytes = input.bytes;

  if (bytes.length < 6) {
    return { errors: ["payload too short: expected 6 bytes, got " + bytes.length] };
  }

  var tempRaw = (bytes[0] << 8) | bytes[1];
  if (tempRaw > 0x7FFF) {
    tempRaw = tempRaw - 0x10000;
  }

  var humidity = bytes[2];
  var batteryMv = (bytes[3] << 8) | bytes[4];
  var statusFlags = bytes[5];

  return {
    data: {
      temperature_c: tempRaw / 100.0,
      temperature_raw: tempRaw,
      humidity_pct: humidity,
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      sensor_fault: (statusFlags & 0x01) !== 0,
      low_battery: (statusFlags & 0x02) !== 0,
      first_boot: (statusFlags & 0x04) !== 0
    }
  };
}
```

### Example: Bidirectional Actuator (5-byte uplink, 3-byte downlink)

```
Uplink (5 bytes, big-endian):
  Byte 0:   actuator status (uint8) — 0x00=idle, 0x01=running, 0x02=fault, 0x03=manual
  Byte 1:   current position % (uint8, 0-100)
  Byte 2-3: supply voltage mV (uint16)
  Byte 4:   flags (uint8, bitmask)
            bit 0: watchdog_ok
            bit 1: overtemp
            bit 2: position_reached

Downlink (3 bytes, big-endian):
  Byte 0:   command code (uint8) — 0x01=set_position, 0x02=stop, 0x03=reset_fault
  Byte 1-2: argument (uint16) — meaning depends on command
            set_position: target 0-100 (byte 1), speed % (byte 2)
            stop/reset_fault: ignored (send 0x00, 0x00)
```

```javascript
var CMD_SET_POSITION = 0x01;
var CMD_STOP = 0x02;
var CMD_RESET_FAULT = 0x03;

var STATUS_NAMES = {};
STATUS_NAMES[0x00] = "idle";
STATUS_NAMES[0x01] = "running";
STATUS_NAMES[0x02] = "fault";
STATUS_NAMES[0x03] = "manual";

var CMD_NAMES = {};
CMD_NAMES[CMD_SET_POSITION] = "set_position";
CMD_NAMES[CMD_STOP] = "stop";
CMD_NAMES[CMD_RESET_FAULT] = "reset_fault";

function decodeUplink(input) {
  var bytes = input.bytes;

  if (bytes.length < 5) {
    return { errors: ["payload too short: expected 5 bytes, got " + bytes.length] };
  }

  var status = bytes[0];
  var positionPct = bytes[1];
  var supplyMv = (bytes[2] << 8) | bytes[3];
  var flags = bytes[4];

  return {
    data: {
      status: status,
      status_name: STATUS_NAMES[status] || "unknown",
      position_pct: positionPct,
      supply_mv: supplyMv,
      supply_v: supplyMv / 1000.0,
      watchdog_ok: (flags & 0x01) !== 0,
      overtemp: (flags & 0x02) !== 0,
      position_reached: (flags & 0x04) !== 0
    }
  };
}

function encodeDownlink(input) {
  var data = input.data;
  var command = data.command || "stop";
  var cmdByte = CMD_STOP;

  if (command === "set_position" || command === CMD_SET_POSITION) {
    cmdByte = CMD_SET_POSITION;
  } else if (command === "stop" || command === CMD_STOP) {
    cmdByte = CMD_STOP;
  } else if (command === "reset_fault" || command === CMD_RESET_FAULT) {
    cmdByte = CMD_RESET_FAULT;
  }

  var arg1 = 0;
  var arg2 = 0;

  if (cmdByte === CMD_SET_POSITION) {
    arg1 = data.position || 0;
    arg2 = data.speed || 100;
  }

  return {
    bytes: [cmdByte, arg1 & 0xFF, arg2 & 0xFF]
  };
}

function decodeDownlink(input) {
  var bytes = input.bytes;

  if (bytes.length < 3) {
    return { errors: ["downlink payload too short: expected 3 bytes, got " + bytes.length] };
  }

  var cmdByte = bytes[0];
  var result = {
    command: CMD_NAMES[cmdByte] || "unknown",
    command_code: cmdByte
  };

  if (cmdByte === CMD_SET_POSITION) {
    result.position = bytes[1];
    result.speed = bytes[2];
  }

  return { data: result };
}
```

### Common Codec Patterns

```javascript
// 16-bit unsigned big-endian
var val = (bytes[0] << 8) | bytes[1];

// 16-bit signed big-endian
var val = (bytes[0] << 8) | bytes[1];
if (val > 0x7FFF) { val = val - 0x10000; }

// 32-bit unsigned big-endian
var val = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

// Bitmask flags
var flags = bytes[N];
var flag_a = (flags & 0x01) !== 0;  // bit 0
var flag_b = (flags & 0x02) !== 0;  // bit 1
var flag_c = (flags & 0x04) !== 0;  // bit 2

// Fixed-point scaling
var temp_c = rawTemp / 100.0;       // 2345 -> 23.45
var battery_v = battery_mv / 1000.0; // 3700 -> 3.700

// fPort routing
function decodeUplink(input) {
  var bytes = input.bytes;
  if (input.fPort === 1) {
    return { data: { type: "telemetry" /* ... */ } };
  } else if (input.fPort === 2) {
    return { data: { type: "status" /* ... */ } };
  }
  return { errors: ["unknown fPort: " + input.fPort] };
}
```

---

## 5. Device Profiles

Device profiles define LoRaWAN behavior (class, codec, intervals). Import via REST API or create manually in the Web UI.

### Class A — Sensor (battery-powered, periodic TX, sleeps between transmissions)

```json
{
  "deviceProfile": {
    "name": "<YOUR-PROJECT>-ClassA-Sensor-OTAA",
    "description": "Class A sensor, OTAA, battery-optimized",
    "region": "US915",
    "macVersion": "LORAWAN_1_0_3",
    "regParamsRevision": "A",
    "adrAlgorithmId": "default",
    "supportsOtaa": true,
    "supportsClassB": false,
    "supportsClassC": false,
    "payloadCodecRuntime": "JS",
    "payloadCodecScript": "<PASTE YOUR CODEC JS HERE>",
    "uplinkInterval": 60,
    "flushQueueOnActivate": true,
    "autoDetectMeasurements": true
  }
}
```

### Class C — Actuator (external power, always-on RX window, receives commands anytime)

```json
{
  "deviceProfile": {
    "name": "<YOUR-PROJECT>-ClassC-Actuator-OTAA",
    "description": "Class C actuator, OTAA, always-listening",
    "region": "US915",
    "macVersion": "LORAWAN_1_0_3",
    "regParamsRevision": "A",
    "adrAlgorithmId": "default",
    "supportsOtaa": true,
    "supportsClassB": false,
    "supportsClassC": true,
    "classCTimeout": 300,
    "payloadCodecRuntime": "JS",
    "payloadCodecScript": "<PASTE YOUR CODEC JS HERE>",
    "uplinkInterval": 60,
    "flushQueueOnActivate": true,
    "autoDetectMeasurements": true
  }
}
```

### Key Fields

| Field | Meaning |
|-------|---------|
| `macVersion` | Always `LORAWAN_1_0_3` for this gateway |
| `region` | Always `US915` |
| `supportsClassC` | `true` for actuators that need to receive commands anytime |
| `classCTimeout` | Seconds before Class C session times out (only if `supportsClassC: true`) |
| `uplinkInterval` | Expected seconds between uplinks (used for device-offline detection) |
| `payloadCodecScript` | Full JavaScript codec pasted inline |
| `flushQueueOnActivate` | Clear pending downlinks on OTAA re-join (prevents stale commands) |

### Import via REST API

```bash
curl -X POST http://<LORACORE_HOST>:8090/api/device-profiles \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d @my-device-profile.json
```

---

## 6. Device Credentials & Registration

### Generate Credentials

```bash
# DevEUI: 8-byte unique device identifier
openssl rand -hex 8
# Example output: 3daa1dd8e5ceb357

# AppKey: 16-byte OTAA encryption key
openssl rand -hex 16
# Example output: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
```

### Register Device via REST API

```bash
API="http://<LORACORE_HOST>:8090/api"
TOKEN="<YOUR_API_TOKEN>"
AUTH="Grpc-Metadata-Authorization: Bearer $TOKEN"

DEV_EUI="<GENERATED_DEV_EUI>"
APP_KEY="<GENERATED_APP_KEY>"
APP_ID="<YOUR_APPLICATION_ID>"       # UUID from ChirpStack
PROFILE_ID="<YOUR_DEVICE_PROFILE_ID>" # UUID from ChirpStack

# 1. Create device
curl -X POST "$API/devices" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"device\": {
      \"devEui\": \"$DEV_EUI\",
      \"name\": \"my-sensor-01\",
      \"applicationId\": \"$APP_ID\",
      \"deviceProfileId\": \"$PROFILE_ID\",
      \"isDisabled\": false,
      \"skipFcntCheck\": false
    }
  }"

# 2. Set OTAA keys
curl -X POST "$API/devices/$DEV_EUI/keys" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"deviceKeys\": {
      \"devEui\": \"$DEV_EUI\",
      \"nwkKey\": \"$APP_KEY\",
      \"appKey\": \"$APP_KEY\"
    }
  }"
```

### Firmware Credential Parameters

These values must be programmed into the device firmware:

| Parameter | Value | Notes |
|-----------|-------|-------|
| DevEUI | 8 bytes | Must match ChirpStack registration |
| AppKey | 16 bytes | Must match ChirpStack registration |
| JoinEUI (AppEUI) | `0x0000000000000000` | All zeros for ChirpStack v4 |
| Region | US915 | Hardcoded |
| Sub-band | 1 | Channel mask: `0x00FF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000` |
| Activation | OTAA | ABP is not supported |

---

## 7. MQTT Integration (Real-time Data)

### Connection

| Parameter | Value |
|-----------|-------|
| Host | `<LORACORE_HOST>` |
| Port | `1883` |
| Authentication | None (`allow_anonymous true`) |
| QoS | 1 (at-least-once) |
| clean_session | `false` (preserves queue during reconnection) |

### Application Topics

| Topic | Event | Description |
|-------|-------|-------------|
| `application/<app_id>/device/<dev_eui>/event/up` | Uplink | Decoded device data |
| `application/<app_id>/device/<dev_eui>/event/join` | Join | OTAA join notification |
| `application/<app_id>/device/<dev_eui>/event/status` | Status | Link margin + battery level |
| `application/<app_id>/device/<dev_eui>/event/ack` | ACK | Downlink delivery confirmation |
| `application/<app_id>/device/<dev_eui>/event/log` | Log | Raw frame log |

**Useful wildcards:**

```
application/<app_id>/device/+/event/up    # All uplinks from one application
application/<app_id>/device/<dev_eui>/event/#  # All events from one device
application/+/device/+/event/up           # All uplinks from all applications
```

### Uplink JSON Schema

```json
{
  "deduplicationId": "a1b2c3d4-...",
  "time": "2026-03-29T14:30:00.123Z",
  "deviceInfo": {
    "tenantId": "6ab88d75-...",
    "tenantName": "ChirpStack",
    "applicationId": "e7e90971-...",
    "applicationName": "my-application",
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

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `deviceInfo.devEui` | string | Unique device identifier |
| `deviceInfo.deviceName` | string | Human-readable device name |
| `fPort` | int | LoRaWAN port (identifies payload type) |
| `fCnt` | int | Frame counter (sequential, detects packet loss) |
| `dr` | int | Data rate used (DR0-DR5) |
| `data` | string | Raw payload in base64 (before codec) |
| `object` | object | **Decoded data from codec — this is the primary field for consumption** |
| `rxInfo[].rssi` | int | Signal power in dBm |
| `rxInfo[].snr` | float | Signal-to-noise ratio in dB |
| `time` | string | ISO 8601 timestamp |

### Join Event JSON

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

An unexpected join may indicate device reset or session loss.

### Status Event JSON

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

### ACK Event JSON

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

**Important:** ACK confirms the frame reached the device, NOT that the command was executed. For execution confirmation, the firmware must send an uplink confirming the action.

### Python MQTT Subscriber

```python
import json
import paho.mqtt.client as mqtt

BROKER = "<LORACORE_HOST>"
PORT = 1883
TOPIC = "application/+/device/+/event/up"

def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT broker (rc={rc})")
    client.subscribe(TOPIC, qos=1)

def on_message(client, userdata, msg):
    payload = json.loads(msg.payload.decode())
    dev_eui = payload["deviceInfo"]["devEui"]
    device_name = payload["deviceInfo"]["deviceName"]
    data = payload.get("object", {})
    rssi = payload["rxInfo"][0]["rssi"] if payload.get("rxInfo") else None

    print(f"[{device_name}] devEui={dev_eui} RSSI={rssi}dBm data={data}")

    # Your logic here:
    # - Store in database
    # - Check thresholds and trigger alerts
    # - Forward to dashboard

client = mqtt.Client(client_id="my-backend", clean_session=False)
client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, keepalive=60)
client.loop_forever()
```

**Dependency:** `pip install paho-mqtt`

### Recommended Consumption Pattern

1. Connect to Mosquitto with QoS 1 and `clean_session=false`
2. Subscribe to: `application/+/device/+/event/up`
3. For each message: parse JSON → route by `devEui` or `fPort` → extract data from `object`
4. Handle automatic reconnection (broker preserves the queue)

---

## 8. REST API (Device Management)

**Base URL:** `http://<LORACORE_HOST>:8090/api`

### Authentication

Generate API key:

```bash
ssh <USER>@<LORACORE_HOST> "sudo chirpstack -c /etc/chirpstack create-api-key --name my-backend"
```

Include in every request:

```
Header: Grpc-Metadata-Authorization: Bearer <TOKEN>
```

### Device Operations

```bash
# List devices
curl -s http://<LORACORE_HOST>:8090/api/devices?limit=100&applicationId=<APP_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"

# Create device
curl -X POST http://<LORACORE_HOST>:8090/api/devices \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "device": {
      "devEui": "<DEV_EUI>",
      "name": "sensor-01",
      "applicationId": "<APP_ID>",
      "deviceProfileId": "<PROFILE_ID>",
      "isDisabled": false,
      "skipFcntCheck": false
    }
  }'

# Set OTAA keys
curl -X POST http://<LORACORE_HOST>:8090/api/devices/<DEV_EUI>/keys \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceKeys": {
      "devEui": "<DEV_EUI>",
      "nwkKey": "<APP_KEY>",
      "appKey": "<APP_KEY>"
    }
  }'

# Get device
curl -s http://<LORACORE_HOST>:8090/api/devices/<DEV_EUI> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"

# Delete device
curl -X DELETE http://<LORACORE_HOST>:8090/api/devices/<DEV_EUI> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"

# Enqueue downlink
curl -X POST http://<LORACORE_HOST>:8090/api/devices/<DEV_EUI>/queue \
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

# List downlink queue
curl -s http://<LORACORE_HOST>:8090/api/devices/<DEV_EUI>/queue \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"
```

### Application Operations

```bash
# List applications
curl -s http://<LORACORE_HOST>:8090/api/applications?limit=100&tenantId=<TENANT_ID> \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>"

# Create application
curl -X POST http://<LORACORE_HOST>:8090/api/applications \
  -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "application": {
      "name": "my-project",
      "tenantId": "<TENANT_ID>"
    }
  }'
```

---

## 9. gRPC API (Production Downlinks)

For production backends that send downlinks frequently. gRPC offers native typing (Protobuf), lower overhead than REST, and auto-generated stubs.

### Connection

| Parameter | Value |
|-----------|-------|
| Host | `<LORACORE_HOST>` |
| Port | `8080` (shared with Web UI) |
| Protocol | gRPC over HTTP/2 (insecure on local network) |
| Python package | `chirpstack-api` |
| Authentication | Bearer token via gRPC metadata |

**Dependencies:** `pip install chirpstack-api grpcio`

### Enqueue Downlink (sync)

```python
import grpc
from chirpstack_api import api as chirpstack_api

CHIRPSTACK_GRPC = "<LORACORE_HOST>:8080"
API_TOKEN = "<YOUR_TOKEN>"

channel = grpc.insecure_channel(CHIRPSTACK_GRPC)
device_service = chirpstack_api.DeviceServiceStub(channel)
metadata = [("authorization", f"Bearer {API_TOKEN}")]

request = chirpstack_api.EnqueueDeviceQueueItemRequest(
    queue_item=chirpstack_api.DeviceQueueItem(
        dev_eui="<DEV_EUI>",
        confirmed=False,
        f_port=2,
        data=bytes([0x01, 0x02]),
    )
)

response = device_service.Enqueue(request, metadata=metadata)
print(f"Downlink enqueued: id={response.id}")
channel.close()
```

### Enqueue Downlink (async, for FastAPI/aiohttp)

```python
import grpc.aio
from chirpstack_api import api as chirpstack_api

CHIRPSTACK_GRPC = "<LORACORE_HOST>:8080"
API_TOKEN = "<YOUR_TOKEN>"

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

### Flush and Query Queue

```python
# Flush pending downlinks
flush_req = chirpstack_api.FlushDeviceQueueRequest(dev_eui="<DEV_EUI>")
device_service.FlushQueue(flush_req, metadata=metadata)

# Query current queue
list_req = chirpstack_api.GetDeviceQueueItemsRequest(dev_eui="<DEV_EUI>")
queue = device_service.GetQueue(list_req, metadata=metadata)
for item in queue.result:
    print(f"  fPort={item.f_port} confirmed={item.confirmed} pending={item.is_pending}")
```

### gRPC vs REST

| Aspect | REST API (`:8090`) | gRPC (`:8080`) |
|--------|-------------------|----------------|
| Simplicity | `curl` / `requests` | Requires `chirpstack-api` |
| Performance | HTTP/1.1 + JSON | HTTP/2 + Protobuf |
| Typing | Dynamic JSON | Protobuf stubs |
| Best for | Scripts, simple automation | Production backends, high volume |
| Streaming | No | Supported |

**Recommendation:** REST for scripts and prototypes, gRPC for production backends.

---

## 10. Firmware Guidelines

### Build System

PlatformIO is the standard build system.

```ini
; platformio.ini example
[env:my-device]
platform = heltec-cubecell   ; or platform for your MCU
board = cubecell_board        ; or your board
framework = arduino
monitor_speed = 115200
```

```bash
pio run              # compile
pio run -t upload    # compile + flash
pio device monitor --baud 115200  # serial monitor
```

### LoRaWAN Configuration Block (C++ / Arduino)

```cpp
#include "LoRaWan_APP.h"

/* OTAA credentials — must match ChirpStack registration */
uint8_t devEui[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x01 };
uint8_t appEui[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };  /* all zeros for ChirpStack v4 */
uint8_t appKey[] = { 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0xA7, 0xB8,
                     0xC9, 0xD0, 0xE1, 0xF2, 0xA3, 0xB4, 0xC5, 0xD6 };

/* ABP placeholders (not used with OTAA) */
uint8_t nwkSKey[] = { 0 };
uint8_t appSKey[] = { 0 };
uint32_t devAddr  = 0;

/* US915 Sub-band 1 (channels 0-7) */
uint16_t userChannelsMask[6] = { 0x00FF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000 };

/* LoRaWAN config */
LoRaMacRegion_t loraWanRegion = LORAMAC_REGION_US915;
DeviceClass_t   loraWanClass  = CLASS_A;       /* CLASS_A for sensors, CLASS_C for actuators */
bool     overTheAirActivation = true;
bool     loraWanAdr           = false;
bool     keepNet              = false;
bool     isTxConfirmed        = false;          /* use unconfirmed for telemetry */
uint8_t  confirmedNbTrials    = 4;
uint8_t  appPort              = 2;              /* fPort for your payload */
uint32_t appTxDutyCycle       = 60000;          /* TX interval in ms */
```

### Payload Construction (big-endian)

```cpp
static void prepareTxFrame(uint8_t port) {
    uint16_t batteryVoltage = getBatteryVoltage();
    uint16_t uptime = (uint16_t)(millis() / 1000);

    appDataSize = 4;
    appData[0] = (uint8_t)(batteryVoltage >> 8);   /* battery MSB */
    appData[1] = (uint8_t)(batteryVoltage);         /* battery LSB */
    appData[2] = (uint8_t)(uptime >> 8);            /* uptime MSB */
    appData[3] = (uint8_t)(uptime);                 /* uptime LSB */
}
```

### Downlink Handling (Class C)

```cpp
void downLinkDataHandle(McpsIndication_t *mcpsIndication) {
    uint8_t port = mcpsIndication->Port;
    uint8_t *buf = mcpsIndication->Buffer;
    uint8_t size = mcpsIndication->BufferSize;

    Serial.printf("RX port=%d size=%d\r\n", port, size);

    if (port == 2 && size >= 1) {
        uint8_t command = buf[0];
        // Process command...
        // Send uplink confirming execution (application-layer ACK)
    }
}
```

### Class A State Machine

```cpp
void loop() {
    switch (deviceState) {
        case DEVICE_STATE_INIT:
            LoRaWAN.init(loraWanClass, loraWanRegion);
            deviceState = DEVICE_STATE_JOIN;
            break;
        case DEVICE_STATE_JOIN:
            LoRaWAN.join();
            break;
        case DEVICE_STATE_SEND:
            prepareTxFrame(appPort);
            LoRaWAN.send();
            deviceState = DEVICE_STATE_CYCLE;
            break;
        case DEVICE_STATE_CYCLE:
            txDutyCycleTime = appTxDutyCycle + randr(0, APP_TX_DUTYCYCLE_RND);
            LoRaWAN.cycle(txDutyCycleTime);
            deviceState = DEVICE_STATE_SLEEP;
            break;
        case DEVICE_STATE_SLEEP:
            LoRaWAN.sleep();
            break;
        default:
            deviceState = DEVICE_STATE_INIT;
            break;
    }
}
```

### Firmware Resilience Rules

When writing firmware that interacts with peripherals, communication, or I/O:

1. **Timeout:** every I/O operation must have an explicit timeout (Wire, SPI, Serial, LoRa)
2. **Limited retry:** reconnections/re-reads must have a defined maximum — no infinite loops
3. **Fallback:** define behavior when a peripheral does not respond (last valid value, error flag, skip cycle)
4. **Watchdog:** main loop must feed the watchdog — if it hangs, automatic reset
5. **Status flag:** failures must be recorded in a state variable accessible for diagnostics (serial, LoRa payload, LED)

**When NOT to apply:**
- Periodic non-critical reads with short cycle (< 1 min) — the next read is the natural retry
- One-shot initialization where failure = abort is acceptable (e.g., `while(!sensor.begin())` with watchdog as backstop)

**Anti-patterns:**
- Infinite retry without watchdog = bricked device
- `delay()` as timeout = blocks entire system
- Silencing errors without a flag = invisible failure

### Confirmed vs Unconfirmed

- **Use unconfirmed for telemetry** — saves bandwidth and airtime, the next uplink is the natural retry
- **Use confirmed only for critical commands** — confirmed uplinks degrade throughput under stress
- Class A: device can only receive downlinks in the short RX windows after an uplink
- Class C: device listens continuously — downlinks are delivered immediately

---

## 11. Invariants (Non-negotiable Rules)

1. **US915 sub-band 1, OTAA, ChirpStack v4** — baseline non-negotiable
2. **Firmware must compile** (`pio run`) before any claim of completion
3. **100% offline operation** — no internet dependency
4. **Docs-as-Code** — behavior change requires documentation update
5. **Hardware-first** — hardware tasks are blocked until physical inspection
6. **Generic templates with placeholders** — never hardcoded credential values
7. **JavaScript codecs follow** `function decodeUplink(input)` **standard** (ChirpStack v4)

### Additional Integration Invariants

8. **MQTT QoS 1** and `clean_session=false` for all subscribers — ensures at-least-once delivery
9. **ES5 JavaScript only** in codecs — no modern JS features
10. **Big-endian byte order** for payload encoding — unless explicitly documented otherwise
11. **Unconfirmed uplinks for telemetry** — confirmed only for critical actuator commands
12. **Codec errors return `{ errors: [...] }`** — never silent `{ data: {} }`
13. **Both nwkKey and appKey set to the same value** when registering device keys (LoRaWAN 1.0.3)

---

## 12. Integration Checklist

### Infrastructure Setup

- [ ] LoRaCore gateway running (all 7 services healthy)
- [ ] ChirpStack Web UI accessible at `http://<LORACORE_HOST>:8080`
- [ ] API token generated

### Device Configuration

- [ ] Application created in ChirpStack
- [ ] Device profile created with JavaScript codec
- [ ] Codec tested locally with Node.js
- [ ] DevEUI and AppKey generated (`openssl rand -hex 8` / `openssl rand -hex 16`)
- [ ] Device registered via REST API or Web UI
- [ ] OTAA keys set (nwkKey = appKey = your AppKey)

### Firmware

- [ ] Firmware compiles (`pio run`)
- [ ] DevEUI, AppKey, AppEUI (all zeros), channel mask (`0x00FF,...`) configured
- [ ] Region set to `LORAMAC_REGION_US915`
- [ ] Payload construction uses big-endian byte order
- [ ] fPort set to match codec expectations
- [ ] Device completes OTAA join (visible in ChirpStack logs)
- [ ] Uplinks visible in ChirpStack Web UI with decoded `object` field

### Backend

- [ ] MQTT subscriber connected to `:1883` with QoS 1 and `clean_session=false`
- [ ] Subscribed to `application/<app_id>/device/+/event/up`
- [ ] JSON parsing extracts data from `object` field
- [ ] Downlink sending works via REST (`:8090`) or gRPC (`:8080`)
- [ ] Offline device detection implemented (2.5× expected uplink interval)

### Actuators (if applicable)

- [ ] Device profile has `supportsClassC: true`
- [ ] Firmware handles `downLinkDataHandle` callback
- [ ] Application-layer ACK: firmware sends uplink confirming command execution
- [ ] Backend implements ACK tracking with timeout + retry

---

## 13. Quick Reference

### Placeholders

| Placeholder | Description | How to obtain |
|-------------|-------------|---------------|
| `<LORACORE_HOST>` | RPi5 IP/hostname | Network scan or static assignment |
| `<TOKEN>` | ChirpStack API token | Web UI > API Keys, or `chirpstack create-api-key` |
| `<APP_ID>` | Application UUID | REST API or Web UI |
| `<PROFILE_ID>` | Device Profile UUID | REST API or Web UI |
| `<TENANT_ID>` | Tenant UUID | REST API or Web UI (default tenant) |
| `<DEV_EUI>` | Device identifier (8-byte hex) | `openssl rand -hex 8` |
| `<APP_KEY>` | OTAA key (16-byte hex) | `openssl rand -hex 16` |

### Capacity Limits (RPi5)

| Resource | Comfortable limit |
|----------|------------------|
| Simultaneous devices | 200-500 (depends on TX interval) |
| Uplinks/minute | 100-200 |
| Applications | No practical limit |
| MQTT subscribers | Dozens |
