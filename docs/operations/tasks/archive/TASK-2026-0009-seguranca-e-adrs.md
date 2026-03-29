---
id: TASK-2026-0009
title: Documentacao de seguranca expandida e ADR confirmed mode
status: done
phase: concluido
severity: S3
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
  - SECURITY.md
  - templates/mosquitto/password_auth.conf
  - docs/adr/ADR-0005-confirmed-uplink-degradacao-sob-stress.md
context_reads:
  - SECURITY.md
  - templates/mosquitto/mosquitto.conf
  - docs/RELATORIO_STRESS_TEST_V3.md
  - docs/adr/
acceptance:
  - SECURITY.md expandido com topologia de rede (portas localhost vs LAN)
  - SECURITY.md documenta decisao explicita sobre MQTT ACLs
  - SECURITY.md inclui checklist SSH hardening
  - SECURITY.md documenta rotacao de API tokens ChirpStack
  - templates/mosquitto/password_auth.conf existe como template opcional
  - ADR-0005 documenta degradacao de confirmed uplinks sob stress (11% vs 85% unconfirmed)
  - ADR-0005 recomenda unconfirmed para telemetria e confirmed so para comandos criticos
restrictions: []
hardware_required: []
bom: []
tags:
  - producao
  - seguranca
  - adr
---

## Retomada

ESTADO: concluido
AGENTE: coordenador
RESULTADO:
- SECURITY.md expandido: topologia de rede, decisao MQTT ACLs, SSH hardening, rotacao tokens
- templates/mosquitto/password_auth.conf criado como template opcional
- ADR-0005: confirmed uplinks degradam sob stress (11% vs 85%)
- docs/README.md e templates/README.md atualizados

## Analise Preliminar

### Contexto

Duas lacunas distintas agrupadas por serem ambas de documentacao e baixo esforco:

1. **SECURITY.md** tem 29 linhas. A postura de seguranca do projeto e adequada para rede isolada (AES-128, offline, localhost), mas a documentacao nao explicita isso para operadores. Um operador precisa saber quais portas estao expostas, por que MQTT e anonimo, e como endurecer se a rede mudar.

2. **Confirmed mode** degradou a 11% no stress test v3 enquanto unconfirmed manteve 85%. Isso nao e bug — e limitacao do protocolo LoRaWAN Class A sob carga. Precisa virar ADR para que consumidores nao usem confirmed para telemetria de sensores.

### Decisoes ja tomadas

- Nao implementar ACLs agora — apenas documentar e fornecer template opcional
- ADR-0005 e decisao de guidance, nao de implementacao
- Formato dos ADRs segue padrao dos existentes (ADR-0001 a 0003)

### Perguntas a Investigar

#### Seguranca
1. Quais portas o ChirpStack escuta? (8080 web, 8090 REST — verificar se sao localhost ou 0.0.0.0)
2. O PostgreSQL aceita conexoes remotas ou so localhost? (verificar pg_hba.conf via docs)
3. O Redis esta bind a localhost? (verificar configuracao)

#### Confirmed mode
1. Qual a taxa exata de delivery de D1 (unconfirmed) vs D2 (confirmed) no stress test v3?
2. O que causa a degradacao? (retransmissoes do device saturam o duty cycle)

### Fontes de Referencia

- SECURITY.md (estado atual)
- docs/RELATORIO_STRESS_TEST_V3.md (dados quantitativos)
- docs/adr/ADR-0001 a ADR-0003 (formato de referencia)
- templates/mosquitto/mosquitto.conf

## Checklist

- [x] Ler SECURITY.md atual
- [x] Ler config do Mosquitto para entender postura atual
- [x] Ler stress test v3 para dados de confirmed vs unconfirmed
- [x] Expandir SECURITY.md (topologia, ACLs, SSH, tokens)
- [x] Criar templates/mosquitto/password_auth.conf
- [x] Criar docs/adr/ADR-0005-confirmed-uplink-degradacao-sob-stress.md
