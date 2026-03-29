# Relatorio de Stress Test v3 — 2 Devices Simultaneos

**Data**: 2026-03-29
**Duracao**: 2 rodadas de 5 minutos (baseline + stress)
**Objetivo**: Avaliar delivery de 2 devices LoRaWAN simultaneos sob carga extrema, comparando com v1 (Go, 0%) e v2 (Rust, 79%)

---

## 1. Configuracao do Teste

### 1.1 Devices

| Device | DevEUI | TX Interval | Modo | Payload | Retries |
|--------|--------|------------|------|---------|---------|
| D1 (baseline) | `3daa1dd8e5ceb357` | 5s | Unconfirmed | 7 bytes | — |
| D2 (agressivo) | `4bcc2ef7a1d06489` | 3s | Confirmed | 14 bytes | 8 |

Ambos: CubeCell HTCC-AB01, OTAA, US915 SB1 (canais 0-7), SF7/125kHz, 20 dBm.

### 1.2 Infraestrutura (RPi5)

- ChirpStack v4.17.0 + MQTT Forwarder (Rust 4.5.1)
- Hardening ativo: systemd MemoryHigh/Max, CPUWeight, sysctl vm.swappiness=10
- 6 servicos: lora-pkt-fwd, chirpstack-mqtt-forwarder, mosquitto, chirpstack, postgresql, redis-server

### 1.3 Carga do Stress-ng

```bash
stress-ng --cpu 4 --vm 2 --vm-bytes 512M --io 2 --hdd 2 --timeout 300
```

10 workers: CPU 4 cores saturados + 1 GB alocacao continua + I/O sync + escrita disco.

---

## 2. Resultados — Delivery

### 2.1 Baseline (sem stress, 5 min)

| Device | TX Esperados | Recebidos | Delivery |
|--------|-------------|-----------|----------|
| D1 (unconfirmed, 5s) | 60 | 49 | **81%** |
| D2 (confirmed, 3s) | 100 | 74 | **74%** |
| **Total** | **160** | **123** | **76%** |

Nota: delivery <100% mesmo sem stress. Causas:
- 2 devices disputam 8 canais (colisoes RF)
- D2 confirmed gera ACK downlinks que ocupam janelas RX, reduzindo slots disponiveis
- Jitter natural do LoRaWAN (duty cycle, random delay)

### 2.2 Sob Stress (stress-ng, 5 min)

| Device | TX Esperados | Recebidos | Delivery | Delta vs Baseline |
|--------|-------------|-----------|----------|-------------------|
| D1 (unconfirmed, 5s) | 60 | 51 | **85%** | +4pp |
| D2 (confirmed, 3s) | 100 | 11 | **11%** | **-63pp** |
| **Total** | **160** | **62** | **38%** | -38pp |

### 2.3 Analise por Device

**D1 (unconfirmed) — resiliencia surpreendente:**
- Delivery SUBIU de 81% para 85% sob stress
- Hipotese: com D2 falhando, menos contencao nos canais RF e menos ACK downlinks competindo
- O MQTT Forwarder (Rust) processa unconfirmed uplinks de forma extremamente eficiente

**D2 (confirmed) — colapso sob stress:**
- Delivery caiu de 74% para 11% — queda de 85%
- O modo confirmed exige processamento bidirecional: uplink + ACK downlink
- Sob CPU 100%, o ChirpStack nao consegue gerar ACKs a tempo
- Sem ACK, o device faz retries (ate 8x), saturando os canais RF
- Cascata: retries sem ACK → mais carga no server → menos ACKs → mais retries

---

## 3. Metricas do Sistema

### 3.1 Resumo Comparativo

| Metrica | Baseline (media) | Stress (media) | Stress (pico) |
|---------|-----------------|----------------|---------------|
| **CPU idle** | 96% | 0% | 0% |
| **Memoria** | 567 MB (7%) | 1150 MB (14%) | 1281 MB (16%) |
| **Swap** | 72 MB | 180 MB | 580 MB |
| **Temperatura** | 56°C | 72°C | 75.5°C |
| **Load Average (1m)** | 0.1 | 13.5 | 16.1 |

### 3.2 Estabilidade dos Servicos

| Servico | Baseline | Stress | Nota |
|---------|----------|--------|------|
| postgresql | 100% | 100% | — |
| redis-server | 100% | 100% | — |
| mosquitto | 100% | 100% | — |
| chirpstack | 100% | 100% | — |
| chirpstack-mqtt-forwarder | 100% | 100% | — |
| lora-pkt-fwd | 100% | **~97%** | **Caiu brevemente, systemd reiniciou** |

