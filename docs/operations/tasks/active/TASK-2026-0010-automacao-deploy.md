---
id: TASK-2026-0010
title: Script de automacao de deploy
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
  - templates/deploy/
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - templates/README.md
  - templates/monitoring/
  - templates/backup/
acceptance:
  - templates/deploy/setup-loracore.sh existe e valida com bash -n
  - script instala pacotes (PostgreSQL, Redis, Mosquitto, ChirpStack)
  - script copia templates com substituicao interativa de placeholders
  - script cria overrides systemd, aplica sysctl, configura udev
  - script oferece setup opcional de backup e monitoramento
  - script e idempotente (seguro re-executar)
  - script executa health check final
  - templates/deploy/README.md documenta prerequisitos e uso
  - Secao 19 do DOC_PROTOCOLO permanece como referencia manual autoritativa
restrictions:
  - bash puro (sem Ansible, Terraform, Docker)
  - interativo com prompts para placeholders
  - nao substitui a documentacao manual
hardware_required: []
bom: []
tags:
  - producao
  - deploy
  - automacao
---

## Retomada

ESTADO: aguardando_execucao
AGENTE: coordenador
PROXIMA: ler Secao 19 do DOC_PROTOCOLO para mapear todos os passos manuais a automatizar
LER:
- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 19 — Instalacao)
- templates/README.md (indice de todos os templates)
- templates/backup/lorawan-backup.sh (setup de backup como referencia de script interativo)
DECIDIDO:
- bash, nao Ansible: operador e dono do negocio, nao DevOps
- nao Docker: hardware access (USB concentrador, systemd, sysctl) exige host direto
- script interativo com prompts para Gateway ID, secret, username, etc
- idempotente: verificar se ja instalado antes de reinstalar
- Secao 19 do doc continua como referencia manual
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

A Secao 19 do DOC_PROTOCOLO documenta 18+ passos manuais para deploy from scratch. Isso e aceitavel para documentacao de referencia, mas problematico para:
- Disaster recovery (RUNBOOK-002 precisa de deploy rapido em novo SD card)
- Novos consumidores adotando o kit
- Reprodutibilidade (cada deploy manual tem risco de erro humano)

O script automatiza esses passos mantendo interatividade para configuracoes especificas de cada instalacao.

Depende da TASK-2026-0006 porque deve incluir setup opcional de monitoramento (scripts que serao criados naquela task).

### Decisoes ja tomadas

- Bash puro — acessivel para o perfil do operador
- Nao Docker — interacao com hardware USB, systemd, sysctl exige acesso direto ao host
- Nao Ansible — complexidade nao justificada para single-node
- Interativo com prompts (Gateway ID, secret, username, caminhos)
- Auto-gera secret com `openssl rand -base64 32` quando nao fornecido
- Idempotente: safe to run again

### Perguntas a Investigar

#### Deploy
1. Quais sao os 18+ passos exatos da Secao 19? (mapear para funcoes do script)
2. Qual a ordem correta de instalacao/ativacao dos servicos?
3. Quais pacotes sao instalados via apt vs repositorio externo (ChirpStack)?
4. O script de backup ja tem padrao de prompts interativos reutilizavel?

### Fontes de Referencia

- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 19)
- templates/backup/lorawan-backup.sh (referencia de script interativo)
- templates/ (todos os templates a copiar)

## Checklist

- [ ] Ler Secao 19 do DOC_PROTOCOLO
- [ ] Mapear passos manuais para funcoes do script
- [ ] Criar templates/deploy/setup-loracore.sh
- [ ] Criar templates/deploy/README.md
- [ ] Validar script com bash -n
- [ ] Testar idempotencia (re-execucao segura)
