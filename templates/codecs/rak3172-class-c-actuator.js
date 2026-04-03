// Template LoRaCore — Codec ChirpStack: RAK3172 Class C Actuator
// Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 12.4
//
// Uplink payload: [battery_mv_hi, battery_mv_lo, status, gpio_state]
// Downlink payload: [command, value]
// Usar no Device Profile do ChirpStack como "Codec functions"

// Decode uplink
function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) return { errors: ["payload too short: expected 4 bytes, got " + bytes.length] };
  var batteryMv = (bytes[0] << 8) | bytes[1];
  var status = bytes[2];
  var gpioState = bytes[3];
  return {
    data: {
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      status: status,
      gpio_state: gpioState
    }
  };
}

// Encode downlink (servidor -> device)
function encodeDownlink(input) {
  var cmd = (input.data.command || 0) & 0xFF;
  var val = (input.data.value || 0) & 0xFF;
  return { bytes: [cmd, val] };
}
