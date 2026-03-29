// Test: rak3172-class-c-actuator.js
// Uplink: [battery_mv_hi, battery_mv_lo, status, gpio_state]
// Downlink: [command, value]
var assert = require("assert");
var fs = require("fs");
var path = require("path");

eval(fs.readFileSync(path.join(__dirname, "..", "rak3172-class-c-actuator.js"), "utf8"));

// === decodeUplink ===

// --- decode com payload valido ---
var result = decodeUplink({ bytes: [0x0E, 0x74, 0x01, 0xFF], fPort: 1 });
assert.strictEqual(result.data.battery_mv, 3700);
assert.strictEqual(result.data.battery_v, 3.7);
assert.strictEqual(result.data.status, 1);
assert.strictEqual(result.data.gpio_state, 255);
assert(!result.errors);

// --- decode com zeros ---
var result2 = decodeUplink({ bytes: [0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(result2.data.battery_mv, 0);
assert.strictEqual(result2.data.status, 0);
assert.strictEqual(result2.data.gpio_state, 0);

// --- error handling: payload curto ---
var err1 = decodeUplink({ bytes: [0x0E], fPort: 1 });
assert(err1.errors);
assert(err1.errors[0].indexOf("too short") !== -1);

// === encodeDownlink ===

// --- encode comando basico ---
var enc1 = encodeDownlink({ data: { command: 5, value: 100 } });
assert.deepStrictEqual(enc1.bytes, [5, 100]);

// --- encode com defaults (command=0, value=0) ---
var enc2 = encodeDownlink({ data: {} });
assert.deepStrictEqual(enc2.bytes, [0, 0]);

// --- roundtrip: encode -> decode uplink nao se aplica (formatos diferentes) ---
// Mas podemos verificar que encode produz bytes coerentes
var enc3 = encodeDownlink({ data: { command: 0x01, value: 0xFF } });
assert.strictEqual(enc3.bytes[0], 1);
assert.strictEqual(enc3.bytes[1], 255);

console.log("PASS rak3172-class-c-actuator");
