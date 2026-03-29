# Documentacao LoRaCore

Indice da documentacao do kit de infraestrutura LoRaWAN.

## Documentos Canonicos

| Documento | Descricao |
|-----------|-----------|
| [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) | Referencia autoritativa da infraestrutura — 22 secoes cobrindo todo o stack, da camada fisica ao monitoramento |
| [RELATORIO_STRESS_TEST.md](RELATORIO_STRESS_TEST.md) | Validacao de performance sob carga extrema (CPU 100%, memoria saturada, I/O intenso) |
| [RELATORIO_STRESS_TEST_V2.md](RELATORIO_STRESS_TEST_V2.md) | Validacao do MQTT Forwarder (Rust) sob carga progressiva (6 fases, 79% entrega sob stress total) |
| [RELATORIO_STRESS_TEST_V3.md](RELATORIO_STRESS_TEST_V3.md) | Validacao de 2 devices simultaneos sob carga extrema (D1=85%, D2=11%) |

## Guias Praticos

| Documento | Descricao |
|-----------|-----------|
| [QUICK_START.md](QUICK_START.md) | Do zero ao primeiro uplink em 30 minutos (infra ja instalada) |
| [GUIA_CONSUMIDOR.md](GUIA_CONSUMIDOR.md) | Como adotar o LoRaCore em um projeto externo — passo a passo completo |
| [REFERENCIA_INTEGRACAO.md](REFERENCIA_INTEGRACAO.md) | Como consumir dados via MQTT, REST API e gRPC — schemas JSON, endpoints, exemplos Python/Bash |
| [FAQ.md](FAQ.md) | Perguntas frequentes sobre capacidade, manutencao, operacao e firmware |
| [GLOSSARIO.md](GLOSSARIO.md) | Definicoes dos termos tecnicos LoRaWAN usados na documentacao |
| [GUIA_CLAUDE_CODE.md](GUIA_CLAUDE_CODE.md) | Guia rapido para uso do Claude Code no projeto |

## Runbooks Operacionais

| Runbook | Cenario |
|---------|---------|
| [RUNBOOK-001](runbooks/RUNBOOK-001-service-failure.md) | Servico systemd inativo |
| [RUNBOOK-002](runbooks/RUNBOOK-002-sd-card-failure.md) | Falha de microSD / filesystem read-only |
| [RUNBOOK-003](runbooks/RUNBOOK-003-gateway-not-receiving.md) | Gateway nao recebe uplinks |
| [RUNBOOK-004](runbooks/RUNBOOK-004-backup-failure.md) | Falha no backup diario |
| [RUNBOOK-005](runbooks/RUNBOOK-005-device-offline.md) | Device offline |

## Decisoes Arquiteturais (ADR)

| ADR | Titulo |
|-----|--------|
| [ADR-0001](adr/ADR-0001-mqtt-forwarder-rust-vs-gateway-bridge-go.md) | MQTT Forwarder (Rust) vs Gateway Bridge (Go) |
| [ADR-0002](adr/ADR-0002-us915-subband-1.md) | US915 Sub-band 1 |
| [ADR-0003](adr/ADR-0003-mqtt-como-camada-de-integracao.md) | MQTT como camada de integracao |
| [ADR-0004](adr/ADR-0004-observabilidade-scripts-vs-prometheus.md) | Observabilidade via scripts shell vs Prometheus/Grafana |
| [ADR-0005](adr/ADR-0005-confirmed-uplink-degradacao-sob-stress.md) | Confirmed uplinks degradam sob stress — usar unconfirmed para telemetria |

## Gestao de Tarefas

O sistema de backlog e tarefas esta em [`operations/tasks/`](operations/tasks/README.md).

## Recursos Relacionados

- [Templates de configuracao](../templates/README.md) — configs reutilizaveis extraidas da documentacao
- [Exemplos](../examples/README.md) — firmwares de teste e validacao
