# TASK-2026-0014 — Hardening de codecs e testes

- **Severidade:** S2
- **Status:** done
- **Origem:** Code review 2026-04-02
- **Concluido:** 2026-04-03

## O que

Adicionar validação de input nos codecs e expandir cobertura de testes.

## Por que

Codecs em produção sem bounds checking. Testes não cobrem overflow, valores negativos ou integração firmware→codec.

## Itens

### Altos
1. **`rak3172-class-c-actuator.js:27-29`** — `encodeDownlink` sem bounds check em command/value. Valores >255 causam overflow. Adicionar `& 0xFF`.
2. **`cubecell-class-a-sensor.js:10-11`** — uint16 sem conversão explícita unsigned. Adicionar `& 0xFFFF`.
3. **Testes de overflow** — adicionar testes com valores >255/65535, negativos e float em todos os codecs.

### Médios
4. **Testes de integração** — criar teste roundtrip que simula payload do firmware e verifica decode.
5. **`.gitignore` incompleto** — adicionar `.env*`, `*.key`, `*.pem`, `credentials*`, `secrets/`.

## Aceite
- [x] Todos os codecs com bounds checking nos inputs
- [x] Testes cobrem overflow, negativos e floats
- [x] .gitignore cobre arquivos sensíveis
- [x] Testes existentes continuam passando
