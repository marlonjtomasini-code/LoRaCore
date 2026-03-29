# Glossario LoRaWAN — Referencia Rapida

Definicoes dos termos tecnicos usados na documentacao do LoRaCore. Para detalhes de implementacao, consulte o [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md).

---

## Termos de Protocolo

| Termo | Significado | Descricao |
|-------|-------------|-----------|
| **LoRa** | Long Range | Modulacao de radio de longo alcance (camada fisica). Nao confundir com LoRaWAN. |
| **LoRaWAN** | Long Range Wide Area Network | Protocolo de rede sobre LoRa. Define ativacao, roteamento, seguranca e classes de operacao. O LoRaCore usa v1.0.3. |
| **OTAA** | Over-The-Air Activation | Metodo de ativacao onde o device negocia chaves de sessao com o servidor via join-request/join-accept. Mais seguro que ABP. Unico metodo usado no LoRaCore. |
| **ABP** | Activation By Personalization | Metodo alternativo onde as chaves sao gravadas manualmente no device. Nao recomendado — sem renovacao de chaves. Nao usado no LoRaCore. |
| **ADR** | Adaptive Data Rate | Mecanismo onde o servidor ajusta automaticamente SF e potencia de transmissao do device, otimizando alcance vs velocidade vs consumo. |
| **MIC** | Message Integrity Code | Hash criptografico de 4 bytes no final de cada frame LoRaWAN. O servidor verifica o MIC para garantir autenticidade e integridade. |
| **fCnt** | Frame Counter | Contador sequencial de frames (uplink e downlink). Previne ataques de replay. Incrementa a cada transmissao. |
| **FPort** | Frame Port | Campo do frame que identifica o tipo de payload. FPort 0 = MAC commands, FPort 1-223 = dados de aplicacao. |
| **MAC Commands** | Media Access Control Commands | Comandos de controle trocados entre device e servidor (ex: ajuste de potencia, data rate, canal). Transparentes para a aplicacao. |
| **Uplink** | — | Transmissao do device para o servidor (sensor → gateway → ChirpStack). |
| **Downlink** | — | Transmissao do servidor para o device (ChirpStack → gateway → atuador). |

## Identificadores de Dispositivo

| Termo | Significado | Formato | Descricao |
|-------|-------------|---------|-----------|
| **DevEUI** | Device Extended Unique Identifier | 8 bytes hex (16 caracteres) | Identificador unico global do device. Analogia: MAC address do dispositivo. |
| **JoinEUI / AppEUI** | Join Extended Unique Identifier | 8 bytes hex | Identifica o servidor de join (application server). No LoRaCore: `0000000000000000`. |
| **AppKey** | Application Key | 16 bytes hex (32 caracteres) | Chave raiz usada no OTAA para derivar as chaves de sessao. Deve ser unica por device e secreta. |
| **NwkKey** | Network Key | 16 bytes hex | No LoRaWAN 1.0.x, identica a AppKey. Usada para derivar chaves de sessao de rede. |
| **DevAddr** | Device Address | 4 bytes hex | Endereco de rede atribuido apos join OTAA. Muda a cada novo join. |
| **Gateway ID** | — | 8 bytes hex (16 caracteres) | Identificador do gateway, derivado do MAC da interface de rede (padrao EUI-64 com insercao de FFFE). |

## Camada Fisica (RF)

| Termo | Significado | Descricao |
|-------|-------------|-----------|
| **SF** | Spreading Factor | Fator de espalhamento (SF7 a SF12). SF maior = maior alcance + menor velocidade + maior consumo. SF menor = menor alcance + maior velocidade + menor consumo. |
| **BW** | Bandwidth | Largura de banda do canal. LoRaCore usa 125 kHz (uplink) e 500 kHz (canal 64 e downlink RX2). |
| **DR** | Data Rate | Indice que mapeia para uma combinacao de SF + BW. DR0 = SF10/125kHz (lento), DR5 = SF7/125kHz (rapido), DR8 = SF12/500kHz (RX2). |
| **RSSI** | Received Signal Strength Indicator | Potencia do sinal recebido em dBm. Valores tipicos: -30 (forte) a -120 (fraco). |
| **SNR** | Signal-to-Noise Ratio | Relacao sinal-ruido em dB. LoRa funciona com SNR negativo (abaixo do piso de ruido). Tipico: -20 a +15 dB. |
| **Canal** | Channel | Frequencia fixa de transmissao. LoRaCore US915 sub-band 1 usa canais 0-7 (902.3-903.7 MHz) + canal 64 (903.0 MHz, 500kHz). |
| **Sub-band** | — | Grupo de 8 canais de 125 kHz. US915 tem 8 sub-bands. LoRaCore usa sub-band 1 (canais 0-7). Gateway e devices devem usar a mesma sub-band. |
| **Channel Mask** | — | Mascara de bits que define quais canais o device pode usar. Sub-band 1: `0x00FF,0x0000,0x0000,0x0000,0x0000,0x0000`. |

