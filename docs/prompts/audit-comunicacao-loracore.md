# Prompt: Auditoria de Conformidade com Diretrizes de Comunicacao LoRaCore

> Cole este prompt na conversa do projeto consumidor.
> Substitua `<CAMINHO_LORACORE>` pelo path absoluto do repositorio LoRaCore na maquina.

---

Preciso que voce faca uma auditoria completa de conformidade deste projeto com as diretrizes de comunicacao do LoRaCore — a infraestrutura LoRaWAN compartilhada que este projeto consome.

## Contexto

O LoRaCore e um kit de infraestrutura LoRaWAN generico (gateway RPi5 + ChirpStack v4). Este projeto e um **consumidor** que usa essa infraestrutura para comunicar com devices via LoRa. A documentacao canonica do LoRaCore esta em `<CAMINHO_LORACORE>/docs/`.

## Diretrizes a verificar

Analise todo o codigo deste projeto (firmware, codecs, backend, configs) contra cada diretriz abaixo. Para cada item, reporte: **OK**, **VIOLACAO** (com arquivo:linha e descricao), ou **N/A** (projeto nao tem esse componente).

### 1. Protocolo de payload

- [ ] **Big-endian**: todos os campos multi-byte no payload LoRa usam big-endian (network byte order). Procure por shifts como `(byte[1] << 8) | byte[0]` — isso e little-endian e esta errado.
- [ ] **Layout documentado**: cada firmware que monta payload tem comentario descrevendo o layout de bytes (ex: `[bat(2) uptime(2)]`). Cada codec tem header com o mesmo layout.
- [ ] **Consistencia firmware↔codec**: o layout de bytes que o firmware envia e identico ao que o codec JS decodifica. Comparar campo a campo: ordem, tamanho, tipo (signed/unsigned), escala.
- [ ] **Consistencia codec↔backend**: se o backend tambem faz decode (alem do codec JS), o resultado deve ser identico. Mesmos nomes de campos, mesmas unidades, mesma precisao.
- [ ] **appDataSize correto**: o valor de `appDataSize` no firmware corresponde ao numero real de bytes escritos em `appData[]`.

### 2. Codecs ChirpStack

- [ ] **Assinatura correta**: codec usa `function decodeUplink(input)` (ChirpStack v4). Nao usar `Decode(fPort, bytes)` (v3 legado).
- [ ] **Validacao de tamanho**: codec verifica `bytes.length` minimo antes de decodificar. Retorna `{ errors: [...] }` se payload curto.
- [ ] **Retorno padrao**: decode retorna `{ data: { ... } }`, nao formatos customizados.
- [ ] **Sem dependencias externas**: codec e JavaScript puro, sem require/import (executa no sandbox do ChirpStack).
- [ ] **encodeDownlink para atuadores**: devices Class C ou qualquer device que recebe downlinks tem `encodeDownlink()` e `decodeDownlink()` no codec.
- [ ] **Teste de codec existe**: cada codec `.js` tem um arquivo de teste correspondente rodavel com `node tests/test-<nome>.js`.
- [ ] **Baseado no template**: codec segue a estrutura de `<CAMINHO_LORACORE>/templates/codecs/CODEC_TEMPLATE.js` (header com layout, validacao, retorno padronizado).

### 3. Credenciais e seguranca

- [ ] **Sem credenciais hardcoded**: DevEUI, AppKey, AppEUI no firmware sao placeholders (`0x00`) ou lidos de config externa. Grep por arrays de hex com valores nao-zero nos campos de credenciais OTAA.
- [ ] **Sem tokens no codigo**: API tokens do ChirpStack nao estao em arquivos versionados. Verificar arquivos `.py`, `.toml`, `.env`, `.json`.
- [ ] **OTAA apenas**: firmware usa `overTheAirActivation = true`. Nenhum firmware usa ABP (Activation By Personalization).

### 4. Configuracao LoRaWAN

- [ ] **US915 sub-band 1**: firmware configura `LORAMAC_REGION_US915` e channel mask `0x00FF` (canais 0-7). Nao usar all-channels ou outra sub-band.
- [ ] **Classe correta**: sensores a bateria = Class A. Atuadores com alimentacao externa = Class C. Nao usar Class B (nao suportado no LoRaCore).
- [ ] **fPort valido**: firmware usa `appPort` entre 1-223. Nao usar porta 0 (MAC) nem portas reservadas.

### 5. Integracao backend

- [ ] **Topicos MQTT corretos**: backend subscreve `application/{id}/device/+/event/up` (padrao ChirpStack v4). Nao usar topicos inventados ou formato v3.
- [ ] **QoS e clean_session**: conexao MQTT usa QoS 1 e `clean_session=false` para nao perder mensagens durante reconexao.
- [ ] **Portas corretas**: MQTT=1883, REST API=8090, gRPC/WebUI=8080. Verificar configs de conexao.
- [ ] **Campo `object` para dados decodificados**: backend extrai dados do campo `object` (ou `data` dentro do `object`) do JSON MQTT — nao faz decode manual do base64 se o codec ja esta configurado.

### 6. Firmware build

- [ ] **Compila sem erros**: `pio run` passa para todos os environments do `platformio.ini`.
- [ ] **platformio.ini valido**: `default_envs` tem no maximo 1 valor (ou esta ausente). Environments usam `build_src_filter` para separar devices.
- [ ] **Sem warnings relevantes**: compilacao nao gera warnings sobre truncamento de tipos, variaveis nao usadas em logica critica, ou overflow.

### 7. Sincronizacao de protocolo

- [ ] **Alteracao atomica**: mudancas no layout de payload estao no mesmo commit/PR para firmware + codec + backend decoder. Verificar git log se houve alteracao parcial.
- [ ] **Sem versoes divergentes**: nao existe firmware enviando formato X enquanto codec espera formato Y (problema que o LoRaCore corrigiu na TASK-2026-0012).

## Formato de saida

Organize o relatorio assim:

```
## Resultado da Auditoria LoRaCore

### Resumo
- Total de checks: X
- OK: X
- Violacoes: X
- N/A: X

### Violacoes encontradas

#### [VIOLACAO] <titulo curto>
- **Diretriz**: <numero e nome>
- **Arquivo**: <path:linha>
- **Problema**: <descricao objetiva>
- **Correcao sugerida**: <o que fazer>
- **Severidade**: critica | alta | media

### Items OK
(lista compacta dos checks que passaram)
```

## Instrucoes adicionais

- Leia os arquivos, nao suponha. Abra cada firmware, cada codec, cada config de backend.
- Se encontrar um padrao que nao esta nas diretrizes mas parece problematico, mencione como **observacao** separada das violacoes.
- Se o projeto nao tem determinado componente (ex: nao tem backend ainda), marque toda a secao como N/A.
- Priorize violacoes criticas (payload mismatch, credenciais expostas) sobre cosmeticas.
- Ao final, liste as violacoes ordenadas por severidade para facilitar priorizacao.
