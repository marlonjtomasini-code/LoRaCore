// =============================================================================
// Template: Codec ChirpStack v4 — Sensor Termico Industrial (exemplo)
// Referencia: templates/codecs/README.md
// Destino: Device Profile > Codec tab no ChirpStack
//
// Payload Uplink (6 bytes, big-endian):
//   Byte 0-1: temperatura x100 (int16, signed) — ex: 2345 = 23.45 C
//   Byte 2:   umidade relativa (uint8, %)       — ex: 65 = 65%
//   Byte 3-4: tensao bateria em mV (uint16)     — ex: 3700 = 3.700 V
//   Byte 5:   flags de status (uint8, bitmask)
//             bit 0: sensor_fault (leitura invalida)
//             bit 1: low_battery (abaixo do threshold)
//             bit 2: first_boot (primeira transmissao apos reset)
//
// Este codec implementa apenas decodeUplink (sensor unidirecional).
// Para dispositivos bidirecionais, veja example-actuator-bidirectional.js.
// =============================================================================

function decodeUplink(input) {
  var bytes = input.bytes;

  if (bytes.length < 6) {
    return { errors: ["payload too short: expected 6 bytes, got " + bytes.length] };
  }

  // Temperatura: int16 signed big-endian (x100)
  var tempRaw = (bytes[0] << 8) | bytes[1];
  if (tempRaw > 0x7FFF) {
    tempRaw = tempRaw - 0x10000; // converter para signed
  }

  // Umidade: uint8
  var humidity = bytes[2];

  // Bateria: uint16 big-endian (mV)
  var batteryMv = (bytes[3] << 8) | bytes[4];

  // Flags de status: uint8 bitmask
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
