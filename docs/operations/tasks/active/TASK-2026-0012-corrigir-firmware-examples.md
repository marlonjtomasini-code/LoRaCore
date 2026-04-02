# TASK-2026-0012 — Corrigir firmware examples

- **Severidade:** S2
- **Status:** pendente
- **Origem:** Code review 2026-04-02

## O que

Corrigir problemas críticos nos exemplos de firmware CubeCell (payload mismatch, credenciais hardcoded, platformio.ini).

## Por que

device1.cpp envia payload incompatível com o codec correspondente. Credenciais OTAA reais estão versionadas. platformio.ini tem config inválida.

## Itens

### Críticos
1. **Payload mismatch device1.cpp vs codec** — device1 envia 7 bytes `[deviceId(1) bat(2) txCount(4)]`, codec `cubecell-class-a-sensor.js` espera 4 bytes `[bat(2) uptime(2)]`. Opções: (a) atualizar device1 para formato do codec, ou (b) criar codec específico para device1.
2. **Credenciais OTAA hardcoded em `device1.cpp:13-16` e `device2.cpp:13-16`** — DevEUI e AppKey reais. Substituir por placeholders com instruções.

### Altos
3. **`platformio.ini:6` — `default_envs` com 2 valores** — PlatformIO não suporta múltiplos defaults. Corrigir.
4. **`device1.cpp:37-39` — `txFail` nunca incrementado** — variável declarada mas sem uso real.

## Aceite
- [ ] Payload de cada device documentado e compatível com codec correspondente
- [ ] Nenhuma credencial real no código (apenas placeholders)
- [ ] platformio.ini compila sem warnings
- [ ] CI firmware-build.yml passa
