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

// === decodeDownlink ===

// --- decode downlink basico ---
var dec1 = decodeDownlink({ bytes: [5, 100], fPort: 1 });
assert.strictEqual(dec1.data.command, 5);
assert.strictEqual(dec1.data.value, 100);
assert(!dec1.errors);

// --- decode downlink zeros ---
var dec2 = decodeDownlink({ bytes: [0, 0], fPort: 1 });
assert.strictEqual(dec2.data.command, 0);
assert.strictEqual(dec2.data.value, 0);

// --- decode downlink max ---
var dec3 = decodeDownlink({ bytes: [0xFF, 0xFF], fPort: 1 });
assert.strictEqual(dec3.data.command, 255);
assert.strictEqual(dec3.data.value, 255);

// --- decode downlink error: payload curto ---
var dec4 = decodeDownlink({ bytes: [0x01], fPort: 1 });
assert(dec4.errors);
assert(dec4.errors[0].indexOf("too short") !== -1);

// --- roundtrip: encode -> decode downlink ---
var rt1 = encodeDownlink({ data: { command: 42, value: 200 } });
var rt2 = decodeDownlink({ bytes: rt1.bytes, fPort: 1 });
assert.strictEqual(rt2.data.command, 42);
assert.strictEqual(rt2.data.value, 200);

// === encodeDownlink — overflow, negativos, floats ===

// --- overflow: valores > 255 devem ser truncados para byte ---
var enc4 = encodeDownlink({ data: { command: 256, value: 300 } });
assert.strictEqual(enc4.bytes[0], 0, "command 256 deve truncar para 0 (& 0xFF)");
assert.strictEqual(enc4.bytes[1], 44, "value 300 deve truncar para 44 (& 0xFF)");

var enc5 = encodeDownlink({ data: { command: 0x1FF, value: 0xFFFF } });
assert.strictEqual(enc5.bytes[0], 0xFF, "command 0x1FF deve truncar para 0xFF");
assert.strictEqual(enc5.bytes[1], 0xFF, "value 0xFFFF deve truncar para 0xFF");

// --- negativos: bitwise & 0xFF produz complemento ---
var enc6 = encodeDownlink({ data: { command: -1, value: -1 } });
assert.strictEqual(enc6.bytes[0], 0xFF, "command -1 -> 0xFF via & 0xFF");
assert.strictEqual(enc6.bytes[1], 0xFF, "value -1 -> 0xFF via & 0xFF");

// --- floats: bitwise trunca parte fracionaria ---
var enc7 = encodeDownlink({ data: { command: 5.9, value: 100.7 } });
assert.strictEqual(enc7.bytes[0], 5, "command float 5.9 trunca para 5");
assert.strictEqual(enc7.bytes[1], 100, "value float 100.7 trunca para 100");

// === decodeUplink — valores limite ===

// --- valores maximos (0xFF em todos os bytes) ---
var maxResult = decodeUplink({ bytes: [0xFF, 0xFF, 0xFF, 0xFF], fPort: 1 });
assert.strictEqual(maxResult.data.battery_mv, 65535);
assert.strictEqual(maxResult.data.status, 255);
assert.strictEqual(maxResult.data.gpio_state, 255);

console.log("PASS rak3172-class-c-actuator");
