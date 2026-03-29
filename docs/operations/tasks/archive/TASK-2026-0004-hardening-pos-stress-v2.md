---
id: TASK-2026-0004
title: Hardening pos-stress-test v2
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
  - templates/systemd/
  - templates/sysctl/
  - templates/codecs/
  - examples/firmware/cubecell-otaa-test/
  - CHANGELOG.md
  - templates/README.md
  - docs/operations/tasks/
context_reads:
  - docs/RELATORIO_STRESS_TEST.md
  - docs/RELATORIO_STRESS_TEST_V2.md
  - docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md
acceptance:
  - Todos os 5 servicos LoRaWAN tem CPUWeight ou IOWeight em templates
  - 4 servicos nao-database tem MemoryHigh + MemoryMax
  - sysctl inclui vm.swappiness, vm.dirty_ratio, vm.dirty_background_ratio
  - Codec Device 2 decodifica payload de 14 bytes
  - README do firmware documenta ambos devices
  - CHANGELOG atualizado
  - Indice de templates atualizado
restrictions: []
hardware_required: []
bom: []
tags:
  - resiliencia
  - systemd
  - stress-test
---

## Retomada

ESTADO: concluida
AGENTE: coordenador
PROXIMA: nenhuma — tarefa concluida
LER: []
DECIDIDO:
- MemoryHigh (soft) + MemoryMax (hard) para protecao contra OOM
- CPUWeight=150 para lora-pkt-fwd (3 blips no stress test v2)
- vm.swappiness=10 para reduzir desgaste do microSD (swap pico 327MB)
PENDENTE:
- IP migration (54 refs .129 → .186): tarefa futura separada
- Monitoring/alerting (load > 4): tarefa futura separada

## Analise Preliminar

### Contexto

Os stress tests v1 (2026-03-28) e v2 (2026-03-29) validaram a migracao para MQTT Forwarder (Rust) e revelaram oportunidades de hardening:
- 21% queda de uplinks sob carga maxima (reduzivel com CPU reservation)
- 3 blips no lora-pkt-fwd (96% uptime, precisa CPUWeight)
- Swap de 327MB degradando microSD (vm.swappiness muito alto)
- Templates de systemd incompletos (chirpstack e mosquitto sem override)
- Device 2 do stress test sem codec no ChirpStack

### Decisoes ja tomadas

- MemoryHigh como guard soft (aplica back-pressure) antes de MemoryMax (kill)
- Valores de memoria com 4-10x headroom sobre baseline observado
- Codec Device 2 como arquivo separado (payload diferente do Device 1)
- IP migration fora de escopo (54 arquivos, tarefa separada)

## Checklist

- [x] Criar chirpstack-priority.conf (CPUWeight=200, Nice=-5, MemoryHigh=512M, MemoryMax=768M)
- [x] Criar mosquitto-priority.conf (CPUWeight=150, Nice=-5, MemoryHigh=128M, MemoryMax=256M)
- [x] Adicionar MemoryHigh/Max ao chirpstack-mqtt-fwd-priority.conf
- [x] Adicionar CPUWeight/MemoryHigh/Max ao lora-pkt-fwd.service
- [x] Adicionar vm.swappiness, vm.dirty_ratio, vm.dirty_background_ratio ao sysctl
- [x] Criar codec cubecell-stress-test-device2.js (14 bytes)
- [x] Reescrever README do firmware (dual device)
- [x] Atualizar CHANGELOG
- [x] Atualizar templates/README.md