**Achado novo:** `lora-pkt-fwd` (C) caiu pela primeira vez nos 3 testes. Nos v1/v2 (1 device) nunca havia caido. Hipotese: com 2 devices, o volume de PUSH_DATA dobra e sob I/O extremo o processo C leve nao sobrevive.

---

## 4. Evolucao Historica

| Teste | Data | Forwarder | Devices | Stress | Delivery Total |
|-------|------|-----------|---------|--------|---------------|
| v1 | 2026-03-28 | Gateway Bridge (Go) | 1 | CPU+VM+IO+HDD | **0%** |
| v2 | 2026-03-29 | MQTT Forwarder (Rust) | 1 | CPU+VM+IO+HDD | **79%** |
| v3 baseline | 2026-03-29 | MQTT Forwarder (Rust) | 2 | nenhum | **76%** |
| v3 stress | 2026-03-29 | MQTT Forwarder (Rust) | 2 | CPU+VM+IO+HDD | **38%** |

### 4.1 Interpretacao

1. **Rust vs Go:** a migracao para MQTT Forwarder (Rust) eliminou o gargalo de 0% → 79% (1 device)
2. **2 devices sem stress:** 76% delivery mostra que o limite esta no RF (colisoes de canal), nao no software
3. **2 devices com stress:** D1 unconfirmed se mantem (85%), mas D2 confirmed colapsa (11%)
4. **Confirmed mode e o gargalo:** o processamento bidirecional (ACK) e o ponto de falha sob carga

---

## 5. Conclusoes

### 5.1 Pontos Fortes

1. **MQTT Forwarder (Rust)** continua resiliente — D1 unconfirmed manteve 85% sob stress total
2. **Hardening funciona**: systemd reiniciou lora-pkt-fwd automaticamente apos queda
3. **5 de 6 servicos** permaneceram 100% disponiveis durante o stress
4. **Temperatura controlada**: 75.5°C pico, abaixo do throttling (85°C)
5. **Sem OOM kill**: swap absorveu picos (580 MB) sem matar processos

### 5.2 Pontos Criticos

1. **Confirmed mode colapsa sob stress** — de 74% para 11%
2. **lora-pkt-fwd caiu** pela primeira vez com 2 devices sob stress
3. **Delivery total 38%** — inaceitavel para producao sob carga

### 5.3 Recomendacoes

| Acao | Prioridade | Efeito Esperado |
|------|-----------|-----------------|
| **Usar unconfirmed para sensores** — reservar confirmed so para atuadores criticos | Alta | Eliminar cascata de retries; D1 provou 85% sob stress |
| **Aumentar TX interval** — 15-30s em producao (vs 3-5s do teste) | Alta | Menos colisoes RF, menos carga no server |
| **cgroup dedicado para lora-pkt-fwd** com CPUShares mais alto | Media | Prevenir queda do packet forwarder |
| **Monitorar fCnt gaps** no ChirpStack para detectar perda de pacotes | Media | Visibilidade operacional |
| **Segundo gateway** para redundancia | Baixa | Eliminaria ponto unico de falha RF |

### 5.4 Contexto para Producao (50 devices)

Com TX interval de 30s (padrao producao):
- 50 devices × 1 msg/30s = 1.67 msg/s (vs 0.53 msg/s deste teste)
- Usando unconfirmed: delivery esperada >90% baseado em D1
- CPU estimada <5% (sem stress artificial)
- **Risco real**: cenario de stress (CPU 100%) e improvavel em producao

---

## 6. Dados Brutos

Localizacao na Raspberry Pi:
```
/home/<USER>/stress_v3_results/
  baseline_mqtt.log       # Uplinks MQTT coletados durante baseline
  baseline_metrics.csv    # Metricas do sistema a cada 5s (baseline)
  stress_mqtt.log         # Uplinks MQTT coletados durante stress
  stress_metrics.csv      # Metricas do sistema a cada 5s (stress)
  stress_services.log     # Registro de quedas de servico durante stress
```

### 6.1 Comando do stress-ng
```bash
stress-ng --cpu 4 --vm 2 --vm-bytes 512M --io 2 --hdd 2 --timeout 300
# Resultado: passed: 10: cpu (4) vm (2) io (2) hdd (2) — 5 min 10s
```
