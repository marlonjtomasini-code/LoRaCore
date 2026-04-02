# Guia de Desenvolvimento de Codecs

Codecs sao funcoes JavaScript que o ChirpStack v4 executa automaticamente para converter payloads binarios LoRaWAN em objetos JSON legiveis (e vice-versa). Este guia cobre o ciclo completo: da criacao ao deploy.

---

## O que sao Codecs e Quando Sao Executados

```
Device ──uplink──> ChirpStack ──decodeUplink()──> JSON no MQTT/API
                                                  campo "object"

App ──JSON──> ChirpStack ──encodeDownlink()──> bytes enviados ao device

ChirpStack Web UI ──decodeDownlink()──> exibe downlink legivel
```

| Funcao | Direcao | Quando executa |
|--------|---------|----------------|
| `decodeUplink` | Device → App | Automaticamente em cada uplink recebido |
| `encodeDownlink` | App → Device | Ao enfileirar downlink via API com payload JSON |
| `decodeDownlink` | — | Para exibir downlinks na web UI (debug) |

---

## Assinaturas das Funcoes

### decodeUplink(input)

```javascript
// input:
//   {
//     bytes: Uint8Array,  // payload bruto (sem headers LoRaWAN)
//     fPort: number,      // porta LoRaWAN (1-223)
//     recvTime: Date      // timestamp de recepcao
//   }
//
// retorno (sucesso):
//   { data: { campo1: valor1, campo2: valor2, ... } }
// retorno (erro):
//   { errors: ["descricao do erro"] }

function decodeUplink(input) {
  var bytes = input.bytes;
  if (bytes.length < 4) { return { errors: ["payload too short: expected 4 bytes, got " + bytes.length] }; }
  var temperature = (bytes[0] << 8) | bytes[1];
  return { data: { temperature: temperature } };
}
```

### encodeDownlink(input)

```javascript
// input:
//   { data: { campo1: valor1, campo2: valor2, ... } }
//
// retorno:
//   { bytes: [byte0, byte1, ...] }

function encodeDownlink(input) {
  var cmd = input.data.command || 0;
  return { bytes: [cmd] };
}
```

### decodeDownlink(input)

```javascript
// input:
//   {
//     bytes: Uint8Array,  // payload do downlink
//     fPort: number       // porta LoRaWAN
//   }
//
// retorno:
//   { data: { campo1: valor1, campo2: valor2, ... } }

function decodeDownlink(input) {
  var bytes = input.bytes;
  return { data: { command: bytes[0] } };
}
```

---

## Como Usar o Template

1. Copie `CODEC_TEMPLATE.js` e renomeie (ex: `meu-sensor-umidade.js`)
2. Preencha o header com o layout de bytes do seu protocolo
3. Implemente as funcoes necessarias (minimo: `decodeUplink`)
4. Remova funcoes que seu device nao usa (sensores tipicamente nao precisam de `encodeDownlink`/`decodeDownlink`)
5. Teste localmente com Node.js (secao abaixo)
6. Cole no Device Profile > Codec no ChirpStack

---

## Teste Local com Node.js

Antes de subir no ChirpStack, teste o codec localmente:

```bash
# Testar decodeUplink
node -e "
$(cat meu-sensor.js)

var input = { bytes: [0x09, 0x29, 0x41, 0x0E, 0x74, 0x00], fPort: 1 };
console.log(JSON.stringify(decodeUplink(input), null, 2));
"
```

```bash
# Testar encodeDownlink
node -e "
$(cat meu-atuador.js)

var input = { data: { command: 'set_position', position: 75, speed: 50 } };
var result = encodeDownlink(input);
console.log('bytes:', result.bytes);
"
```

```bash
# Testar roundtrip (encode → decode)
node -e "
$(cat meu-atuador.js)

var original = { data: { command: 'set_position', position: 75, speed: 50 } };
var encoded = encodeDownlink(original);
console.log('encoded:', encoded.bytes);

var decoded = decodeDownlink({ bytes: encoded.bytes, fPort: 2 });
console.log('decoded:', JSON.stringify(decoded.data));
"
```

---

## Deploy no ChirpStack

1. Abra a web UI do ChirpStack (`http://<HOST>:8080`)
2. Va em **Device Profiles** > selecione ou crie um profile
3. Na aba **Codec**, selecione **JavaScript functions**
4. Cole o conteudo do seu arquivo `.js`
5. Salve o profile
6. Todos os devices com esse profile passam a usar o codec automaticamente

Alternativamente, importe via REST API incluindo o script no campo `payloadCodecScript` do device profile JSON.

---

## Padroes Comuns

### Inteiros multi-byte (big-endian)

