// Test: cubecell-stress-test-device2.js
// Payload: 14 bytes
// [deviceId(1)] [bat(2)] [txCount(4)] [uptime(4)] [rxCount(2)] [ackCount(1)]
var assert = require("assert");
var fs = require("fs");
var path = require("path");

eval(fs.readFileSync(path.join(__dirname, "..", "cubecell-stress-test-device2.js"), "utf8"));

// --- decode com payload valido ---
// deviceId=2, battery=3700(0x0E74), txCount=100(0x00000064),
// uptime=3600(0x00000E10), rxCount=50(0x0032), ackCount=45
var payload = [0x02, 0x0E, 0x74, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x0E, 0x10, 0x00, 0x32, 0x2D];
var result = decodeUplink({ bytes: payload, fPort: 1 });
assert.strictEqual(result.data.device_id, 2);
assert.strictEqual(result.data.battery_mv, 3700);
assert.strictEqual(result.data.battery_v, 3.7);
assert.strictEqual(result.data.tx_count, 100);
assert.strictEqual(result.data.uptime_s, 3600);
assert.strictEqual(result.data.rx_count, 50);
assert.strictEqual(result.data.ack_count, 45);
assert(!result.errors);

// --- decode com zeros ---
var zeros = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
var result2 = decodeUplink({ bytes: zeros, fPort: 1 });
assert.strictEqual(result2.data.device_id, 0);
assert.strictEqual(result2.data.tx_count, 0);

// --- error handling: payload curto ---
var err1 = decodeUplink({ bytes: [0x02, 0x0E, 0x74], fPort: 1 });
assert(err1.errors);
assert(err1.errors[0].indexOf("too short") !== -1);

// --- error handling: payload vazio ---
var err2 = decodeUplink({ bytes: [], fPort: 1 });
assert(err2.errors);

// === Valores maximos uint32 ===

// --- todos os bytes 0xFF ---
var maxPayload = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
var maxResult = decodeUplink({ bytes: maxPayload, fPort: 1 });
assert.strictEqual(maxResult.data.device_id, 255);
assert.strictEqual(maxResult.data.battery_mv, 65535, "max uint16 battery");
assert.strictEqual(maxResult.data.tx_count, 4294967295, "max uint32 tx_count");
assert.strictEqual(maxResult.data.uptime_s, 4294967295, "max uint32 uptime");
assert.strictEqual(maxResult.data.rx_count, 65535, "max uint16 rx_count");
assert.strictEqual(maxResult.data.ack_count, 255, "max uint8 ack_count");

// === Integracao: simula payload real do firmware device2.cpp ===

// --- firmware envia: id=2, bat=3300, tx=1000, up=7200, rx=500, ack=200 ---
// bat: 0x0CE4, tx: 0x000003E8, up: 0x00001C20, rx: 0x01F4, ack: 0xC8
var fwPayload = [0x02, 0x0C, 0xE4, 0x00, 0x00, 0x03, 0xE8, 0x00, 0x00, 0x1C, 0x20, 0x01, 0xF4, 0xC8];
var fwResult = decodeUplink({ bytes: fwPayload, fPort: 1 });
assert.strictEqual(fwResult.data.device_id, 2);
assert.strictEqual(fwResult.data.battery_mv, 3300);
assert.strictEqual(fwResult.data.tx_count, 1000);
assert.strictEqual(fwResult.data.uptime_s, 7200);
assert.strictEqual(fwResult.data.rx_count, 500);
assert.strictEqual(fwResult.data.ack_count, 200);

console.log("PASS cubecell-stress-test-device2");