## Classes de Operacao

| Classe | Recepcao | Consumo | Uso no LoRaCore |
|--------|----------|---------|-----------------|
| **Class A** | Somente apos TX (janelas RX1 + RX2) | Minimo (ideal para bateria) | CubeCell — sensores de telemetria |
| **Class B** | Janelas agendadas via beacon | Medio | Nao usado no LoRaCore |
| **Class C** | Continua (sempre escutando) | Maximo (requer alimentacao fixa) | RAK3172 — atuadores bidirecionais |

**Janelas de recepcao:**
- **RX1**: Abre 1s apos TX, na frequencia de downlink correspondente ao canal de uplink
- **RX2**: Abre 2s apos TX, frequencia fixa 923.3 MHz, DR8 (SF12/500kHz)
- **RXC** (Class C): Continua apos RX2, mesmos parametros de RX2

## Infraestrutura MQTT

| Termo | Descricao |
|-------|-----------|
| **QoS** (Quality of Service) | Nivel de garantia de entrega MQTT. QoS 0 = "at most once" (pode perder). QoS 1 = "at least once" (garante entrega, pode duplicar). QoS 2 = "exactly once". LoRaCore usa QoS 1 em toda a cadeia. |
| **clean_session** | Quando `false`, o broker preserva subscricoes e enfileira mensagens durante desconexao do cliente. Quando `true`, descarta tudo ao desconectar. LoRaCore usa `false` em todos os clientes. |
| **Topic prefix** | Prefixo dos topicos MQTT do gateway. No LoRaCore: `us915_0`. Deve ser identico no MQTT Forwarder e na regiao do ChirpStack. |
| **Broker** | Servidor MQTT que roteia mensagens entre publicadores e assinantes. No LoRaCore: Mosquitto na porta 1883. |
| **Retained message** | Mensagem que o broker armazena e envia automaticamente a novos assinantes do topico. |

## Infraestrutura LoRaWAN (Componentes do LoRaCore)

| Componente | O que faz | Tecnologia |
|------------|-----------|------------|
| **Concentrador** | Hardware de radio que recebe/transmite pacotes LoRa | RAK2287 (SX1302 + SX1250) via USB |
| **Packet Forwarder** | Software que le pacotes do concentrador e envia via UDP | sx1302_hal (C), porta 1700 |
| **MQTT Forwarder** | Converte protocolo UDP Semtech para MQTT | ChirpStack MQTT Forwarder (Rust, 3.7MB) |
| **Broker MQTT** | Roteia mensagens entre componentes | Mosquitto 2.0.18, porta 1883 |
| **Network Server** | Gerencia devices, processa joins, executa ADR, decodifica payloads | ChirpStack v4.17.0, portas 8080/8090 |
| **Banco de Dados** | Persistencia de devices, sessoes e historico | PostgreSQL 16.13, porta 5432 |
| **Cache** | Sessoes ativas, deduplicacao, estado ADR | Redis 7.0.15, porta 6379 |

## Abreviacoes do Projeto

| Abreviacao | Significado |
|------------|-------------|
| **RPi5** | Raspberry Pi 5 |
| **US915** | Plano de frequencias Americas 915 MHz (definido pela LoRa Alliance) |
| **Sub-band 1** | Canais 0-7 (902.3-903.7 MHz) + canal 64 (903.0 MHz, 500kHz) |
| **PUSH_DATA** | Mensagem UDP do packet forwarder contendo pacotes LoRa recebidos |
| **PULL_DATA** | Mensagem UDP de keepalive do packet forwarder (a cada 10s) |
| **PULL_ACK** | Resposta do servidor ao PULL_DATA — indica que a comunicacao UDP esta ativa |
| **EUI-64** | Formato de identificador de 64 bits. Gateway ID e derivado do MAC com insercao de FFFE |

---

**Referencia externa**: [LoRaWAN Regional Parameters US915](https://lora-alliance.org/resource_hub/rp002-1-0-4-regional-parameters/)
