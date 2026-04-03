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

// === Testes de integracao: simula payload real do firmware ===

// --- firmware envia battery=4200mV, uptime=120s ---
// C firmware: appData[0]=(4200>>8)=0x10, appData[1]=(4200&0xFF)=0x68
//             appData[2]=(120>>8)=0x00,  appData[3]=(120&0xFF)=0x78
var fwPayload = [0x10, 0x68, 0x00, 0x78];
var fwResult = decodeUplink({ bytes: fwPayload, fPort: 2 });
assert.strictEqual(fwResult.data.battery_mv, 4200, "firmware roundtrip: battery 4200mV");
assert.strictEqual(fwResult.data.uptime_s, 120, "firmware roundtrip: uptime 120s");

// --- firmware envia valores maximos uint16 ---
var fwMax = [0xFF, 0xFF, 0xFF, 0xFF];
var fwMaxResult = decodeUplink({ bytes: fwMax, fPort: 2 });
assert.strictEqual(fwMaxResult.data.battery_mv, 65535, "max uint16 battery");
assert.strictEqual(fwMaxResult.data.uptime_s, 65535, "max uint16 uptime");

// --- payload com bytes extras (firmware pode ter versao mais nova) ---
var extraBytes = [0x0E, 0x74, 0x01, 0xF4, 0xAA, 0xBB];
var extraResult = decodeUplink({ bytes: extraBytes, fPort: 1 });
assert.strictEqual(extraResult.data.battery_mv, 3700, "ignora bytes extras");
assert.strictEqual(extraResult.data.uptime_s, 500);
assert(!extraResult.errors, "bytes extras nao devem causar erro");

console.log("PASS cubecell-class-a-sensor");
