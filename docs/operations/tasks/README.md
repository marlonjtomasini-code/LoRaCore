# Backlog Canonico — LoRaCore

Tarefas sao criadas, lidas, atualizadas e fechadas exclusivamente pelo Claude (agente unico). O humano consulta o estado via conversa com o agente.

## Estrutura

- `index.md`: lista oficial das tarefas
- `active/`: um arquivo por tarefa aberta
- `archive/`: tarefas concluidas, canceladas ou substituidas
- `TASK_TEMPLATE.md`: modelo para novas tarefas
- `plans/`: planos de execucao por tarefa
- `plans/PLAN_TEMPLATE.md`: modelo para plano de execucao com fases TDD
- `.task_counter`: contador global de IDs (nunca editar manualmente)

## Formato de tarefa

Cada tarefa e composta por:

1. **YAML front matter** — metadados estruturados: `id`, `status`, `phase`, `severity`, `write_scope`, `context_reads`, `acceptance`, `restrictions`, `hardware_required`, `bom`
2. **## Retomada** — estado compacto para continuidade entre sessoes (ESTADO/AGENTE/PROXIMA/LER/DECIDIDO/PENDENTE)
3. **## Analise Preliminar** — contexto, decisoes tomadas, perguntas a investigar, fontes de referencia
4. **## Checklist** — tracking de progresso

## Status permitidos

| Status | Significado |
|---|---|
| `pending` | registrada, aguardando execucao |
| `in_progress` | em execucao |
| `blocked` | impedida (hardware, dependencia, decisao pendente) |
| `done` | concluida → mover para archive/ |
| `cancelled` | abandonada → mover para archive/ |

## Classificacao de severidade

| Severidade | Descricao | Exemplos |
|---|---|---|
| `S1` | Critico — bloqueia operacao ou seguranca | Crash de firmware, perda de dados, falha de comunicacao |
| `S2` | Moderado — impacta funcionalidade mas tem workaround | Migracao de sensor, otimizacao de consumo |
| `S3` | Simples — melhoria, documentacao, refatoracao | Renomear variaveis, atualizar README |

## Consulta pela IA

1. Ler `index.md`.
2. Listar tarefas `pending`, `in_progress` e `blocked`.
3. Ao retomar uma tarefa, abrir o arquivo em `active/` e seguir `context_reads` do YAML.

Frases naturais que disparam consulta: `o que temos a fazer?`, `quais sao as pendencias?`, `liste as tarefas`
Frases naturais que disparam criacao: `anote isso para fazer depois`, `guarde isso como tarefa`, `crie uma tarefa para...`

## Criacao de nova tarefa

1. Ler `.task_counter` e incrementar por 1.
2. Usar o novo valor como NNNN no ID `TASK-YYYY-NNNN` (ano corrente).
3. Criar o arquivo em `active/` usando `TASK_TEMPLATE.md` como base.
4. Salvar o contador atualizado em `.task_counter`.
5. Atualizar `index.md` com a nova tarefa.

## Workflow de agente unico

O projeto usa Claude como unico agente IA, acumulando os papeis de coordenador, pesquisador e implementador.

### Fluxo em 4 passos

```
Passo 1: Claude cria a task
         (contexto, decisoes, perguntas a investigar, scope)
              |
              v
Passo 2: Claude investiga
         (le codigo, docs, datasheets, web; responde as perguntas)
              |
              v
Passo 3: Claude cria plano ({TASK_ID}-plan.md)
         (decisoes de arquitetura, fases TDD com gates,
          BOM se hardware, riscos, inventario de impacto)
              |
              v
Passo 4: Claude implementa seguindo as fases do plano
         (uma fase por vez, gate de saida obrigatorio)
```

### Convencao de nomes

| Tipo | Padrao de nome | Exemplo |
|---|---|---|
| Tarefa | `TASK-YYYY-NNNN-descricao-curta.md` | `TASK-2026-0001-firmware-cubecell-otaa.md` |
| Plano | `{TASK_ID}-plan.md` | `TASK-2026-0001-plan.md` |

### Fases TDD para Embedded/IoT

Toda tarefa de implementacao segue fases TDD com gates obrigatorios:

**Fase 0 — Inspecao de Hardware** (quando aplicavel)
- Verificar pinout, tensao, conexoes fisicas
- Gate: hardware conectado e verificado com multimetro

**Fases 1-N — Implementacao incremental**
- Uma preocupacao por fase (comunicacao, interrupt, payload, power...)
- Gate de cada fase:
  - `pio run` compila sem erros/warnings
  - `pio run -t upload` flash bem-sucedido (se fase de upload)
  - Serial output confirma comportamento esperado
  - ChirpStack recebe dados (se fase LoRaWAN)

**Fase Final — Teste de Estabilidade**
- Executar por periodo prolongado (1h+ para firmware)
- Gate: sem crash, rejoin, corrupcao ou anomalia nos logs

### Procedimento para criar plano

1. Abrir a tarefa em `active/` e ler a secao `## Analise Preliminar`.
2. Ler todos os arquivos listados em `context_reads`.
3. Investigar: ler codigo, documentacao, datasheets conforme necessario.
4. Criar plano em `plans/` usando `PLAN_TEMPLATE.md`, nomeado como `{TASK_ID}-plan.md`.
5. Preencher todas as secoes: investigacao, BOM, decisoes, fases TDD, riscos, inventario.
6. Atualizar `plan_doc` no YAML da tarefa.
7. Atualizar `index.md`.

### Regra obrigatoria ao encerrar sessao

Se a tarefa ficou parcial, bloqueada ou interrompida:
1. Atualizar `## Retomada` com ESTADO/PROXIMA/DECIDIDO/PENDENTE atuais
2. Atualizar `status` no YAML se mudou (ex: `in_progress` → `blocked`)
3. Atualizar `index.md`
4. Fazer commit (ou `wip:` commit se parcial)
