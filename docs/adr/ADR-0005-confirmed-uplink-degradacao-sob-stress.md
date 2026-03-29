# ADR-0005: Confirmed Uplinks Degradam Sob Stress — Usar Unconfirmed para Telemetria

**Data:** 2026-03-29
**Status:** Aceito
**Contexto:** TASK-2026-0009, validado pelo stress test v3

## Decisao

Recomendar **unconfirmed uplinks** como padrao para telemetria de sensores. Reservar **confirmed uplinks** apenas para comandos criticos de atuadores com < 5 devices e < 1 msg/min por device.

## Contexto

O stress test v3 operou 2 devices simultaneos sob carga extrema (CPU 100%, I/O saturado) no RPi5:

- **Device D1** (unconfirmed, TX 5s): **85% delivery** sob stress (81% baseline)
- **Device D2** (confirmed, TX 3s): **11% delivery** sob stress (74% baseline)

A diferenca de 85% vs 11% nao e um bug — e uma consequencia arquitetural do protocolo LoRaWAN Class A.

## Mecanismo de Degradacao

```
Confirmed uplink: Device TX → Gateway RX → ChirpStack processa → Gera ACK → Gateway TX → Device RX
Unconfirmed uplink: Device TX → Gateway RX → ChirpStack processa → (fim)
```

1. Confirmed requer processamento bidirecional (uplink + downlink ACK)
2. Sob carga de CPU, ChirpStack nao gera ACKs em tempo habil
3. Device nao recebe ACK → retransmite (ate 8x conforme LoRaWAN spec)
4. Retransmissoes saturam os canais RF (8 canais US915 sub-band 1)
5. Mais retransmissoes → menos ACKs → cascata de degradacao

Com unconfirmed, o device transmite e segue adiante. Nao ha retransmissao, nao ha cascata.

## Quando usar cada modo

| Cenario | Modo recomendado | Justificativa |
|---------|------------------|---------------|
| Telemetria de sensores (temperatura, umidade, bateria) | **Unconfirmed** | Perda de 1 leitura e toleravel; proxima leitura vem em segundos/minutos |
| Status periodico de atuadores | **Unconfirmed** | Informativo, nao critico |
| Comando para atuador (ligar, desligar, posicionar) | **Confirmed** | Acao critica, precisa de garantia de entrega |
| Alarme critico (unico, nao periodico) | **Confirmed** | Evento raro, aceita custo de retransmissao |

## Limites seguros para confirmed mode

Baseado nos dados do stress test v3:

- Maximo **5 devices** em confirmed mode simultaneamente
- Maximo **1 mensagem por minuto** por device confirmed
- Funciona bem em **baseline** (sem stress): 74% delivery com TX 3s
- **Colapsa sob carga**: 11% delivery quando CPU esta saturada

## Consequencias

- **Positivo**: telemetria com unconfirmed mantem 85% delivery mesmo sob stress extremo
- **Positivo**: menos retransmissoes = menos colisoes RF = mais capacidade para outros devices
- **Positivo**: menor consumo de bateria nos devices (sem esperar ACK)
- **Negativo**: telemetria sem garantia de entrega (aceitavel para leituras periodicas)
- **Mitigacao**: para dados criticos, usar logica de application-layer acknowledgment

## Referencia

- [RELATORIO_STRESS_TEST_V3.md](../RELATORIO_STRESS_TEST_V3.md) — dados quantitativos completos
- LoRaWAN 1.0.3 spec, Section 18 — Class A retransmission behavior
