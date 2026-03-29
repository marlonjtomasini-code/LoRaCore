// Template LoRaCore — Codec ChirpStack: CubeCell Class A Sensor
// Fonte: docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md, Secao 12.4
//
// Payload: [battery_mv_hi, battery_mv_lo, uptime_hi, uptime_lo]
// Usar no Device Profile do ChirpStack como "Codec functions"

function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) return { errors: ["payload too short: expected 4 bytes, got " + bytes.length] };
  var batteryMv = (bytes[0] << 8) | bytes[1];
  var uptimeSec = (bytes[2] << 8) | bytes[3];
  return {
    data: {
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      uptime_s: uptimeSec
    }
  };
}
