---
id: TASK-2026-0001
title: Generalizar templates, codecs e docs para servir multiplos projetos consumidores
status: done
phase: concluida
severity: S2
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
closed: 2026-03-29
depends_on: []
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - templates/chirpstack/
  - templates/codecs/
  - templates/README.md
  - docs/REFERENCIA_INTEGRACAO.md
  - docs/QUICK_START.md
  - docs/GUIA_CONSUMIDOR.md
  - docs/adr/
  - docs/operations/tasks/
context_reads:
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
  - docs/REFERENCIA_INTEGRACAO.md
  - docs/QUICK_START.md
  - templates/README.md
  - templates/codecs/cubecell-class-a-sensor.js
  - templates/codecs/rak3172-class-c-actuator.js
  - templates/chirpstack/chirpstack.toml
  - templates/chirpstack/region_us915_0.toml
acceptance:
  - Um novo projeto consegue escolher banco (PostgreSQL/SQLite) usando templates do LoRaCore
  - GUIA_CONSUMIDOR.md cobre o fluxo completo de adocao por projeto externo
  - Codec template funciona como ponto de partida para protocolos customizados de qualquer dominio
  - REFERENCIA_INTEGRACAO.md documenta gRPC downlink com exemplo funcional em Python
  - Nenhuma quebra de compatibilidade com o baseline US915/PostgreSQL existente
restrictions:
  - Regiao fixa US915 sub-band 1 — nao ha suporte multi-regiao
  - Nao criar firmware — firmwares pertencem aos projetos consumidores
hardware_required: []
bom: []
tags:
  - infra
  - templates
  - docs
  - multi-projeto
---

## Retomada

ESTADO: concluida
AGENTE: coordenador
ENCERRADA: 2026-03-29
RESUMO: Todas as 5 entregas implementadas — framework de codecs (4 arquivos), variante SQLite, device profiles (2 JSONs), documentacao gRPC em REFERENCIA_INTEGRACAO.md, GUIA_CONSUMIDOR.md. Baseline US915/PostgreSQL intocado.

## Analise Preliminar

### Contexto

O LoRaCore foi concebido como kit de infraestrutura LoRaWAN generico e reutilizavel, mas na pratica seus templates, codecs e documentacao estao travados numa unica configuracao validada (US915 sub-band 1, PostgreSQL, sx1302_hal). Analisando o CoffeeControl AI como primeiro consumidor real do LoRaCore, ficaram evidentes lacunas que impediriam qualquer projeto similar de adotar o kit sem retrabalho significativo.

O CoffeeControl AI e um sistema de controle termico de secadores de cafe que usa LoRaWAN com sensores Class A e atuadores Class C. Seu backend Python consome uplinks via MQTT e despacha downlinks via gRPC — um padrao de integracao que o LoRaCore nao documenta.

Esta tarefa visa fechar os gaps entre o que o LoRaCore oferece e o que projetos consumidores realmente precisam, sem quebrar o baseline existente.

### Gaps identificados

| Categoria | LoRaCore oferece | Consumidor real precisa |
|-----------|-----------------|------------------------|
| Banco de dados | PostgreSQL hard-coded | SQLite para deployments edge leves |
| Codecs | 2 genericos (battery+uptime) | Guia + template para protocolos customizados |
| Downlink gRPC | Nao documentado | Padrao principal para atuadores Class C |
| Device profiles | Nenhum template exportavel | Class A sensor + Class C atuador prontos para importar |
| Onboarding consumidor | Quick Start isolado do LoRaCore | Guia "como usar LoRaCore no seu projeto" |

### Decisoes ja tomadas

- Regiao fixa US915 sub-band 1 — nao ha suporte multi-regiao (invariante do projeto)
- Codecs do CoffeeControl (A1-A4) NAO entram no LoRaCore — sao exemplos de como o framework de codecs seria usado
- gRPC downlink e documentado como padrao de integracao, nao como feature do LoRaCore

### Perguntas a Investigar

#### ChirpStack SQLite
1. Qual a DSN correta para SQLite no chirpstack.toml do ChirpStack v4?
2. Ha limitacoes conhecidas do SQLite vs PostgreSQL no ChirpStack v4?

#### Codecs
3. Qual a assinatura exata das funcoes decodeUplink/encodeDownlink/decodeDownlink que o ChirpStack v4 espera?
4. Como testar codecs JS localmente antes de subir no ChirpStack?

#### gRPC
5. Qual o pacote Python para o client gRPC do ChirpStack v4? (chirpstack-api)
6. Qual o metodo gRPC para enfileirar downlinks? (DeviceService.Enqueue)

#### Device profiles
7. Qual o formato JSON de exportacao de device profiles no ChirpStack v4?

### Fontes de Referencia

- ChirpStack API reference: gRPC DeviceService
- ChirpStack codec documentation: JavaScript codec functions
- CoffeeControl AI `docs/architecture/arquitetura_projeto.md` — padrao de consumidor real
- CoffeeControl AI `docs/architecture/backend_operacao_atual.md` — integracao MQTT + gRPC em producao

## Entregas

### 1. Variante SQLite do ChirpStack
- `templates/chirpstack/chirpstack-sqlite.toml`
- Nota no README: quando usar PostgreSQL vs SQLite

### 2. Framework de codecs
- `templates/codecs/README.md` — guia de desenvolvimento
- `templates/codecs/CODEC_TEMPLATE.js` — esqueleto
- `templates/codecs/example-thermal-sensor.js` — exemplo realista
- `templates/codecs/example-actuator-bidirectional.js` — exemplo bidirecional

### 3. Documentacao gRPC downlink
- Secao nova em `docs/REFERENCIA_INTEGRACAO.md`

### 4. Device profile templates
- `templates/chirpstack/device-profiles/class-a-sensor-otaa.json`
- `templates/chirpstack/device-profiles/class-c-actuator-otaa.json`

### 5. Guia do consumidor
- `docs/GUIA_CONSUMIDOR.md`

## Checklist

- [x] Investigar formato de device profiles exportaveis do ChirpStack v4
- [x] Investigar DSN SQLite no ChirpStack v4
- [x] Investigar assinatura de codecs JS no ChirpStack v4
- [x] Criar plano TDD (TASK-2026-0001-plan.md)
- [x] Implementar variante SQLite
- [x] Implementar framework de codecs
- [x] Atualizar REFERENCIA_INTEGRACAO.md com gRPC downlink
- [x] Criar device profile templates
- [x] Criar GUIA_CONSUMIDOR.md
- [x] Atualizar templates/README.md
- [x] Revisar todos os arquivos contra docs oficiais
- [x] Testar codecs JS com node
