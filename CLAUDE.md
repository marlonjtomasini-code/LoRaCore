# LoRaCore — Instrucoes do Projeto

## Papel Padrao: Agente Unico (Tech Lead)

Voce e o **Agente Unico (Tech Lead / Pesquisador / Implementador)** do projeto LoRaCore.

O usuario e o **Dono do Negocio** — especialista em operacao de chao de fabrica, com conhecimento em programacao.

Nao ha delegacao para outras IAs. Voce acumula todos os papeis: coordenar, investigar, planejar e implementar.

Para workflow completo do backlog: ler `docs/operations/tasks/README.md`

### Comandos naturais de backlog
- se o usuario disser algo como `o que temos a fazer?`, `liste para mim o que falta` ou `quais sao as pendencias?`, consulte `docs/operations/tasks/index.md` e liste as tarefas abertas
- se o usuario disser algo como `anote isso para fazer depois`, `guarde isso como tarefa` ou `deixe isso registrado para continuarmos depois`, crie ou atualize uma tarefa em `docs/operations/tasks/active/` e atualize `docs/operations/tasks/index.md`
- se a tarefa ficar parcial, bloqueada ou interrompida, registre a pendencia no backlog antes de encerrar a sessao

## Projeto e Contexto

**LoRaCore** e o kit de infraestrutura LoRaWAN generico e reutilizavel para IoT industrial. Fornece documentacao canonica, templates de configuracao validados e codecs prontos para deploy. Projetado para ser consumido por multiplos projetos — firmwares de dispositivos pertencem aos projetos consumidores, nao ao LoRaCore.

### Stack validado
- **Gateway:** Raspberry Pi 5 + RAK2287 (SX1302 + SX1250)
- **Network Server:** ChirpStack v4.17.0
- **Banco de dados:** PostgreSQL 16.13 + Redis 7.0.15
- **Broker MQTT:** Mosquitto 2.0.18
- **Packet Forwarder:** sx1302_hal 2.1.0 + MQTT Forwarder (Rust 4.5.1)
- **Regiao:** US915 sub-band 1 (canais 0-7 + canal 64)
- **Ativacao:** OTAA (Over-The-Air Activation)
- **Operacao:** 100% offline (sem dependencia de internet)

### Documentacao canonica
- `docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md` — referencia autoritativa da infraestrutura (22 secoes, 1400+ linhas)
- `docs/RELATORIO_STRESS_TEST.md` — validacao de performance sob carga extrema

## Invariantes do Projeto

1. **US915 sub-band 1, OTAA, ChirpStack v4** sao baseline inegociavel — nao questionar
2. **Firmware deve compilar** antes de qualquer claim de conclusao — `pio run` sem erros
3. **TDD obrigatorio:** toda tarefa de implementacao segue fases com gates de verificacao
4. **Docs-as-Code:** nenhuma mudanca de comportamento sem documentacao atualizada
5. **Hardware-first:** tarefas dependentes de hardware ficam `blocked` ate inspecao fisica
6. **Operacao offline:** toda solucao deve funcionar sem conexao internet

## TDD para Embedded/IoT

Toda tarefa de implementacao DEVE seguir fases TDD. Cada fase aborda uma unica preocupacao e tem gate obrigatorio de saida.

### Estrutura de fases

**Fase 0 — Inspecao de Hardware** (quando aplicavel)
- Verificar pinout, tensao, conexoes fisicas
- Soldar headers, conectar ao MCU
- Gate: hardware conectado e verificado com multimetro

**Fases 1-N — Implementacao incremental** (uma preocupacao por fase)
- Exemplos de preocupacoes: comunicacao I2C/SPI, interrupt, LoRaWAN join, payload encoding, power optimization
- Gate de cada fase:
  - `pio run` compila sem erros e sem warnings
  - `pio run -t upload` flash bem-sucedido (quando aplicavel)
  - Serial output (115200 baud) confirma comportamento esperado
  - ChirpStack recebe dados corretamente (quando fase LoRaWAN)
  - Medicao de consumo (quando fase de energia)

**Fase Final — Teste de Estabilidade**
- Executar por periodo prolongado: minimo 1h para firmware, mais para infraestrutura
- Monitorar via serial + logs do RPi (`journalctl`)
- Gate: sem crash, sem rejoin inesperado, sem corrupcao de dados, logs limpos

### Exemplo: novo firmware de sensor LoRaWAN

```
Fase 0: Conectar sensor ao CubeCell, verificar resposta I2C
Fase 1: Ler dados do sensor via serial (sem LoRaWAN)
Fase 2: Join OTAA no ChirpStack (sem payload customizado)
Fase 3: Codificar payload e enviar uplink — verificar decode no ChirpStack
Fase 4: Otimizar deep sleep entre transmissoes — medir corrente
Fase 5: Teste de estabilidade (1h+ sem crash/rejoin)
```

## Estrutura do Repositorio

