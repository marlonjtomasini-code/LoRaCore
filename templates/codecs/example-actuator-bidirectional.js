// =============================================================================
// Template: Codec ChirpStack v4 — Atuador Bidirecional Industrial (exemplo)
// Referencia: templates/codecs/README.md
// Destino: Device Profile > Codec tab no ChirpStack
//
// Payload Uplink (5 bytes, big-endian):
//   Byte 0:   status do atuador (uint8)
//             0x00 = idle, 0x01 = running, 0x02 = fault, 0x03 = manual
//   Byte 1:   posicao atual em % (uint8, 0-100)
//   Byte 2-3: tensao bateria/fonte em mV (uint16)
//   Byte 4:   flags (uint8, bitmask)
//             bit 0: watchdog_ok (heartbeat recente)
//             bit 1: overtemp (protecao termica ativa)
//             bit 2: position_reached (posicao alvo atingida)
//
// Payload Downlink (3 bytes, big-endian):
//   Byte 0:   codigo do comando (uint8)
//             0x01 = set_position, 0x02 = stop, 0x03 = reset_fault
//   Byte 1-2: argumento (uint16) — significado depende do comando
//             set_position: posicao alvo 0-100 (byte 1), velocidade % (byte 2)
//             stop/reset_fault: ignorado (enviar 0x00, 0x00)
//
// Este codec implementa as tres funcoes: decodeUplink, encodeDownlink,
// decodeDownlink. Para sensores unidirecionais, veja example-thermal-sensor.js.
// =============================================================================

// --- Constantes de comando ---
var CMD_SET_POSITION = 0x01;
var CMD_STOP = 0x02;
var CMD_RESET_FAULT = 0x03;

// --- Constantes de status ---
var STATUS_IDLE = 0x00;
var STATUS_RUNNING = 0x01;
var STATUS_FAULT = 0x02;
var STATUS_MANUAL = 0x03;

// Mapa legivel de status
var STATUS_NAMES = {};
STATUS_NAMES[STATUS_IDLE] = "idle";
STATUS_NAMES[STATUS_RUNNING] = "running";
STATUS_NAMES[STATUS_FAULT] = "fault";
STATUS_NAMES[STATUS_MANUAL] = "manual";

// Mapa legivel de comandos
var CMD_NAMES = {};
CMD_NAMES[CMD_SET_POSITION] = "set_position";
CMD_NAMES[CMD_STOP] = "stop";
CMD_NAMES[CMD_RESET_FAULT] = "reset_fault";

// ---------------------------------------------------------------------------
// decodeUplink — Decodifica telemetria do atuador
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// encodeDownlink — Codifica comando para o atuador
//
// Exemplo de uso via REST API:
//   POST /api/devices/<DEV_EUI>/queue
//   { "queueItem": { "data": { "command": "set_position", "position": 75, "speed": 50 } } }
// ---------------------------------------------------------------------------
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
    arg1 = data.position || 0;  // posicao alvo 0-100
    arg2 = data.speed || 100;   // velocidade % (default: max)
  }

  return {
    bytes: [cmdByte, arg1 & 0xFF, arg2 & 0xFF]
  };
}

// ---------------------------------------------------------------------------
// decodeDownlink — Decodifica downlink para visualizacao/debug na web UI
// ---------------------------------------------------------------------------
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
