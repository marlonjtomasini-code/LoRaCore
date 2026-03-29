# ADR-0001: MQTT Forwarder (Rust) vs Gateway Bridge (Go)

## Status

Aceito (2026-03-28)

## Contexto

O LoRaCore precisa de um componente que converta o protocolo UDP Semtech (enviado pelo Packet Forwarder) para MQTT (consumido pelo ChirpStack). Originalmente, o ChirpStack fornecia o **Gateway Bridge** escrito em Go. Em 2025, o ChirpStack introduziu o **MQTT Forwarder** escrito em Rust como alternativa.

O RPi5 roda a stack completa (6 camadas) em hardware limitado (4 cores ARM, 8GB RAM, microSD). A confiabilidade sob carga e critica para operacao industrial.

## Opcoes Consideradas

1. **ChirpStack Gateway Bridge (Go)** — componente original, 14MB, garbage collector, 7 threads
2. **ChirpStack MQTT Forwarder (Rust)** — alternativa oficial, 3.7MB, sem GC, binario unico

## Decisao

Adotar o **MQTT Forwarder (Rust)**.

## Justificativa

Stress test com CPU 100% + I/O saturado por 5 minutos (stress-ng com 10 workers):

| Metrica | Gateway Bridge (Go) | MQTT Forwarder (Rust) |
|---------|--------------------|-----------------------|
| Uplinks entregues ao ChirpStack | **0 (0%)** | **45 (97.8%)** |
| Temperatura pico | 71.0 C | 55.6 C |
| Swap pico | 523 MB | 52 MB |

O Gateway Bridge perdeu 100% dos pacotes sob CPU saturada. O garbage collector do Go introduz pausas imprevisiveis que, combinadas com contencao de CPU, impediram completamente o processamento de pacotes UDP.

O MQTT Forwarder (Rust), sem GC e com 3.7MB de memoria, manteve 97.8% de entrega sob a mesma carga extrema.

## Consequencias

**Positivas:**
- Resiliencia drasticamente superior sob carga
- Consumo de memoria 75% menor (3.7MB vs ~15MB)
- Temperatura 15C menor (menos overhead de processamento)
- Binario unico, sem dependencias de runtime

**Negativas:**
- O MQTT Forwarder publica em Protobuf nos topicos de gateway (nao JSON), o que dificulta debug direto desses topicos — mas os topicos de aplicacao (que sao os consumidos por integracao) continuam em JSON

## Referencia

- [RELATORIO_STRESS_TEST.md](../RELATORIO_STRESS_TEST.md) — dados completos do teste
- [DOC_PROTOCOLO Secao 5](../DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#5-camada-2---mqtt-forwarder-udp-para-mqtt) — configuracao do MQTT Forwarder
- [DOC_PROTOCOLO Secao 21](../DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#21-resultados-de-stress-test) — comparativo antes/depois
