# Relatorio de Stress Test - Raspberry Pi + Comunicacao LoRaWAN

**Data**: 2026-03-28
**Duracao**: 2 rodadas de 5 minutos cada
**Objetivo**: Avaliar o comportamento do sistema LoRaWAN sob carga extrema simultanea de CPU, memoria, I/O e disco

---

## 1. Configuracao do Teste

### 1.1 Carga Aplicada (stress-ng)

| Stressor | Workers | Parametro | Efeito |
|---|---|---|---|
| CPU | 4 | (todos os cores) | Satura 100% de todos os 4 cores ARM Cortex-A76 |
| VM (memoria) | 2 | 512 MB cada | Aloca/desaloca 1 GB de memoria continuamente |
| IO | 2 | (sync I/O) | Forca operacoes sync() constantes |
| HDD | 2 | (escrita em disco) | Escrita continua no microSD |

**Total**: 10 workers competindo por recursos do sistema durante 5 minutos.

### 1.2 Comunicacao LoRaWAN Simultanea

- Dispositivo: Heltec CubeCell HTCC-AB01
- Intervalo de TX: 5 segundos (agressivo)
- Modulacao: LoRa SF7/125kHz, 20 dBm
- Canais: US915 Sub-band 1 (902.3 - 903.7 MHz)

---

## 2. Metricas do Sistema Sob Stress

### 2.1 Resumo

| Metrica | Baseline (pre-stress) | Sob Stress (media) | Sob Stress (pico) |
|---|---|---|---|
| **CPU** | 4.7% | 100.0% | 100.0% |
| **Memoria** | 471 MB (6%) | 1064 MB (13.4%) | 1247 MB (15.7%) |
| **Swap** | 0 MB | 176 MB | 523 MB |
| **Temperatura** | 54.0 C | 69.4 C | 71.0 C |
| **Load Average (1m)** | 0.02 | 10.1 | 12.5 |
| **Disco** | 5% | 6-7% | 7% |

### 2.2 Comportamento Temporal

- **0-30s**: CPU sobe de 4.7% para 100%. Temperatura sobe de 54C para 64C.
- **30s-2min**: Load average sobe progressivamente ate ~10. Swap começa a ser usado (~300-500 MB).
- **2-5min**: Sistema estabiliza em saturacao total. CPU 100%, Load ~12, Temp ~70C.
- **Pos-stress**: Load cai lentamente (10.5 -> 0 em ~5 min). Temperatura normaliza em ~2 min.

### 2.3 Estabilidade dos Servicos

| Servico | Amostras OK / Total | Disponibilidade |
|---|---|---|
| postgresql | 55/55 | **100%** |
| redis-server | 55/55 | **100%** |
| mosquitto | 55/55 | **100%** |
| chirpstack | 55/55 | **100%** |
| chirpstack-gateway-bridge | 55/55 | **100%** |
| lora-pkt-fwd | 55/55 | **100%** |

**Nenhum servico caiu durante o stress test.** Todos os 7 servicos permaneceram ativos durante toda a duracao do teste.

---

## 3. Impacto na Comunicacao LoRaWAN

### 3.1 Resultados da Cadeia de Comunicacao

| Camada | Componente | Pacotes Processados | Status |
|---|---|---|---|
| RF -> USB | Concentrador SX1302 | **~50 pacotes recebidos** | OK (hardware, nao depende de CPU) |
| USB -> UDP | Packet Forwarder | **~50 PUSH_DATA enviados** | OK (C leve, roda mesmo com CPU 100%) |
| UDP -> MQTT | Gateway Bridge | **0 uplinks publicados** | **FALHA** |
| MQTT -> NS | ChirpStack | **0 mensagens recebidas** | **FALHA** (consequencia) |
| NS -> App | MQTT Application | **0 uplinks entregues** | **FALHA** (consequencia) |

### 3.2 Ponto de Falha Identificado

```
Concentrador (OK) -> Packet Fwd (OK) -> [X] Gateway Bridge (FALHA) -> ChirpStack -> App
                                              |
                                              +-- PUSH_DATA acknowledged: 0.00%
                                              +-- 0 eventos publicados no MQTT
```

**O Gateway Bridge e o gargalo critico sob stress extremo.**

