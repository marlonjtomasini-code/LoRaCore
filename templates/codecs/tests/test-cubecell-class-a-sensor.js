// Test: cubecell-class-a-sensor.js
// Payload: [battery_mv_hi, battery_mv_lo, uptime_hi, uptime_lo]
var assert = require("assert");
var fs = require("fs");
var path = require("path");

eval(fs.readFileSync(path.join(__dirname, "..", "cubecell-class-a-sensor.js"), "utf8"));

// --- decode com payload valido ---
var result = decodeUplink({ bytes: [0x0E, 0x74, 0x01, 0xF4], fPort: 1 });
assert.strictEqual(result.data.battery_mv, 3700);
assert.strictEqual(result.data.battery_v, 3.7);
assert.strictEqual(result.data.uptime_s, 500);
assert(!result.errors, "nao deve retornar errors para payload valido");

// --- decode com payload minimo (exatamente 4 bytes) ---
var result2 = decodeUplink({ bytes: [0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(result2.data.battery_mv, 0);
assert.strictEqual(result2.data.uptime_s, 0);

// --- decode com valores maximos ---
var result3 = decodeUplink({ bytes: [0xFF, 0xFF, 0xFF, 0xFF], fPort: 1 });
assert.strictEqual(result3.data.battery_mv, 65535);
assert.strictEqual(result3.data.uptime_s, 65535);

// --- error handling: payload curto ---
var err1 = decodeUplink({ bytes: [0x0E, 0x74], fPort: 1 });
assert(err1.errors, "deve retornar errors para payload curto");
assert(err1.errors.length > 0);
assert(err1.errors[0].indexOf("too short") !== -1);

// --- error handling: payload vazio ---
var err2 = decodeUplink({ bytes: [], fPort: 1 });
assert(err2.errors, "deve retornar errors para payload vazio");

console.log("PASS cubecell-class-a-sensor");
