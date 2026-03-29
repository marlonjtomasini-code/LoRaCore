# Documentacao LoRaCore

Indice da documentacao do kit de infraestrutura LoRaWAN.

## Documentos Canonicos

| Documento | Descricao |
|-----------|-----------|
| [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) | Referencia autoritativa da infraestrutura — 22 secoes cobrindo todo o stack, da camada fisica ao monitoramento |
| [RELATORIO_STRESS_TEST.md](RELATORIO_STRESS_TEST.md) | Validacao de performance sob carga extrema (CPU 100%, memoria saturada, I/O intenso) |

## Guias Praticos

| Documento | Descricao |
|-----------|-----------|
| [QUICK_START.md](QUICK_START.md) | Do zero ao primeiro uplink em 30 minutos (infra ja instalada) |
| [GUIA_CONSUMIDOR.md](GUIA_CONSUMIDOR.md) | Como adotar o LoRaCore em um projeto externo — passo a passo completo |
| [REFERENCIA_INTEGRACAO.md](REFERENCIA_INTEGRACAO.md) | Como consumir dados via MQTT, REST API e gRPC — schemas JSON, endpoints, exemplos Python/Bash |
| [FAQ.md](FAQ.md) | Perguntas frequentes sobre capacidade, manutencao, operacao e firmware |
| [GLOSSARIO.md](GLOSSARIO.md) | Definicoes dos termos tecnicos LoRaWAN usados na documentacao |
| [GUIA_CLAUDE_CODE.md](GUIA_CLAUDE_CODE.md) | Guia rapido para uso do Claude Code no projeto |

## Decisoes Arquiteturais (ADR)

| ADR | Titulo |
|-----|--------|
| [ADR-0001](adr/ADR-0001-mqtt-forwarder-rust-vs-gateway-bridge-go.md) | MQTT Forwarder (Rust) vs Gateway Bridge (Go) |
| [ADR-0002](adr/ADR-0002-us915-subband-1.md) | US915 Sub-band 1 |
| [ADR-0003](adr/ADR-0003-mqtt-como-camada-de-integracao.md) | MQTT como camada de integracao |

## Gestao de Tarefas

O sistema de backlog e tarefas esta em [`operations/tasks/`](operations/tasks/README.md).

## Recursos Relacionados

- [Templates de configuracao](../templates/README.md) — configs reutilizaveis extraidas da documentacao
- [Exemplos](../examples/README.md) — firmwares de teste e validacao
