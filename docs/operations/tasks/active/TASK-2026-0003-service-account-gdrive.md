---
id: TASK-2026-0003
title: Migrar backup rclone de OAuth para Google Service Account
status: pending
phase: analise
severity: S3
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
depends_on:
  - TASK-2026-0002
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - templates/backup/
context_reads:
  - templates/backup/README.md
  - templates/backup/lorawan-backup.sh
acceptance:
  - rclone configurado com Service Account JSON (sem OAuth token)
  - Backup roda sem expiracao de credenciais
  - README.md do backup atualizado com instrucoes de Service Account
restrictions: []
hardware_required: []
bom: []
tags:
  - backup
  - infraestrutura
  - operacao
---

## Retomada

ESTADO: aguardando_triagem
AGENTE: coordenador
PROXIMA: usuario criar projeto no Google Cloud Console e Service Account
LER:
- templates/backup/README.md
DECIDIDO:
- Service Account e a solucao correta para credenciais permanentes em servidor headless
- OAuth atual funciona mas pode expirar (~6 meses ou ao mudar senha Google)
PENDENTE:
- Usuario precisa acessar Google Cloud Console para criar o projeto e a Service Account

## Analise Preliminar

### Contexto

O backup da RPi5 para Google Drive (TASK-2026-0002) usa OAuth com refresh token via rclone. O token pode expirar se o usuario mudar a senha do Google, revogar acesso, ou por politicas de seguranca do Google. Uma Service Account gera uma chave JSON permanente — ideal para servidores headless sem intervencao humana.

### Passos previstos

1. **Usuario no browser:** Google Cloud Console → criar projeto → ativar Drive API → criar Service Account → baixar JSON
2. **Agente na RPi5:** configurar rclone com `service_account_file` → compartilhar pasta Drive com email da SA → testar backup → remover OAuth antigo
3. **Agente no repo:** atualizar `templates/backup/README.md` com instrucoes de Service Account

### Fontes de Referencia

- https://rclone.org/drive/#service-account-support
- https://console.cloud.google.com/
