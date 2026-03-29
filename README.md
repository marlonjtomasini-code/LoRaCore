# LoRaCore

Kit de infraestrutura LoRaWAN generico e reutilizavel para IoT industrial. Documentacao canonica, templates de configuracao validados e codecs prontos para deploy.

## O que e o LoRaCore

LoRaCore e o **nucleo de infraestrutura LoRaWAN** projetado para ser consumido por multiplos projetos. Ele fornece:

- **Documentacao canonica** — referencia completa de 22 secoes para replicar a infraestrutura do zero
- **Templates de configuracao** — arquivos prontos para copiar e customizar (packet forwarder, ChirpStack, MQTT, systemd, codecs)
- **Baselines de performance** — resultados de stress test validados em hardware real
- **Exemplos** — firmwares de teste e validacao da infraestrutura

LoRaCore **nao e um projeto de firmware** — firmwares de dispositivos pertencem aos projetos consumidores. Os firmwares incluidos sao exclusivamente para teste e validacao da infraestrutura.

## Stack Validado

| Componente | Tecnologia | Versao |
|------------|------------|--------|
| Gateway | Raspberry Pi 5 + RAK2287 (SX1302 + SX1250) | - |
| Network Server | ChirpStack | v4.17.0 |
| Banco de Dados | PostgreSQL | 16.13 |
| Cache | Redis | 7.0.15 |
| Broker MQTT | Mosquitto | 2.0.18 |
| Packet Forwarder | sx1302_hal | 2.1.0 |
| MQTT Forwarder | ChirpStack MQTT Forwarder (Rust) | 4.5.1 |
| Regiao | US915 sub-band 1 (canais 0-7 + canal 64) | - |
| Ativacao | OTAA (Over-The-Air Activation) | - |
| Operacao | 100% offline (sem dependencia de internet) | - |

## Estrutura do Repositorio

```
LoRaCore/
├── docs/                    # Documentacao core
│   ├── DOC_PROTOCOLO_*.md   # Referencia canonica da infraestrutura (22 secoes)
│   ├── RELATORIO_*.md       # Validacao de performance sob carga
│   └── operations/tasks/    # Sistema de gestao de tarefas
├── templates/               # Configuracoes reutilizaveis
│   ├── packet-forwarder/    # SX1302 US915 sub-band 1
│   ├── chirpstack/          # Network server + regiao
│   ├── mqtt-forwarder/      # UDP para MQTT (Rust)
│   ├── mosquitto/           # Broker MQTT
│   ├── systemd/             # Unit files e overrides de prioridade
│   ├── sysctl/              # Tuning de buffers UDP
│   ├── udev/                # I/O scheduler
│   └── codecs/              # Decoders/encoders JavaScript para ChirpStack
├── examples/                # Codigo de teste e referencia (NAO e core)
│   └── firmware/            # Firmwares de validacao
└── .github/                 # Templates e CI/CD
```

## Como Usar em Seu Projeto

1. **Clone o LoRaCore** como referencia:
   ```bash
   git clone <url> LoRaCore
   ```

2. **Copie os templates** que precisa para sua infraestrutura:
   ```bash
   cp LoRaCore/templates/chirpstack/chirpstack.toml /etc/chirpstack/
   cp LoRaCore/templates/packet-forwarder/global_conf.json ~/packet_forwarder/
   ```

3. **Substitua os placeholders** (`<GATEWAY_ID>`, `<SECRET>`, etc.) pelos valores da sua instalacao

4. **Consulte a documentacao canonica** para entender cada parametro:
   - [`docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md`](docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md)

5. **Use os codecs** no Device Profile do ChirpStack:
   - [`templates/codecs/`](templates/codecs/)

## Documentacao

- [Documentacao canonica da infraestrutura](docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) — referencia completa
- [Relatorio de stress test](docs/RELATORIO_STRESS_TEST.md) — performance sob carga extrema
- [Indice de templates](templates/README.md) — configuracoes reutilizaveis
- [Exemplos](examples/README.md) — firmwares de teste e validacao

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para diretrizes de contribuicao.

## Licenca

[MIT](LICENSE)
