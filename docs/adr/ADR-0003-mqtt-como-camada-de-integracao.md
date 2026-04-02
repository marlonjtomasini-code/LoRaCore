# ADR-0003: MQTT como Camada de Integracao

## Status

Aceito (2026-03-28)

## Contexto

Projetos consumidores do LoRaCore precisam receber dados dos devices LoRaWAN em tempo real. O ChirpStack oferece dois mecanismos para consumo de dados:

1. **MQTT** — pub/sub via Mosquitto (ja presente na stack como camada 3)
2. **gRPC / REST API** — polling ou streaming via porta 8080/8090

A escolha afeta como os projetos consumidores se integram com a infraestrutura.

## Opcoes Consideradas

1. **MQTT como mecanismo primario** de integracao em tempo real, REST API apenas para gerenciamento
2. **gRPC streaming** como mecanismo primario, eliminando a dependencia do Mosquitto para integracao
3. **REST API polling** para todos os casos de uso

## Decisao

Adotar **MQTT como mecanismo primario** de integracao para dados em tempo real. REST API para gerenciamento (CRUD de devices, downlinks, consultas).

## Justificativa

- **MQTT ja e obrigatorio na stack**: o MQTT Forwarder publica pacotes do gateway no Mosquitto, e o ChirpStack consome desse mesmo broker. Adicionar um subscriber externo nao introduz nenhum componente novo
- **Desacoplamento**: pub/sub permite que multiplos consumidores recebam os mesmos dados simultaneamente sem que nenhum precise conhecer o outro. Um backend Python, um dashboard e um sistema de alertas podem coexistir subscrevendo o mesmo topico
- **QoS e persistencia**: com QoS 1 e `clean_session=false`, mensagens sao preservadas durante desconexao do consumidor e entregues ao reconectar — sem perda de dados
- **Simplicidade de implementacao**: um subscriber MQTT em Python (paho-mqtt) requer ~15 linhas de codigo. Streaming gRPC requer geracao de stubs, tratamento de reconexao e dependencias mais pesadas
- **Operacao offline**: MQTT funciona inteiramente na rede local sem nenhuma dependencia externa

**Por que nao gRPC/REST polling:**
- Polling introduz latencia e desperdicio de recursos (requisicoes vazias quando nao ha dados)
- gRPC streaming e mais complexo para implementar corretamente (reconexao, backpressure) e requer dependencias adicionais nos consumidores

## Consequencias

**Positivas:**
- Zero componentes adicionais para integracao (Mosquitto ja esta na stack)
- Suporta multiplos consumidores simultaneos sem configuracao extra
- Dados em JSON nos topicos de aplicacao — facil de parsear em qualquer linguagem
- Reconexao com preservacao de fila (QoS 1 + clean_session=false)

**Negativas:**
- Mosquitto se torna ponto unico de falha para integracao (mitigado: Mosquitto e escrito em C, extremamente leve e estavel)
- Debug de topicos de gateway e em Protobuf (nao JSON) — mas topicos de aplicacao sao JSON
- Sem controle de acesso granular (allow_anonymous=true) — adequado para rede local isolada, mas precisaria de ACLs se exposto externamente

## Referencia

- [DOC_PROTOCOLO Secao 14](../DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#14-topicos-mqtt-e-integracao-de-dados) — topicos MQTT e formato de dados
- [LORACORE_AI_INTEGRATION_GUIDE.md](../LORACORE_AI_INTEGRATION_GUIDE.md) — guia completo de integracao para projetos consumidores
