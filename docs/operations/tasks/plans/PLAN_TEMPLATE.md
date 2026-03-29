# Plano de Execucao: TASK-YYYY-NNNN — titulo

> Gerado por: Claude (Coordenador) | Data: YYYY-MM-DD
> Status: **RASCUNHO** | **PRONTO PARA IMPLEMENTACAO** | **EM EXECUCAO**

## Investigacao Realizada

<!-- O que Claude leu, investigou e descobriu durante a analise.
     Inclui arquivos do repo, datasheets, documentacao externa, testes exploratarios.
     Serve como rastreabilidade de como as decisoes foram fundamentadas. -->

### Arquivos e fontes consultados
- caminho/arquivo.cpp (linhas X-Y) — o que foi observado
- URL — o que foi verificado

### Fatos descobertos
- fato 1 (fonte: ...)
- fato 2 (fonte: ...)

## BOM (Bill of Materials)

<!-- Preencher quando a tarefa envolve hardware. Remover secao se for apenas software. -->

| Componente | Quantidade | Especificacao | Fornecedor | Status |
|-----------|-----------|---------------|-----------|--------|
| exemplo | 1 | modelo X, tensao Y | AliExpress | pendente |

## Decisoes de Arquitetura

### Decisao 1 — titulo
**Abordagem:** ...
**Justificativa:** ...
**Alternativa descartada:** ... (motivo: ...)

## Ambiente de Teste

<!-- Infraestrutura necessaria para verificacao das fases TDD. -->

| Recurso | Detalhe |
|---------|---------|
| Raspberry Pi 5 | <LORACORE_HOST> |
| ChirpStack Web UI | http://<LORACORE_HOST>:8080 |
| ChirpStack REST API | http://<LORACORE_HOST>:8090 |
| MQTT Broker | <LORACORE_HOST>:1883 |
| Porta serial | /dev/ttyUSB0 (ou /dev/ttyACM0) |
| Device EUI | (preencher) |
| Ferramentas | PlatformIO, mosquitto_sub, ssh |

## Plano de Execucao (TDD em Fases)

<!-- Cada fase aborda UMA preocupacao. Nao avancar sem passar o gate de saida.
     Para tarefas de hardware, iniciar com Fase 0 (inspecao fisica).
     Para tarefas somente software, iniciar na Fase 1. -->

### Fase 0 — Inspecao de Hardware (quando aplicavel)

**Gate de entrada:** hardware fisicamente disponivel
**Implementacao:**
1. Inspecao visual: identificar pinout, tensao, conexoes
2. Medir com multimetro: VCC, GND, sinais
3. Soldar headers / conectar ao MCU
**Verificacao:**
- [ ] Pinout identificado e documentado
- [ ] Tensao de alimentacao medida e compativel
- [ ] Conexao fisica ao MCU verificada
**Gate de saida:** hardware conectado e pronto para firmware

### Fase 1 — titulo

**Gate de entrada:** prerequisitos (fase anterior OK, hardware disponivel)
**Implementacao:**
1. passo 1
2. passo 2
**Verificacao:**
- [ ] `pio run` compila sem erros/warnings
- [ ] `pio run -t upload` flash bem-sucedido
- [ ] Serial output confirma: (output esperado)
- [ ] ChirpStack recebe dados (se aplicavel)
**Gate de saida:** todos os itens de verificacao OK

### Fase N — Teste de Estabilidade (fase final)

**Gate de entrada:** todas as fases anteriores OK
**Implementacao:**
1. Executar sistema por periodo prolongado (minimo 1h para firmware, mais para infra)
2. Monitorar via serial + logs do RPi
**Verificacao:**
- [ ] Nenhum crash ou watchdog reset durante o periodo
- [ ] Nenhum rejoin inesperado (se LoRaWAN)
- [ ] Dados recebidos consistentes (sem corrupcao ou lacunas)
- [ ] Consumo de energia dentro do esperado (se bateria)
- [ ] Logs do RPi sem erros criticos
**Gate de saida:** sistema estavel pelo periodo definido

## Riscos

| Risco | Probabilidade | Impacto | Mitigacao |
|-------|--------------|---------|-----------|
| ... | Alta/Media/Baixa | ... | ... |

## Inventario de Impacto

| Arquivo | Acao | O que muda |
|---------|------|-----------|
| ... | ADD/MODIFY/DELETE | descricao da mudanca |

## Criterios de Aceite Finais

<!-- Checklist completo que deve estar 100% antes de considerar a tarefa concluida. -->

- [ ] Todos os gates de todas as fases passaram
- [ ] Compilacao sem erros e sem warnings
- [ ] Documentacao atualizada (se comportamento mudou)
- [ ] Teste de estabilidade completado com sucesso
- [ ] Arquivos fora do write_scope nao foram alterados
