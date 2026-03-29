// Test: example-thermal-sensor.js
// Payload: 6 bytes
// [temp_hi, temp_lo (int16 signed x100)] [humidity (uint8)] [bat_hi, bat_lo (uint16)] [flags (uint8)]
var assert = require("assert");
var fs = require("fs");
var path = require("path");

eval(fs.readFileSync(path.join(__dirname, "..", "example-thermal-sensor.js"), "utf8"));

// --- decode com payload valido (temperatura positiva) ---
// temp=2345 (23.45C), humidity=65, battery=3700(0x0E74), flags=0x00
var result = decodeUplink({ bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x00], fPort: 1 });
assert.strictEqual(result.data.temperature_c, 23.45);
assert.strictEqual(result.data.temperature_raw, 2345);
assert.strictEqual(result.data.humidity_pct, 65);
assert.strictEqual(result.data.battery_mv, 3700);
assert.strictEqual(result.data.battery_v, 3.7);
assert.strictEqual(result.data.sensor_fault, false);
assert.strictEqual(result.data.low_battery, false);
assert.strictEqual(result.data.first_boot, false);
assert(!result.errors);

// --- decode com temperatura negativa ---
// temp=-500 (0xFE0C) = -5.00C
var result2 = decodeUplink({ bytes: [0xFE, 0x0C, 0x32, 0x0E, 0x74, 0x00], fPort: 1 });
assert.strictEqual(result2.data.temperature_c, -5.00);
assert.strictEqual(result2.data.temperature_raw, -500);

// --- decode com flags ativas ---
// flags=0x07 (sensor_fault + low_battery + first_boot)
var result3 = decodeUplink({ bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x07], fPort: 1 });
assert.strictEqual(result3.data.sensor_fault, true);
assert.strictEqual(result3.data.low_battery, true);
assert.strictEqual(result3.data.first_boot, true);

// --- decode com flags parciais ---
// flags=0x02 (apenas low_battery)
var result4 = decodeUplink({ bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x02], fPort: 1 });
assert.strictEqual(result4.data.sensor_fault, false);
assert.strictEqual(result4.data.low_battery, true);
assert.strictEqual(result4.data.first_boot, false);

// --- error handling: payload curto ---
var err1 = decodeUplink({ bytes: [0x09, 0x29, 0x41], fPort: 1 });
assert(err1.errors);
assert(err1.errors[0].indexOf("too short") !== -1);

// --- error handling: payload vazio ---
var err2 = decodeUplink({ bytes: [], fPort: 1 });
assert(err2.errors);

console.log("PASS example-thermal-sensor");
