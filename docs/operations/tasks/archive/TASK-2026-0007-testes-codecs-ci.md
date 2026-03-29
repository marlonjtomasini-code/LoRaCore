---
id: TASK-2026-0007
title: Testes automatizados de codecs no CI
status: done
phase: concluido
severity: S3
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
closed: 2026-03-29
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

ESTADO: concluido
AGENTE: coordenador
RESULTADO:
- 5 arquivos de teste criados em templates/codecs/tests/
- Todos os 5 codecs testados: decode, error handling, roundtrip (onde aplicavel)
- Job test-codecs adicionado ao validate-core.yml
- templates/codecs/README.md atualizado com secao de testes
- Todos os testes passam localmente

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

- [x] Listar todos os codecs existentes (5 codecs + 1 template)
- [x] Ler cada codec para mapear inputs/outputs
- [x] Criar templates/codecs/tests/test-*.js para cada codec (5 testes)
- [x] Adicionar job test-codecs ao validate-core.yml
- [x] Atualizar templates/codecs/README.md com padrao de testes
- [x] Verificar testes passam localmente
