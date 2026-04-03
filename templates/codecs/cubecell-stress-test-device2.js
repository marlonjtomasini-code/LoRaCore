// Template LoRaCore — Codec ChirpStack: CubeCell Stress Test Device 2
// Fonte: examples/firmware/cubecell-otaa-test/src/device2.cpp
//
// Payload: 14 bytes
// [deviceId(1)] [bat(2)] [txCount(4)] [uptime(4)] [rxCount(2)] [ackCount(1)]
// Usar no Device Profile do ChirpStack como "Codec functions"

function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 14) return { errors: ["payload too short: expected 14 bytes, got " + bytes.length] };

  var batteryMv = ((bytes[1] << 8) | bytes[2]) & 0xFFFF;
  var txCount = ((bytes[3] << 24) | (bytes[4] << 16) | (bytes[5] << 8) | bytes[6]) >>> 0;
  var uptimeSec = ((bytes[7] << 24) | (bytes[8] << 16) | (bytes[9] << 8) | bytes[10]) >>> 0;
  var rxCount = ((bytes[11] << 8) | bytes[12]) & 0xFFFF;

  return {
    data: {
      device_id: bytes[0],
      battery_mv: batteryMv,
      battery_v: batteryMv / 1000.0,
      tx_count: txCount >>> 0,
      uptime_s: uptimeSec >>> 0,
      rx_count: rxCount,
      ack_count: bytes[13]
    }
  };
}