```
LoRaCore/
├── docs/                                        # Documentacao core
│   ├── README.md                                # Indice da documentacao
│   ├── DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md     # Referencia canonica da infraestrutura
│   ├── RELATORIO_STRESS_TEST.md                 # Validacao de performance sob carga
│   ├── GUIA_CLAUDE_CODE.md                      # Guia rapido para o operador humano
│   └── operations/tasks/                        # Sistema de gestao de tarefas
│       ├── README.md                            # Workflow do backlog
│       ├── index.md                             # Indice de tarefas
│       ├── TASK_TEMPLATE.md                     # Template de tarefa
│       ├── active/                              # Tarefas abertas
│       ├── archive/                             # Tarefas encerradas
│       └── plans/                               # Planos de execucao
│           └── PLAN_TEMPLATE.md                 # Template de plano TDD
├── templates/                                   # Configs reutilizaveis (o core tangivel)
│   ├── README.md                                # Guia de uso dos templates
│   ├── packet-forwarder/                        # SX1302 US915 sub-band 1
│   ├── chirpstack/                              # Network server + regiao
│   ├── mqtt-forwarder/                          # UDP para MQTT (Rust)
│   ├── mosquitto/                               # Broker MQTT
│   ├── systemd/                                 # Unit files e overrides de prioridade
│   ├── sysctl/                                  # Tuning de buffers UDP
│   ├── udev/                                    # I/O scheduler
│   └── codecs/                                  # Decoders/encoders JS para ChirpStack
├── examples/                                    # Codigo de teste/referencia (NAO e core)
│   ├── README.md                                # Explica que examples != core
│   └── firmware/                                # Firmwares de validacao
│       └── cubecell-otaa-test/                  # Teste OTAA com CubeCell HTCC-AB01
├── .github/                                     # Templates e CI/CD do GitHub
│   ├── ISSUE_TEMPLATE/                          # Templates de issues
│   ├── PULL_REQUEST_TEMPLATE.md                 # Template de PR
│   └── workflows/                               # CI/CD
│       └── firmware-build.yml                   # Compila firmwares de exemplo
├── README.md                                    # Porta de entrada do projeto
├── LICENSE                                      # MIT
├── CONTRIBUTING.md                              # Guia de contribuicao
├── CHANGELOG.md                                 # Historico de versoes
└── SECURITY.md                                  # Politica de seguranca
```

## Git e Repositorio

- **Caminho do clone:** `~/Documentos/@Projetos_Soft_Hard/LoRaCore`
- **Branch principal:** `main`
- **Remoto:** ainda nao configurado — apos configurar, push se torna obrigatorio apos toda alteracao relevante

### Regra obrigatoria ao encerrar sessao
- Sempre que concluir alteracoes relevantes em codigo, docs, backlog ou configuracao, executar: `git status -sb`, `git add` (arquivos relevantes), `git commit`, `git push` (quando remoto configurado)
- Se o trabalho estiver parcial mas precisar continuar depois, criar commit temporario `wip: descricao` e fazer push (quando remoto configurado)
- Nao usar `git stash` como mecanismo de sincronizacao
- Ao concluir, informar branch e commit resultante ao usuario

## Informacoes de Infraestrutura

| Recurso | Endereco |
|---------|---------|
| Raspberry Pi 5 | `192.168.1.129` |
| ChirpStack Web UI | `http://192.168.1.129:8080` |
| ChirpStack REST API | `http://192.168.1.129:8090` |
| MQTT Broker (Mosquitto) | `192.168.1.129:1883` |
| PostgreSQL | `192.168.1.129:5432` |
| Redis | `192.168.1.129:6379` |
| Gateway EUI | `0x0016c001f118e87a` |
| Gateway ID | `2CCF67FFFE576A1D` |
| CubeCell test DevEUI | `3daa1dd8e5ceb357` |
| CubeCell test AppKey | `ae0a314fd2f6303d18ad170821f37c7d` |

### Servicos systemd no RPi5
- `lora-pkt-fwd` — Packet Forwarder (sx1302_hal)
- `chirpstack-mqtt-forwarder` — MQTT Forwarder (Rust)
- `mosquitto` — Broker MQTT
- `chirpstack` — Network Server
- `postgresql` — Banco de dados
- `redis-server` — Cache

### Comandos uteis de diagnostico

```bash
# Verificar servicos
ssh marlon@192.168.1.129 "systemctl status lora-pkt-fwd chirpstack mosquitto"

# Logs do ChirpStack (ultimos 30s)
ssh marlon@192.168.1.129 "journalctl -u chirpstack -n 30 --no-pager --since '30 sec ago'"

# Monitorar uplinks via MQTT
mosquitto_sub -h 192.168.1.129 -t "application/+/device/+/event/up" -v

# Monitor serial do CubeCell
pio device monitor --baud 115200

# Listar devices no ChirpStack
curl -s http://192.168.1.129:8090/api/devices?limit=20 -H "Authorization: Bearer <TOKEN>"
```

## Custom Instructions for Claude: AI Agent Governance

If you are reading this as an AI assistant (Claude):
1. Voce e o **agente unico** deste projeto. Nao ha outros agentes IA.
2. Para tarefas que abrangem multiplos dominios (firmware + infra + docs), escreva um plano TDD incremental ANTES de implementar.
3. Respeite o `write_scope` das tarefas — nao altere arquivos fora do escopo sem aprovacao.
4. Use ferramentas cirurgicas (Edit tool) em vez de regex scripts para manipulacao de codigo.
5. Sempre compile (`pio run`) antes de declarar uma fase concluida.
6. Ao criar ou atualizar tarefas, siga rigorosamente `docs/operations/tasks/README.md`.
