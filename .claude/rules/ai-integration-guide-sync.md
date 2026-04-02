# Sincronizacao do AI Integration Guide

`docs/LORACORE_AI_INTEGRATION_GUIDE.md` e o artefato principal deste projeto — e o unico arquivo que projetos consumidores precisam para integrar com o LoRaCore.

## Quando atualizar

Ao modificar qualquer um destes itens, atualizar a secao correspondente do AI Integration Guide **no mesmo commit**:

1. **Versoes do stack** (ChirpStack, PostgreSQL, Redis, Mosquitto) → Secoes 1, header
2. **Configuracao de rede** (canais, sub-band, DR table, RX windows) → Secao 2
3. **Formato de payload** (convencoes, encoding patterns) → Secao 3
4. **Codecs** (template, exemplos, constraints do runtime) → Secao 4
5. **Device profiles** (JSON templates, campos) → Secao 5
6. **Credenciais e registro** (fluxo OTAA, REST endpoints) → Secao 6
7. **MQTT** (topics, JSON schema, connection params) → Secao 7
8. **REST API** (endpoints, auth) → Secao 8
9. **gRPC API** (endpoints, exemplos) → Secao 9
10. **Firmware guidelines** (PlatformIO, resilience rules) → Secao 10
11. **Invariantes** (`docs/architecture/INVARIANTS.md`) → Secao 11

## Regra

- O guide deve permanecer **self-contained** — zero referencias a outros arquivos do LoRaCore
- Toda informacao relevante para o consumidor deve estar **inline** no guide
- Se uma mudanca afeta o consumidor mas nao esta refletida no guide, o commit esta incompleto
