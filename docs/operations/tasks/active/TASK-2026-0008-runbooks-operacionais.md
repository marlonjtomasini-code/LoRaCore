---
id: TASK-2026-0008
title: Runbooks operacionais para incidentes de producao
status: pending
phase: analise
severity: S2
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
depends_on:
  - TASK-2026-0006
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - docs/runbooks/
  - docs/README.md
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - docs/RELATORIO_STRESS_TEST_V3.md
  - templates/backup/lorawan-backup.sh
  - templates/backup/lorawan-restore.sh
acceptance:
  - docs/runbooks/README.md existe com indice e trigger de cada runbook
  - RUNBOOK-001 (service failure) cobre triagem, recovery por servico, escalacao
  - RUNBOOK-002 (sd card failure) cobre deteccao, recovery com restore, downtime estimado
  - RUNBOOK-003 (gateway not receiving) cobre arvore de decisao RF vs USB vs servico
  - RUNBOOK-004 (backup failure) cobre fases do script, OAuth, disco
  - RUNBOOK-005 (device offline) cobre um-vs-todos, firmware vs gateway
  - cada runbook completavel em <15 minutos de leitura + acao
  - docs/README.md atualizado com diretorio runbooks
restrictions:
  - portugues (consistente com docs existentes)
  - operador-alvo: dono do negocio com conhecimento em programacao
hardware_required: []
bom: []
tags:
  - producao
  - operacoes
  - runbooks
---

## Retomada

ESTADO: aguardando_execucao
AGENTE: coordenador
PROXIMA: ler Secao 22 do DOC_PROTOCOLO (troubleshooting) e stress test v3 para cenarios reais
LER:
- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 22 — Troubleshooting)
- docs/RELATORIO_STRESS_TEST_V3.md (cenarios de falha reais)
- templates/backup/lorawan-restore.sh (procedimento de restore)
DECIDIDO:
- 5 runbooks cobrindo cenarios mais provaveis em chao de fabrica
- formato: deteccao -> triagem -> recovery -> pos-incidente
- linguagem acessivel para operador nao-DevOps
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

A DOC_PROTOCOLO Secao 22 tem troubleshooting tabular (diagnostico), mas nao procedimentos passo-a-passo para o operador seguir durante incidente. Em producao, quando algo quebra as 3h da manha, o operador precisa de um checklist claro, nao de uma tabela de referencia. Runbooks sao a ponte entre documentacao tecnica e acao operacional.

Os 5 cenarios cobertos foram selecionados com base nos modos de falha observados durante stress tests e nos riscos inerentes da plataforma (microSD como single point of failure, gateway RF, dependencia de backup).

### Decisoes ja tomadas

- 5 runbooks: service failure, SD card failure, gateway not receiving, backup failure, device offline
- Cada runbook segue estrutura: Deteccao -> Triagem -> Recovery -> Pos-incidente
- Portugues, acessivel para operador com conhecimento em programacao
- Referencia scripts de monitoramento da TASK-2026-0006 (depends_on)

### Perguntas a Investigar

#### Cenarios de falha
1. Quais servicos crasharam durante stress test v3? (para priorizar no RUNBOOK-001)
2. Qual a ordem correta de restart dos servicos? (dependencias: postgres -> redis -> chirpstack -> mqtt-forwarder -> mosquitto -> pkt-fwd)
3. O lorawan-restore.sh tem modo dry-run? (para RUNBOOK-002)
4. Quais sinais de dmesg indicam falha de microSD? (para RUNBOOK-002)

### Fontes de Referencia

- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 22)
- docs/RELATORIO_STRESS_TEST_V3.md
- templates/backup/lorawan-restore.sh
- templates/backup/README.md

## Checklist

- [ ] Ler Secao 22 do DOC_PROTOCOLO
- [ ] Ler stress test v3 para cenarios reais de falha
- [ ] Ler lorawan-restore.sh para procedimento de restore
- [ ] Criar docs/runbooks/README.md (indice)
- [ ] Criar RUNBOOK-001-service-failure.md
- [ ] Criar RUNBOOK-002-sd-card-failure.md
- [ ] Criar RUNBOOK-003-gateway-not-receiving.md
- [ ] Criar RUNBOOK-004-backup-failure.md
- [ ] Criar RUNBOOK-005-device-offline.md
- [ ] Atualizar docs/README.md
