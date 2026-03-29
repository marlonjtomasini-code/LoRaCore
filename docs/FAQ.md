# FAQ — Perguntas Frequentes

Respostas para perguntas operacionais e de planejamento sobre o LoRaCore. Para diagnostico de falhas, consulte a [Secao 22 do DOC_PROTOCOLO](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#22-troubleshooting).

---

## Capacidade e Escala

### Quantos devices um gateway suporta?

Depende do intervalo de transmissao e do spreading factor. Em operacao normal com 50 devices transmitindo a cada 60s (~0.83 msg/s), o RPi5 opera com CPU < 10% e entrega 100% dos pacotes. O stress test ([RELATORIO_STRESS_TEST.md](RELATORIO_STRESS_TEST.md)) mostra que a cadeia so falha quando a CPU atinge 100% por mais de 30s — cenario extremamente improvavel em producao.

Limites praticos para US915 sub-band 1 com 8 canais:
- **~200 devices** com TX a cada 60s e SF7 (alta taxa, curto alcance)
- **~50 devices** com TX a cada 60s e SF12 (baixa taxa, longo alcance)
- O ADR ajusta o SF automaticamente para otimizar a capacidade

### Como adicionar um segundo gateway?

1. Instalar a stack LoRaCore em um novo RPi5 (Secao 19 do DOC_PROTOCOLO) **ou** apontar o MQTT Forwarder do novo gateway para o Mosquitto/ChirpStack existente
2. Registrar o novo gateway no ChirpStack (Web UI ou API REST)
3. O ChirpStack automaticamente faz deduplicacao — se ambos os gateways recebem o mesmo uplink, processa apenas uma vez
4. O ADR considera o melhor RSSI/SNR entre os gateways disponíveis

### E possivel operar com mais de uma sub-band?

Sim, mas requer hardware adicional. Cada concentrador SX1302 cobre 8 canais de 125 kHz (uma sub-band). Para cobrir multiplas sub-bands simultaneamente, e necessario um segundo concentrador. Os devices precisam ter o channel mask ajustado no firmware para incluir as sub-bands adicionais.

---

## Manutencao

### Como atualizar o ChirpStack?

```bash
# 1. Backup antes de atualizar
sudo bash /home/marlon/backup_chirpstack.sh

# 2. Atualizar pacotes
sudo apt update
sudo apt upgrade chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api

# 3. Verificar release notes para breaking changes
# https://www.chirpstack.io/docs/changelog/

# 4. Verificar que os servicos reiniciaram corretamente
systemctl status chirpstack chirpstack-mqtt-forwarder chirpstack-rest-api
```

Sempre leia as release notes antes de atualizar — versoes major podem ter breaking changes em configuracao ou banco de dados.

### O que acontece se o cartao SD morrer?

O backup diario (Secao 17.4 do DOC_PROTOCOLO) garante perda maxima de 24h de configuracao:

1. Instalar Ubuntu em um novo cartao SD
2. Reinstalar a stack LoRaCore (Secao 19 do DOC_PROTOCOLO)
3. Restaurar o backup (Secao 17.6): PostgreSQL dump + Redis snapshot + configs
4. Os devices **nao precisam ser reprovisionados** — as session keys sao restauradas com o banco

**Recomendacao**: copiar os backups para fora do RPi periodicamente (`rsync` ou `scp` para outra maquina). Se o SD morrer, o backup local morre junto.

### Como mudar de US915 para outra regiao (EU868, AU915)?

Tres alteracoes necessarias:

1. **ChirpStack**: criar novo arquivo `region_*.toml` com as frequencias da regiao alvo e atualizar `enabled_regions` em `chirpstack.toml`
2. **Packet Forwarder**: editar `global_conf.json` com as frequencias centrais dos radios, canais e potencia TX da nova regiao
3. **Firmware dos devices**: atualizar channel mask e frequencias no codigo

Referencia: Secoes 10-11 do DOC_PROTOCOLO para a configuracao atual US915.

---

## Operacao

### O gateway precisa de internet para funcionar?

Nao. O LoRaCore opera 100% offline na rede local (Secao 15.3 do DOC_PROTOCOLO). Todos os servicos comunicam via `localhost`. O boot completa mesmo sem WiFi — nenhum servico depende de `network-online.target`.

Internet e necessaria apenas para:
- Acesso SSH remoto (de fora da rede local)
- `apt update` / atualizacoes de pacotes
- Acesso a Web UI de fora da rede local (a menos que haja VPN)

### Como verificar se um device esta offline?

Tres formas:

1. **Automatica**: o script `device_monitor.sh` roda a cada 3 minutos e registra alertas no log
   ```bash
   grep "ALERT OFFLINE" /var/log/lorawan-health.log
   ```

2. **Web UI**: verificar `lastSeenAt` no painel do device em `http://192.168.1.129:8080`

3. **API REST**:
   ```bash
   curl -s http://192.168.1.129:8090/api/devices/<DEV_EUI> \
     -H "Grpc-Metadata-Authorization: Bearer <TOKEN>" | python3 -m json.tool
   ```

### Qual a latencia tipica de um downlink Class C?

Menos de 1 segundo em condicoes normais. O ChirpStack envia o downlink imediatamente via MQTT, o MQTT Forwarder converte para UDP e o concentrador transmite na janela RXC (923.3 MHz, DR8). O device Class C esta sempre escutando, entao recebe instantaneamente.

Para Class A, o downlink so e entregue na proxima janela RX1/RX2 — ou seja, precisa esperar pelo proximo uplink do device.

### O que significa "PUSH_DATA acknowledged: 0.00%" nos logs?

O Packet Forwarder esta enviando pacotes UDP, mas o MQTT Forwarder nao esta respondendo. Causas:

1. **MQTT Forwarder parado**: `systemctl status chirpstack-mqtt-forwarder`
2. **Porta 1700 em uso por outro processo**: `ss -ulnp | grep 1700`
3. **CPU saturada**: o MQTT Forwarder nao consegue processar (ver [RELATORIO_STRESS_TEST.md](RELATORIO_STRESS_TEST.md))
4. **Configuracao**: `bind` no MQTT Forwarder deve ser `0.0.0.0:1700`, e `serv_port_up`/`serv_port_down` no Packet Forwarder deve ser `1700`

---

## Firmware e Devices

### Preciso criar um codec para cada tipo de device?

Sim. O codec JavaScript converte os bytes brutos do payload LoRaWAN em JSON legivel. Cada tipo de device tem um formato de payload diferente, entao precisa de um codec especifico.

Templates disponiveis em `templates/codecs/`:
- `cubecell-class-a-sensor.js` — CubeCell Class A (bateria + uptime)
- `rak3172-class-c-actuator.js` — RAK3172 Class C (bateria + status + GPIO)

Para testar um codec: ChirpStack Web UI > Device Profile > Codec > aba "Test".

### Posso usar ABP em vez de OTAA?

Tecnicamente sim (o ChirpStack suporta), mas o LoRaCore documenta e recomenda apenas OTAA. Razoes:

- OTAA renova as chaves de sessao a cada join — mais seguro
- ABP usa chaves fixas gravadas no device — se comprometidas, nao ha como renovar sem acesso fisico
- OTAA simplifica o provisionamento — so precisa de DevEUI + AppKey

### Como gerar DevEUI e AppKey para um novo device?

```bash
# DevEUI (8 bytes aleatorios)
openssl rand -hex 8

# AppKey (16 bytes aleatorios)
openssl rand -hex 16
```

Registrar no ChirpStack (Web UI ou API — Secao 20 do DOC_PROTOCOLO) e gravar no firmware do device.

---

## Ver Tambem

- [DOC_PROTOCOLO Secao 22](DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md#22-troubleshooting) — Troubleshooting (diagnostico de falhas)
- [RELATORIO_STRESS_TEST.md](RELATORIO_STRESS_TEST.md) — Limites validados do sistema
- [GLOSSARIO.md](GLOSSARIO.md) — Definicoes dos termos tecnicos
