# TASK-2026-0015 — Melhorias CI/CD e validação de configuração

- **Severidade:** S2
- **Status:** done
- **Origem:** Code review 2026-04-02
- **Concluido:** 2026-04-03

## O que

Melhorar validações no CI e robustez de configuração.

## Por que

CI tem gaps de validação (TOML em Python <3.11, firmware build sem verificação de artefato). Scripts com placeholders não validados.

## Itens

### Médios
1. **`validate-core.yml:82-96`** — validação TOML usa `tomllib` (Python 3.11+). Adicionar fallback para `tomli` ou checar versão.
2. **`validate-core.yml:104-128`** — detecção de hardcodes incompleta. Adicionar patterns para API keys, ranges de IP privado.
3. **`firmware-build.yml:32`** — build não verifica existência do artefato `.pio/build/*/firmware.bin`.
4. **Validação de placeholders** — adicionar check no CI que detecta `<USER>`, `<SECRET>`, etc. não substituídos em scripts de deploy.
5. **`smoke-test.sh:38`** — assume execução do repo root. Normalizar com `cd "$(dirname "$0")/../.."`.

## Aceite
- [x] CI roda em Python 3.10+ sem falha
- [x] Firmware build verifica artefato gerado
- [x] Placeholders não substituídos são detectados pelo CI
- [x] smoke-test.sh funciona de qualquer diretório
