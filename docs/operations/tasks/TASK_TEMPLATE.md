---
id: TASK-YYYY-NNNN
title: Titulo curto descritivo
status: pending
phase: analise
severity: S3
owner: coordenador
created: YYYY-MM-DD
updated: YYYY-MM-DD
depends_on: []
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - docs/operations/tasks/
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
acceptance:
  - criterio 1
  - criterio 2
restrictions: []
hardware_required: []
bom: []
tags:
  - exemplo
---

## Retomada

ESTADO: aguardando_triagem
AGENTE: coordenador
PROXIMA: descrever exatamente o proximo passo
LER:
- caminhos que a IA deve ler antes de retomar
DECIDIDO:
- nenhuma ainda
PENDENTE:
- nenhuma ainda

## Analise Preliminar

> Secao preenchida pelo Claude ao criar ou investigar a tarefa.
> Estrutura o raciocinio antes de criar o plano de execucao.

### Contexto

<!-- Background e motivacao: por que esta tarefa existe, qual problema resolve. -->

### Decisoes ja tomadas

<!-- Restricoes inegociaveis que nao devem ser questionadas durante a analise. -->
- decisao 1
- decisao 2

### Perguntas a Investigar

<!-- Perguntas concretas e verificaveis que o Claude deve responder durante a analise.
     Bom:  "Qual registrador do BMA400 configura o wake-up interrupt?"
     Ruim: "Analise as mudancas necessarias no firmware." -->

#### Dominio 1
1. pergunta concreta 1
2. pergunta concreta 2

#### Dominio 2
1. pergunta concreta 1

### Fontes de Referencia

<!-- Datasheets, URLs, documentos internos, arquivos do repo que devem ser consultados. -->
- fonte 1
- fonte 2

## Checklist

- [ ] item 1
- [ ] item 2
- [ ] item 3
