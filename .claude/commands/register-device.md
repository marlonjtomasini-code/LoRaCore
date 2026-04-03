Registre um novo dispositivo LoRaWAN no ChirpStack e injete as credenciais no firmware. Execute tudo autonomamente, sem perguntas.

Parametros recebidos via $ARGUMENTS: <nome> <tipo> <application> <firmware-path>
Exemplo: sonda-movel-2 sensor Secador /home/marlon/.../SondaMovel_Cubecell_HTCC-AB01_V2

## Passo 1 — Registrar no ChirpStack

Execute o script de registro:
```bash
bash scripts/register-device.sh --name "<nome>" --type "<tipo>" --app "<application>" --json
```

Capture a saida JSON. Se falhar, reporte o erro e pare.

## Passo 2 — Injetar credenciais no firmware

Navegue ate o <firmware-path> fornecido e detecte o padrao de credenciais:

**Padrao A — platformio.ini (build_flags):**
Procure por `-D DEV_EUI_BYTES=` e `-D APP_KEY_BYTES=` no platformio.ini.
Substitua os valores usando `devEuiBytes` e `appKeyBytes` do JSON.

**Padrao B — C array (.cpp/.c/.h):**
Procure por `uint8_t devEui[]` e `uint8_t appKey[]` nos arquivos fonte.
Substitua os valores usando `devEuiBytes` e `appKeyBytes` do JSON.

Se o firmware tiver multiplos environments com credenciais (ex: env principal + Join_Test), atualize TODOS.

## Passo 3 — Compilar para validar

```bash
cd <firmware-path> && pio run
```

Se a compilacao falhar, investigue e corrija. Se passar, reporte sucesso.

## Passo 4 — Reportar resultado

Mostre uma tabela com:
- Nome, tipo, application
- DevEUI, AppKey (hex e bytes)
- Arquivo(s) editado(s)
- Status da compilacao
- Comando para flash: `cd <firmware-path> && pio run -t upload`
- Comando para monitor: `pio device monitor --baud 115200`
- Comando para validar join: `mosquitto_sub -h <host> -t "application/+/device/<devEui>/event/join" -v`

## Invariantes (nao violar)

- nwkKey DEVE ser igual a appKey (LoRaWAN 1.0.3)
- JoinEUI e sempre 0000000000000000
- Regiao: US915 sub-band 1
- OTAA obrigatorio (nunca ABP)
- Channel mask: 0x00FF (sub-band 1)
