---
id: TASK-2026-0007
title: Testes automatizados de codecs no CI
status: pending
phase: analise
severity: S3
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
depends_on: []
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - templates/codecs/tests/
  - templates/codecs/README.md
  - .github/workflows/validate-core.yml
context_reads:
  - templates/codecs/README.md
  - templates/codecs/
  - .github/workflows/validate-core.yml
acceptance:
  - templates/codecs/tests/ contem um arquivo de teste por codec existente
  - cada teste valida decode com bytes conhecidos e retorno esperado
  - cada teste valida error handling (payload curto retorna errors)
  - codecs com encode testam roundtrip (encode -> decode = original)
  - job test-codecs adicionado ao validate-core.yml
  - CI passa verde com os novos testes
  - templates/codecs/README.md documenta padrao de testes
  - zero dependencias npm (node + assert nativo)
restrictions:
  - ES5 (compativel com sandbox ChirpStack)
  - sem frameworks de teste (jest, mocha, etc)
  - sem npm install
hardware_required: []
bom: []
tags:
  - producao
  - ci
  - testes
---

## Retomada

ESTADO: aguardando_execucao
AGENTE: coordenador
PROXIMA: listar todos os codecs existentes em templates/codecs/, ler cada um para entender inputs/outputs
LER:
- templates/codecs/README.md (padrao de teste manual com node -e)
- templates/codecs/*.js (todos os codecs)
- .github/workflows/validate-core.yml (CI atual)
DECIDIDO:
- node + assert nativo, zero dependencias
- cada teste e standalone (exit 0 sucesso, exit 1 falha)
- ES5 para compatibilidade com sandbox ChirpStack
- testes carregam codec via eval() (simula sandbox)
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

O CI atual (validate-core.yml) roda `node --check` nos codecs, validando apenas sintaxe. Um codec pode parsear sem erro mas retornar dados incorretos. O README dos codecs ja documenta como testar manualmente com `node -e`. Esta tarefa mecaniza esses testes no CI para prevenir regressao.

### Decisoes ja tomadas

- Formato: scripts Node.js standalone usando `assert` nativo
- Carregamento: `eval(fs.readFileSync(codec))` para simular sandbox ES5 do ChirpStack
- Testes por codec: decode com bytes conhecidos, error handling, roundtrip encode/decode
- Job no CI: loop sobre `templates/codecs/tests/test-*.js`

### Perguntas a Investigar

#### Codecs existentes
1. Quantos codecs existem em templates/codecs/ e quais sao?
2. Quais codecs tem funcao encode (bidirecionais)?
3. O README documenta exemplos de payloads para cada codec?

### Fontes de Referencia

- templates/codecs/README.md
- templates/codecs/CODEC_TEMPLATE.js
- .github/workflows/validate-core.yml

## Checklist

- [ ] Listar todos os codecs existentes
- [ ] Ler cada codec para mapear inputs/outputs
- [ ] Criar templates/codecs/tests/test-*.js para cada codec
- [ ] Adicionar job test-codecs ao validate-core.yml
- [ ] Atualizar templates/codecs/README.md com padrao de testes
- [ ] Verificar CI passa verde
