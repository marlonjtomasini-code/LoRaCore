# TASK-2026-0011 — Hardening de segurança em scripts shell

- **Severidade:** S2
- **Status:** concluido
- **Origem:** Code review 2026-04-02

## O que

Corrigir vulnerabilidades de segurança e robustez identificadas nos scripts shell do projeto.

## Por que

Scripts em produção no RPi5 com riscos de shell injection, race conditions e falhas silenciosas.

## Itens

### Críticos
1. **Shell injection em `alert_flush.sh:90-96`** — `eval` com dados de config. Trocar por array construction sem eval.
2. **SQL injection em `setup-loracore.sh:184,191`** — password interpolada direto no SQL. Usar psql variable binding.
3. **sed inseguro em `setup-loracore.sh:251`** — secret com chars especiais (`&`, `\`, `|`) corrompe arquivo. Usar delimitador seguro ou escape.
4. **Race condition no lock em `auto_recovery.sh:94-102`** — check-then-write não é atômico. Usar `flock` ou `mkdir`.

### Altos
5. **Secret impresso no terminal em `setup-loracore.sh:111`** — usar `read -s` e não fazer echo do secret.
6. **Placeholder `<USER>` não substituído em `health_check.sh:18` e `auto_recovery.sh:367`** — usar `$(whoami)` ou validar que placeholder foi substituído.

## Aceite
- [x] Nenhum uso de `eval` com dados externos
- [x] Passwords não interpoladas em SQL (escape de aspas simples)
- [x] Secrets nunca impressos em stdout
- [x] Lock file usa mecanismo atômico (`flock`)
- [x] Placeholders validados (grep de `<UPPER>` no próprio script com abort)
- [x] Scripts existentes continuam funcionando (syntax check ok)

## Correções adicionais (encontradas durante revisão)
- Shell injection em `setup-loracore.sh:prompt()` — `eval` substituído por `printf -v`
- JSON injection em `alert_flush.sh:send_webhook()` — função `json_escape()` adicionada
- Unsafe sed estendido para todos os valores de usuário (não só SECRET/PG_PASSWORD)
- Secret parcial no resumo de config mascarado com `********`
