# Architecture Decision Records (ADR)

Registro das decisoes arquiteturais do LoRaCore. Cada ADR documenta uma escolha tecnica, as alternativas consideradas e a justificativa.

## Indice

| ADR | Titulo | Status | Data |
|-----|--------|--------|------|
| [0001](ADR-0001-mqtt-forwarder-rust-vs-gateway-bridge-go.md) | MQTT Forwarder (Rust) vs Gateway Bridge (Go) | Aceito | 2026-03-28 |
| [0002](ADR-0002-us915-subband-1.md) | US915 Sub-band 1 | Aceito | 2026-03-28 |
| [0003](ADR-0003-mqtt-como-camada-de-integracao.md) | MQTT como camada de integracao | Aceito | 2026-03-28 |
| [0004](ADR-0004-observabilidade-scripts-vs-prometheus.md) | Observabilidade via scripts vs Prometheus | Aceito | 2026-03-29 |
| [0005](ADR-0005-confirmed-uplink-degradacao-sob-stress.md) | Confirmed uplink degradacao sob stress | Aceito | 2026-03-29 |
| [0006](ADR-0006-alertas-ntfy-vs-telegram-email.md) | Alertas externos via ntfy.sh vs Telegram vs Email | Aceito | 2026-03-31 |
| [0007](ADR-0007-acesso-remoto-ssh-tunnel-vs-vpn.md) | Acesso remoto via reverse SSH tunnel vs VPN | Aceito | 2026-03-31 |

## Formato

Cada ADR segue a estrutura: Status, Contexto, Opcoes Consideradas, Decisao, Justificativa, Consequencias, Referencia.
