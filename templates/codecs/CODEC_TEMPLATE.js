// =============================================================================
// Template: Codec ChirpStack v4 — Esqueleto
// Referencia: https://www.chirpstack.io/docs/chirpstack/use/codec/
// Destino: Device Profile > Codec tab no ChirpStack
//
// Payload Uplink:
//   [TODO: descrever layout de bytes — ex: byte 0-1 = temperatura x100, ...]
//
// Payload Downlink:
//   [TODO: descrever layout de bytes — ex: byte 0 = comando, byte 1 = valor, ...]
//
// Instrucoes:
//   1. Copie este arquivo e renomeie para seu device (ex: meu-sensor.js)
//   2. Implemente as funcoes conforme seu protocolo
//   3. Teste localmente com Node.js (ver templates/codecs/README.md)
//   4. Cole o conteudo no Device Profile > Codec no ChirpStack
//   5. Remova funcoes que seu device nao usa (ex: sensor sem downlink)
// =============================================================================

// ---------------------------------------------------------------------------
// decodeUplink — Chamada pelo ChirpStack ao receber um uplink do device
//
// input:
//   {
//     bytes: Uint8Array,  // payload bruto (sem headers LoRaWAN)
//     fPort: number,      // porta LoRaWAN (1-223)
//     recvTime: Date      // timestamp de recepcao
//   }
//
// retorno esperado:
//   { data: { campo1: valor1, campo2: valor2, ... } }
//
// O objeto "data" aparece no campo "object" do JSON MQTT e na web UI.
// ---------------------------------------------------------------------------
function decodeUplink(input) {
  var bytes = input.bytes;

  // TODO: validar tamanho minimo do payload
  if (bytes.length < 1) {
    return { data: {} };
  }

  // TODO: extrair campos do payload
  // Exemplo (big-endian 16-bit): var valor = (bytes[0] << 8) | bytes[1];
  // Exemplo (little-endian 16-bit): var valor = bytes[0] | (bytes[1] << 8);

  return {
    data: {
      // TODO: retornar campos decodificados
      // exemplo: temperature_c: rawTemp / 100.0,
      // exemplo: battery_mv: rawBattery
    }
  };
}

// ---------------------------------------------------------------------------
// encodeDownlink — Chamada pelo ChirpStack ao enviar um downlink via API
//
// input:
//   { data: { campo1: valor1, campo2: valor2, ... } }
//
// retorno esperado:
//   { bytes: [byte0, byte1, ...] }
//
// O ChirpStack serializa o array de bytes e envia ao device.
// Se seu device so recebe uplinks (sensor puro), remova esta funcao.
// ---------------------------------------------------------------------------
function encodeDownlink(input) {
  var data = input.data;

  // TODO: converter campos em bytes
  // Exemplo: var cmd = data.command || 0;
  // Exemplo: var val = data.value || 0;

  return {
    bytes: [
      // TODO: retornar array de bytes do payload downlink
      // exemplo: cmd, val
    ]
  };
}

// ---------------------------------------------------------------------------
// decodeDownlink — Chamada pelo ChirpStack para exibir downlinks na web UI
//
// input:
//   {
//     bytes: Uint8Array,  // payload do downlink
//     fPort: number       // porta LoRaWAN
//   }
//
// retorno esperado:
//   { data: { campo1: valor1, campo2: valor2, ... } }
//
// Funcao inversa de encodeDownlink. Usada para visualizacao/debug.
// Se seu device so recebe uplinks (sensor puro), remova esta funcao.
// ---------------------------------------------------------------------------
function decodeDownlink(input) {
  var bytes = input.bytes;

  if (bytes.length < 1) {
    return { data: {} };
  }

  // TODO: decodificar payload de downlink (inverso do encodeDownlink)

  return {
    data: {
      // TODO: retornar campos decodificados
    }
  };
}