O Packet Forwarder (programa em C) continua recebendo pacotes RF e enviando PUSH_DATA via UDP. Porem, o Gateway Bridge (programa em Go) nao consegue processar os pacotes UDP e publicar no MQTT quando a CPU esta 100% saturada e o I/O do disco esta sob stress.

**Evidencia**: `PUSH_DATA acknowledged: 0.00%` - o Packet Forwarder enviou pacotes, mas nao recebeu nenhuma confirmacao do Gateway Bridge.

### 3.3 Analise da Cadeia

| Componente | Linguagem | Peso de CPU | Comportamento sob stress |
|---|---|---|---|
| lora_pkt_fwd | C | Muito leve | Funciona normalmente |
| chirpstack-gateway-bridge | Go | Medio | **Para de processar UDP** |
| chirpstack | Go/Rust | Medio-Alto | Nao recebe dados (depende do bridge) |
| mosquitto | C | Muito leve | Funciona normalmente (servico ativo) |
| postgresql | C | Medio | Funciona normalmente (servico ativo) |
| redis | C | Leve | Funciona normalmente (servico ativo) |

---

## 4. Conclusoes

### 4.1 Pontos Fortes

1. **Todos os servicos sobreviveram** ao stress de 5 minutos com CPU 100%, incluindo I/O e memoria.
2. **Nenhum crash ou restart** foi necessario em nenhum servico.
3. **O concentrador LoRa (SX1302)** opera independente da carga do sistema - e hardware dedicado.
4. **O Packet Forwarder** e extremamente leve e continua operando mesmo sob carga maxima.
5. **O swap de 2 GB** cumpriu sua funcao: pico de 523 MB de swap sem OOM killer.
6. **A temperatura** ficou em 71C no pico - abaixo do limite de throttling (85C).
7. **Apos o stress**, todos os servicos retomaram operacao normal imediatamente.

### 4.2 Ponto Critico

1. **O Gateway Bridge perde 100% dos pacotes** quando a CPU esta saturada a 100% por periodo prolongado (>30s).
2. **Implicacao**: sob carga extrema do sistema, a rede LoRaWAN para de processar uplinks. Os pacotes RF sao recebidos pelo hardware mas descartados na cadeia de software.
3. **Risco real**: em producao com 50 devices, a carga normal e baixa (~0.83 msg/s). Este cenario de CPU 100% so ocorreria se um processo externo consumisse todos os recursos (ex: build de software, minerador, processo descontrolado).

### 4.3 Mitigacoes Recomendadas

| Acao | Prioridade | Efeito |
|---|---|---|
| **cgroups/systemd**: reservar CPU para servicos LoRaWAN | Alta | Garante que o Gateway Bridge tenha CPU minima mesmo sob carga |
| **Monitorar load average**: alertar se > 4 (num cores) | Media | Detecta sobrecarga antes de perder pacotes |
| **Nao executar processos pesados** no mesmo servidor | Media | Pratica operacional |
| **Segundo gateway** (futuro) | Baixa | Redundancia total |

### 4.4 Contexto para Producao

Em operacao normal com 50 devices:
- CPU estimada: < 10%
- Memoria: < 1 GB
- I/O: minimal

O cenario de stress testado (CPU 100% + 1GB VM + I/O saturado) e **extremamente improvavel** em producao. O Gateway Bridge so falha quando a CPU fica saturada por periodo prolongado. Em picos curtos de CPU (<5s), o QoS 1 e o clean_session=false devem recuperar as mensagens pendentes.

---

## 5. Dados Brutos

### 5.1 Arquivos de Metricas

Localizacao na Raspberry Pi:
```
/home/<USER>/stress_results/
  system_metrics.csv        # Metricas do sistema a cada 5s (55 amostras)
  pktfwd_log.txt           # Logs do packet forwarder durante stress
  gw_bridge_log.txt        # Logs do gateway bridge durante stress
  chirpstack_log.txt       # Logs do chirpstack durante stress
  mqtt_uplinks_raw.txt     # Uplinks capturados via MQTT (vazio sob stress)
```

### 5.2 Configuracao do stress-ng

```bash
stress-ng --cpu 4 --vm 2 --vm-bytes 512M --io 2 --hdd 2 --timeout 300
```

Resultado: `passed: 10: cpu (4) vm (2) io (2) hdd (2)` - todos os stressors completaram sem erro.
