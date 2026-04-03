// Test: example-actuator-bidirectional.js
// Uplink: 5 bytes [status, position, supply_mv_hi, supply_mv_lo, flags]
// Downlink: 3 bytes [command, arg1, arg2]
var assert = require("assert");
var fs = require("fs");
var path = require("path");

eval(fs.readFileSync(path.join(__dirname, "..", "example-actuator-bidirectional.js"), "utf8"));

// === decodeUplink ===

// --- decode com payload valido ---
// status=1(running), position=75, supply=12000(0x2EE0), flags=0x05(watchdog_ok + position_reached)
var result = decodeUplink({ bytes: [0x01, 0x4B, 0x2E, 0xE0, 0x05], fPort: 1 });
assert.strictEqual(result.data.status, 1);
assert.strictEqual(result.data.status_name, "running");
assert.strictEqual(result.data.position_pct, 75);
assert.strictEqual(result.data.supply_mv, 12000);
assert.strictEqual(result.data.supply_v, 12.0);
assert.strictEqual(result.data.watchdog_ok, true);
assert.strictEqual(result.data.overtemp, false);
assert.strictEqual(result.data.position_reached, true);
assert(!result.errors);

// --- decode status names ---
var idle = decodeUplink({ bytes: [0x00, 0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(idle.data.status_name, "idle");
var fault = decodeUplink({ bytes: [0x02, 0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(fault.data.status_name, "fault");
var manual = decodeUplink({ bytes: [0x03, 0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(manual.data.status_name, "manual");
var unknown = decodeUplink({ bytes: [0xFF, 0x00, 0x00, 0x00, 0x00], fPort: 1 });
assert.strictEqual(unknown.data.status_name, "unknown");

// --- error handling: payload curto ---
var err1 = decodeUplink({ bytes: [0x01, 0x4B], fPort: 1 });
assert(err1.errors);
assert(err1.errors[0].indexOf("too short") !== -1);

// === encodeDownlink ===

// --- encode set_position ---
var enc1 = encodeDownlink({ data: { command: "set_position", position: 75, speed: 50 } });
assert.deepStrictEqual(enc1.bytes, [0x01, 75, 50]);

// --- encode stop ---
var enc2 = encodeDownlink({ data: { command: "stop" } });
assert.strictEqual(enc2.bytes[0], 0x02);

// --- encode reset_fault ---
var enc3 = encodeDownlink({ data: { command: "reset_fault" } });
assert.strictEqual(enc3.bytes[0], 0x03);

// --- encode default (sem comando) -> stop ---
var enc4 = encodeDownlink({ data: {} });
assert.strictEqual(enc4.bytes[0], 0x02);

// === decodeDownlink ===

// --- decode set_position ---
var dec1 = decodeDownlink({ bytes: [0x01, 75, 50], fPort: 2 });
assert.strictEqual(dec1.data.command, "set_position");
assert.strictEqual(dec1.data.position, 75);
assert.strictEqual(dec1.data.speed, 50);

// --- decode stop ---
var dec2 = decodeDownlink({ bytes: [0x02, 0x00, 0x00], fPort: 2 });
assert.strictEqual(dec2.data.command, "stop");

// --- decode error handling ---
var decErr = decodeDownlink({ bytes: [0x01], fPort: 2 });
assert(decErr.errors);

// === roundtrip: encodeDownlink -> decodeDownlink ===

var original = { data: { command: "set_position", position: 80, speed: 60 } };
var encoded = encodeDownlink(original);
var decoded = decodeDownlink({ bytes: encoded.bytes, fPort: 2 });
assert.strictEqual(decoded.data.command, "set_position");
assert.strictEqual(decoded.data.position, 80);
assert.strictEqual(decoded.data.speed, 60);

// roundtrip stop
var encStop = encodeDownlink({ data: { command: "stop" } });
var decStop = decodeDownlink({ bytes: encStop.bytes, fPort: 2 });
assert.strictEqual(decStop.data.command, "stop");

// === encodeDownlink — overflow, negativos, floats ===

// --- overflow: position > 255 deve truncar para byte ---
var encOver = encodeDownlink({ data: { command: "set_position", position: 300, speed: 256 } });
assert.strictEqual(encOver.bytes[1], 44, "position 300 -> 44 (& 0xFF)");
assert.strictEqual(encOver.bytes[2], 0, "speed 256 -> 0 (& 0xFF)");

// --- negativos ---
var encNeg = encodeDownlink({ data: { command: "set_position", position: -1, speed: -1 } });
assert.strictEqual(encNeg.bytes[1], 0xFF, "position -1 -> 0xFF via & 0xFF");
assert.strictEqual(encNeg.bytes[2], 0xFF, "speed -1 -> 0xFF via & 0xFF");

// --- floats: trunca parte fracionaria ---
var encFloat = encodeDownlink({ data: { command: "set_position", position: 50.9, speed: 75.1 } });
assert.strictEqual(encFloat.bytes[1], 50, "position float 50.9 trunca para 50");
assert.strictEqual(encFloat.bytes[2], 75, "speed float 75.1 trunca para 75");

// === decodeUplink — valores limite ===

// --- supply maxima: 65535mV ---
var maxSupply = decodeUplink({ bytes: [0x00, 0x00, 0xFF, 0xFF, 0x00], fPort: 1 });
assert.strictEqual(maxSupply.data.supply_mv, 65535, "max uint16 supply");

// === Integracao: simula roundtrip firmware -> codec -> encode -> decode ===

// --- firmware envia status=running, pos=80%, supply=12000mV, flags=watchdog_ok ---
var fwUplink = decodeUplink({ bytes: [0x01, 0x50, 0x2E, 0xE0, 0x01], fPort: 1 });
assert.strictEqual(fwUplink.data.status_name, "running");
assert.strictEqual(fwUplink.data.position_pct, 80);
assert.strictEqual(fwUplink.data.supply_mv, 12000);
assert.strictEqual(fwUplink.data.watchdog_ok, true);

// --- backend envia comando em resposta, roundtrip completo ---
var backendCmd = { data: { command: "set_position", position: 100, speed: 80 } };
var encCmd = encodeDownlink(backendCmd);
var decCmd = decodeDownlink({ bytes: encCmd.bytes, fPort: 2 });
assert.strictEqual(decCmd.data.command, "set_position");
assert.strictEqual(decCmd.data.position, 100);
assert.strictEqual(decCmd.data.speed, 80);

console.log("PASS example-actuator-bidirectional");