```javascript
// 16-bit unsigned
var valor = (bytes[0] << 8) | bytes[1];

// 16-bit signed
var valor = (bytes[0] << 8) | bytes[1];
if (valor > 0x7FFF) { valor = valor - 0x10000; }

// 32-bit unsigned
var valor = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
```

### Inteiros multi-byte (little-endian)

```javascript
// 16-bit unsigned
var valor = bytes[0] | (bytes[1] << 8);

// 32-bit unsigned
var valor = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
```

### Flags de status (bitmask)

```javascript
var flags = bytes[N];
var flag_a = (flags & 0x01) !== 0;  // bit 0
var flag_b = (flags & 0x02) !== 0;  // bit 1
var flag_c = (flags & 0x04) !== 0;  // bit 2
```

### Valores com escala fixa

```javascript
// Temperatura x100: 2345 -> 23.45 C
var temp_c = rawTemp / 100.0;

// Bateria mV -> V: 3700 -> 3.700 V
var battery_v = battery_mv / 1000.0;
```

### Roteamento por fPort

```javascript
function decodeUplink(input) {
  var bytes = input.bytes;

  if (input.fPort === 1) {
    // Payload de telemetria
    return { data: { type: "telemetry", /* ... */ } };
  } else if (input.fPort === 2) {
    // Payload de status/diagnostico
    return { data: { type: "status", /* ... */ } };
  }

  return { errors: ["unknown fPort: " + input.fPort] };
}
```

### Tratamento de erros

Ao detectar payload invalido, retorne `{ errors: ["mensagem"] }` em vez de `{ data: {} }`. O ChirpStack v4 publica erros de codec no topico MQTT `application/<app_id>/device/<dev_eui>/event/error` e exibe na web UI, facilitando debug em producao.

```javascript
// Correto — erro visivel no ChirpStack
if (bytes.length < 6) {
  return { errors: ["payload too short: expected 6 bytes, got " + bytes.length] };
}

// Evitar — falha silenciosa, dificil de diagnosticar
if (bytes.length < 6) {
  return { data: {} };
}
```

---

## Compatibilidade

- Use `var` em vez de `let`/`const` (sandbox ChirpStack usa ES5)
- Evite arrow functions (`=>`), template literals (`` ` ``), destructuring
- Funcoes como `Math.round()`, `parseInt()`, `JSON.stringify()` estao disponiveis
- `Date`, `Array`, `Object` estao disponiveis
- Modulos Node.js (`require`, `import`) **nao** estao disponiveis

---

## Testes Automatizados

Cada codec tem um arquivo de teste em `tests/test-<nome>.js`. Os testes usam `assert` nativo do Node.js (zero dependencias npm) e carregam o codec via `eval()` para simular o sandbox ES5 do ChirpStack.

### Executar localmente

```bash
# Todos os testes
for f in templates/codecs/tests/test-*.js; do node "$f"; done

# Teste individual
node templates/codecs/tests/test-cubecell-class-a-sensor.js
```

### O que cada teste valida

- **Decode com bytes conhecidos** — verifica que valores especificos produzem o JSON esperado
- **Error handling** — payload curto ou vazio retorna `{ errors: [...] }` em vez de crash
- **Roundtrip** (codecs bidirecionais) — `encodeDownlink` → `decodeDownlink` preserva os valores originais

### Criar teste para novo codec

1. Copie um teste existente como base
2. Ajuste o path do codec e os payloads de teste
3. Nomeie como `tests/test-<nome-do-codec>.js`
4. Execute `node tests/test-<nome>.js` — exit 0 = sucesso
5. O CI executa automaticamente todos os `tests/test-*.js`

---

## Arquivos neste Diretorio

| Arquivo | Descricao |
|---------|-----------|
| `CODEC_TEMPLATE.js` | Esqueleto com as 3 funcoes e TODOs |
| `example-thermal-sensor.js` | Sensor termico industrial (decode only, 6 bytes) |
| `example-actuator-bidirectional.js` | Atuador bidirecional (decode + encode, 5+3 bytes) |
| `cubecell-class-a-sensor.js` | Codec validado — CubeCell Class A (battery + uptime) |
| `cubecell-stress-test-device2.js` | Codec validado — CubeCell Stress Test Device 2 (14 bytes) |
| `rak3172-class-c-actuator.js` | Codec validado — RAK3172 Class C (status + GPIO + comando) |
| `tests/test-*.js` | Testes automatizados (Node.js assert, zero deps) |

---

## Ver Tambem

- [DOC_PROTOCOLO Secao 12.4](../../docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) — Codecs no contexto da infraestrutura
- [AI Integration Guide](../../docs/LORACORE_AI_INTEGRATION_GUIDE.md) — Como o campo `object` aparece no MQTT
- [ChirpStack Codec docs](https://www.chirpstack.io/docs/chirpstack/use/codec/) — Referencia upstream
