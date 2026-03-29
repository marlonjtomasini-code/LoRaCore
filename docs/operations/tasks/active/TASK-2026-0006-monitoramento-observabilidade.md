---
id: TASK-2026-0006
title: Templates de monitoramento e observabilidade leve
status: pending
phase: analise
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
  - templates/monitoring/
  - templates/README.md
  - docs/adr/ADR-0004-observabilidade-scripts-vs-prometheus.md
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - templates/backup/lorawan-backup.sh
  - templates/README.md
acceptance:
  - templates/monitoring/health_check.sh existe e valida com bash -n
  - templates/monitoring/watchdog_concentrator.sh existe e valida com bash -n
  - templates/monitoring/device_monitor.sh existe e valida com bash -n
  - templates/monitoring/daily_report.sh existe e valida com bash -n
  - templates/monitoring/logrotate-lorawan.conf existe
  - templates/monitoring/README.md documenta placeholders, cron setup e logrotate
  - templates/README.md atualizado com diretorio monitoring
  - ADR-0004 documenta decisao scripts shell vs Prometheus
  - scripts usam formato de log consistente com lorawan-backup.sh
  - scripts degradam graciosamente se servico nao existir
restrictions:
  - bash puro, zero dependencias externas
  - sem Prometheus, Grafana, Alertmanager ou daemons persistentes
hardware_required: []
bom: []
tags:
  - producao
  - monitoramento
  - observabilidade
---

## Retomada

ESTADO: aguardando_execucao
AGENTE: coordenador
PROXIMA: ler Secao 17 do DOC_PROTOCOLO para especificacao dos scripts, ler lorawan-backup.sh para formato de log
LER:
- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 17)
- templates/backup/lorawan-backup.sh (linhas 1-30 para formato de log, linhas 169-171 para referencia aos scripts)
DECIDIDO:
- shell scripts + logs > Prometheus/Grafana para RPi5 single-node (decisao a documentar no ADR-0004)
- formato de log: [timestamp] mensagem (igual ao backup)
- degradacao graceful: scripts devem funcionar mesmo se nem todos os 7 servicos estiverem instalados
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

A DOC_PROTOCOLO Secao 17 descreve 3 scripts de monitoramento (health_check.sh, watchdog_concentrator.sh, device_monitor.sh) que nao existem como templates reutilizaveis. O script de backup referencia esses scripts nas linhas 169-171 para arquivo. Um consumidor seguindo a documentacao nao consegue reproduzir o monitoramento. Este e o maior gap operacional identificado.

Alem dos scripts basicos, o projeto precisa de um relatorio diario (dashboard textual) e logrotate para evitar estouro de disco no microSD.

A decisao de nao usar Prometheus/Grafana e deliberada: o RPi5 ja roda 7 servicos, adicionar stack de monitoramento consumiria 200-400MB RAM adicionais e CPU para renderizacao de graficos. Scripts shell + cron fornecem 90% da visibilidade com 1% da complexidade.

### Decisoes ja tomadas

- Bash puro, sem dependencias externas
- Formato de log identico ao lorawan-backup.sh
- health_check.sh: status servicos, memoria, disco, PULL_ACK, temperatura, load average
- watchdog_concentrator.sh: verifica PULL_ACK 90s, reinicia lora-pkt-fwd se ausente
- device_monitor.sh: consulta ChirpStack REST API, alerta offline >180s
- daily_report.sh: uplinks 24h, last-seen, uptime, disco, memoria, temperatura, status backup
- logrotate: semanal, 12 semanas retencao, compressao

### Perguntas a Investigar

#### Scripts de monitoramento
1. Qual o formato exato de log do lorawan-backup.sh? (ler primeiras linhas do script)
2. A Secao 17 especifica thresholds exatos para os alertas?
3. Quais placeholders usar nos scripts? (consistente com outros templates)

#### Observabilidade
1. O ChirpStack REST API retorna contagem de uplinks por periodo? (para daily_report)
2. Como obter temperatura do RPi5 via CLI? (vcgencmd measure_temp)

### Fontes de Referencia

- docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md (Secao 17)
- templates/backup/lorawan-backup.sh (formato de log e referencia a scripts)
- docs/RELATORIO_STRESS_TEST_V3.md (thresholds de stress identificados)

## Checklist

- [ ] Ler Secao 17 do DOC_PROTOCOLO para especificacoes
- [ ] Ler lorawan-backup.sh para formato de log
- [ ] Criar templates/monitoring/health_check.sh
- [ ] Criar templates/monitoring/watchdog_concentrator.sh
- [ ] Criar templates/monitoring/device_monitor.sh
- [ ] Criar templates/monitoring/daily_report.sh
- [ ] Criar templates/monitoring/logrotate-lorawan.conf
- [ ] Criar templates/monitoring/README.md
- [ ] Atualizar templates/README.md com diretorio monitoring
- [ ] Criar docs/adr/ADR-0004-observabilidade-scripts-vs-prometheus.md
- [ ] Validar todos os scripts com bash -n
