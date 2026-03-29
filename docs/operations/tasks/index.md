# Indice de Tarefas — LoRaCore

Status: ATIVO
Ultima revisao: 2026-03-29 (producao roadmap adicionado)

## Como consultar

- `Leia docs/operations/tasks/index.md e me mostre as tarefas pendentes, em progresso e bloqueadas.`
- `Retome a TASK-YYYY-NNNN lendo o arquivo da tarefa e os documentos obrigatorios.`

## Tarefas abertas

| ID | Status | Fase | Sev | Titulo | Deps | Plano |
|---|---|---|---|---|---|---|
| TASK-2026-0005 | pending | analise | S3 | Release Engineering — tags, semver, GitHub Releases | — | — |
| TASK-2026-0006 | pending | analise | S2 | Templates de monitoramento e observabilidade leve | — | — |
| TASK-2026-0007 | pending | analise | S3 | Testes automatizados de codecs no CI | — | — |
| TASK-2026-0008 | pending | analise | S2 | Runbooks operacionais para incidentes de producao | TASK-0006 | — |
| TASK-2026-0009 | pending | analise | S3 | Documentacao de seguranca expandida e ADR confirmed mode | — | — |
| TASK-2026-0010 | pending | analise | S2 | Script de automacao de deploy | TASK-0006 | — |

## Tarefas bloqueadas

| ID | Status | Fase | Sev | Titulo | Bloqueio |
|---|---|---|---|---|---|
| TASK-2026-0003 | blocked | analise | S3 | Migrar backup rclone de OAuth para Google Service Account | usuario: criar Google Service Account |

## Arquivadas recentes

| ID | Status | Titulo | Encerrada |
|---|---|---|---|
| TASK-2026-0004 | done | Hardening pos-stress-test v2 (systemd, sysctl, codec) | 2026-03-29 |
| TASK-2026-0002 | done | Implementar backup diario com sync para Google Drive | 2026-03-29 |
| TASK-2026-0001 | done | Generalizar templates, codecs e docs para multiplos projetos consumidores | 2026-03-29 |
