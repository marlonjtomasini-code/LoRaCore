---
id: TASK-2026-0002
title: Implementar backup diario com sync para Google Drive
status: done
phase: concluida
severity: S2
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
depends_on: []
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - templates/backup/
  - templates/README.md
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - docs/FAQ.md
  - CLAUDE.md
  - README.md
  - CHANGELOG.md
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - docs/FAQ.md
  - templates/README.md
acceptance:
  - Script de backup gera 3 artefatos (PostgreSQL dump, Redis snapshot, config tar)
  - Script faz sync para Google Drive via rclone com retencao de 30 dias
  - Script degrada graciosamente sem internet ou sem rclone
  - Script de restore e interativo com confirmacao antes de cada passo destrutivo
  - Documentacao atualizada (DOC_PROTOCOLO, FAQ, README, CHANGELOG)
restrictions: []
hardware_required: []
bom: []
tags:
  - backup
  - infraestrutura
  - operacao
---

## Retomada

ESTADO: concluido
AGENTE: coordenador
PROXIMA: deploy no RPi5 (responsabilidade do usuario)
LER:
- templates/backup/README.md
DECIDIDO:
- rclone como ferramenta de sync (padrao de mercado, headless, repos oficiais)
- script unico backup+sync (fases independentes, degradacao graceful)
- execucao como root (necessario para pg_dump, redis, configs em /etc/)
- retencao 30 dias local e remoto
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

O RPi5 hospeda toda a infraestrutura LoRaWAN (ChirpStack, PostgreSQL, Redis, Mosquitto). A Secao 17.4 do DOC_PROTOCOLO documentava a intencao de backup diario, mas o script nunca foi implementado. O FAQ alertava que "se o SD morrer, o backup local morre junto". Esta tarefa implementa o script completo com sync remoto para Google Drive.

### Decisoes ja tomadas

- Google Drive como destino remoto (escolha do usuario)
- rclone como ferramenta de sync
- Backup diario as 3h via cron do root
- Retencao de 30 dias

### Entregaveis

1. `templates/backup/lorawan-backup.sh` — script de backup com 8 fases independentes
2. `templates/backup/lorawan-restore.sh` — script de restore interativo com --date, --from-remote, --dry-run
3. `templates/backup/README.md` — guia completo de setup (rclone, auth headless, cron, troubleshooting)
4. Atualizacoes em DOC_PROTOCOLO (17.4, 17.5, 17.6), FAQ, README, CLAUDE.md, CHANGELOG, templates/README.md

## Checklist

- [x] Criar templates/backup/README.md
- [x] Criar templates/backup/lorawan-backup.sh
- [x] Criar templates/backup/lorawan-restore.sh
- [x] Atualizar templates/README.md
- [x] Atualizar DOC_PROTOCOLO Secao 17.4, 17.5, 17.6
- [x] Atualizar FAQ.md
- [x] Atualizar CLAUDE.md e README.md
- [x] Atualizar CHANGELOG.md
