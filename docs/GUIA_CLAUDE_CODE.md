# Guia Rapido — Claude Code para o LoRaCore

> Para consulta do operador humano (Marlon).
> Baseado em: code.claude.com/docs/en/common-workflows e best-practices.
> Atualizado: 2026-03-29

---

## 1. Conceitos fundamentais

### Janela de contexto
- Tudo que voce e o Claude conversam, arquivos lidos e resultados de comandos ocupam a **janela de contexto**.
- Quando ela enche, o Claude comeca a "esquecer" instrucoes e cometer mais erros.
- **Regra de ouro:** gerencie o contexto como recurso escasso. Limpe entre tarefas.

### Modelos disponiveis

| Modelo | Quando usar | Custo relativo |
|---|---|---|
| **Haiku** (`/model haiku`) | Perguntas simples, consultar backlog, leitura de arquivos | Baixo |
| **Sonnet** (`/model sonnet`) | Bugs localizados, refatoracao de 1-3 arquivos, testes, commits | Medio |
| **Opus** (`/model opus`) | Arquitetura, planejamento, debug complexo, analise de firmware | Alto |

**Dica:** use `/model` para trocar durante a sessao. Comece com Sonnet, suba para Opus se a tarefa exigir.

### Nivel de esforco

| Nivel | Quando usar |
|---|---|
| `/effort min` | Perguntas rapidas, consultas ao backlog, leitura de arquivos |
| `/effort default` | Maioria das tarefas de desenvolvimento |
| `/effort high` | Planejamento arquitetural, debug complexo |

---

## 2. Fluxo recomendado de desenvolvimento

### Fase 1: Explorar (entender o problema)

Use **Plan Mode** (Shift+Tab ate aparecer `plan mode on`).
Neste modo o Claude so le arquivos e responde perguntas — nao altera nada.

```
como funciona a configuracao de frequencia do RAK2287?
```
```
trace o fluxo de um pacote LoRaWAN do CubeCell ate o MQTT
```
```
quais servicos systemd estao envolvidos no packet forwarding?
```

**Modelo sugerido:** Sonnet (leitura rapida) ou Opus (analise profunda).

### Fase 2: Planejar (alinhar a abordagem)

Ainda em Plan Mode, peca um plano:

```
quero adicionar firmware para o RAK3172 Class C.
quais arquivos precisam ser criados? crie um plano passo a passo.
```

- Pressione **Ctrl+G** para abrir o plano no seu editor e editar antes de prosseguir.
- So saia do Plan Mode quando estiver satisfeito com o plano.

**Modelo sugerido:** Opus.

### Fase 3: Implementar

Volte para Normal Mode (Shift+Tab). Execute o plano:

```
implemente o plano que voce criou. compile e teste apos cada etapa.
```

**Modelo sugerido:** Sonnet (tarefas S3) ou Opus (tarefas S1/S2).

### Fase 4: Verificar e commitar

```
compile o firmware e mostre o resultado
```
```
/commit
```

**Modelo sugerido:** Sonnet.

---

## 3. Comandos e atalhos essenciais

### Navegacao e controle

| Atalho | O que faz |
|---|---|
| `Esc` | Para o Claude no meio de uma acao (contexto preservado) |
| `Esc + Esc` | Abre menu de rewind — restaura conversa e/ou codigo para checkpoint anterior |
| `Shift+Tab` | Alterna entre Normal → Auto-Accept → Plan Mode |
| `Ctrl+O` | Liga/desliga modo verboso (mostra o "pensamento" do Claude) |
| `Alt+T` | Liga/desliga extended thinking |
| `Ctrl+G` | Abre o plano no editor de texto para editar diretamente |

### Slash commands uteis

| Comando | Uso | Modelo ideal |
|---|---|---|
| `/clear` | Limpa contexto entre tarefas nao relacionadas | — |
| `/compact` | Compacta a conversa mantendo o essencial | — |
| `/compact Foco nas mudancas de firmware` | Compacta com instrucao especifica do que preservar | — |
| `/model sonnet` ou `/model opus` | Troca de modelo no meio da sessao | — |
| `/effort min` | Reduz esforco para perguntas simples | — |
| `/commit` | Gera commit com mensagem descritiva | Sonnet |
| `/resume` | Retoma uma sessao anterior (picker interativo) | — |
| `/rename lorawan-debug` | Nomeia a sessao para encontrar depois | — |
| `/rewind` | Volta a um checkpoint anterior | — |
| `/btw como funciona X?` | Pergunta lateral que nao entra no contexto | Haiku |

### Linha de comando (fora da sessao)

```bash
# Retomar a ultima conversa
claude --continue

# Retomar sessao especifica
claude --resume nome-da-sessao

# Iniciar em Plan Mode
claude --permission-mode plan

# Rodar query sem sessao interativa (headless)
claude -p "explique o que este projeto faz"

# Rodar em worktree isolada
claude --worktree feature-rak3172

# Pipeline: passar dados e obter resultado
cat build-error.txt | claude -p "explique a causa raiz deste erro"
```

---

## 4. Situacoes comuns do seu projeto

### "O que temos a fazer?"

```
o que temos a fazer?
```
O Claude ja sabe consultar `docs/operations/tasks/index.md` (configurado no CLAUDE.md).
**Modelo:** Haiku ou Sonnet com `/effort min`.

### "Quero entender como funciona X"

```
como o ChirpStack processa um uplink?
```
```
trace o fluxo de um pacote do CubeCell ate o MQTT broker
```
**Modelo:** Sonnet. Use Plan Mode se quiser evitar alteracoes acidentais.

### "O firmware nao faz join"

```
o CubeCell nao faz join OTAA. verifique o firmware, os logs do ChirpStack
e a configuracao de frequencia. use SSH para acessar o RPi.
```
**Dica:** cole o output serial completo. Quanto mais contexto, melhor.
**Modelo:** Opus (debug cross-layer: firmware + infra + rede).

### "Quero portar firmware para novo hardware"

1. Plan Mode: `crie um plano para firmware do RAK3172 Class C baseado no CubeCell`
2. Revise o plano, ajuste
3. Normal Mode: `implemente o plano. compile apos cada etapa`
4. `/commit`

**Modelo:** Opus para planejar, Sonnet para implementar.

### "Quero provisionar um device no ChirpStack"

```
provisione um novo CubeCell no ChirpStack via REST API.
DevEUI: XXXX, AppKey: YYYY. use o device profile ClassA-Sensor.
```
**Modelo:** Sonnet.

### "Quero monitorar uplinks"

```
monitore uplinks do device XXXX via MQTT por 2 minutos
```
```
verifique os logs do ChirpStack nos ultimos 5 minutos via SSH
```
**Modelo:** Haiku ou Sonnet com `/effort min`.

### "Analisar consumo de energia"

```
analise o firmware do CubeCell e identifique onde posso economizar bateria.
verifique deep sleep, duty cycle, e perifericos ativos.
```
**Modelo:** Opus (analise profunda de C/C++ + datasheet).

### "Comparar abordagens tecnicas"

Use Plan Mode + Opus:
```
compare Class A polling vs Class C para um atuador bidirecional.
liste pros/contras, impacto em firmware e consumo, e latencia.
```

### "Anote isso como tarefa para depois"

```
anote isso para fazer depois: criar firmware template para RAK3172 Class C
```
O Claude cria a tarefa automaticamente no backlog (configurado no CLAUDE.md).
**Modelo:** Haiku ou Sonnet com `/effort min`.

### "Quero fazer stress test"

```
execute um stress test no RPi5 usando stress-ng enquanto monitora
os servicos LoRaWAN. siga o padrao do docs/RELATORIO_STRESS_TEST.md
```
**Modelo:** Sonnet.

---

## 5. Boas praticas essenciais

### Sempre de ao Claude uma forma de verificar o trabalho

Esta e a dica mais importante. O Claude erra menos quando pode se auto-verificar.

| Ruim | Bom |
|---|---|
| "mude o firmware" | "mude o TX interval para 30s. compile e mostre o output serial" |
| "configure o device" | "provisione DevEUI X no ChirpStack. verifique com curl que aparece na lista" |
| "o join nao funciona" | "o join falha com [erro]. verifique serial + logs ChirpStack e corrija" |

### Seja especifico no prompt

| Ruim | Bom |
|---|---|
| "adicione um sensor" | "crie firmware para CubeCell + BMA400 via I2C. baseie no examples/firmware/cubecell-otaa-test existente" |
| "corrija o gateway" | "o lora_pkt_fwd reinicia a cada 5 min. verifique logs via SSH e identifique a causa" |

### Use @ para referenciar arquivos

```
explique a logica em @examples/firmware/cubecell-otaa-test/firmware-cubecell.ino
```
```
compare @docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md secao 5 com a config atual do RPi
```

### Gerencie o contexto agressivamente

- **`/clear`** entre tarefas nao relacionadas
- **`/compact`** quando a sessao ficar longa
- **`/btw`** para perguntas rapidas que nao precisam ficar no contexto
- **Subagentes** para investigacao pesada (o Claude explora em contexto separado e traz so o resumo)

### Corrija cedo, nao tarde

- Se o Claude esta indo na direcao errada, pressione **Esc** e redirecione
- Se errou duas vezes seguidas: **`/clear`** e reescreva o prompt com o que voce aprendeu
- Uma sessao limpa com prompt melhor > sessao longa com correcoes acumuladas

### Nomeie suas sessoes

```
/rename cubecell-join-debug
```
Depois retome com:
```bash
claude --resume cubecell-join-debug
```

### Worktrees para trabalho paralelo

Cada worktree e uma copia isolada do repo. Duas sessoes Claude podem trabalhar ao mesmo tempo sem conflito:

```bash
# Sessao 1: firmware novo
claude --worktree feature-rak3172

# Sessao 2: debug infra (em outro terminal)
claude --worktree debug-chirpstack
```

---

## 6. Erros comuns a evitar

| Erro | Sintoma | Solucao |
|---|---|---|
| **Sessao "faz-tudo"** | Comeca com firmware, pede infra, volta para firmware | `/clear` entre tarefas |
| **Corrigir sem parar** | Claude erra, voce corrige, erra de novo, corrige de novo | Apos 2 correcoes: `/clear` + prompt melhor |
| **CLAUDE.md inchado** | Claude ignora instrucoes porque o arquivo e longo demais | Manter so o que causa erro se removido |
| **Confiar sem verificar** | Firmware parece bom mas nao compila ou nao faz join | Sempre pedir para compilar e testar |
| **Exploracao infinita** | Pede "investigue X" sem escopo, Claude le tudo | Escope ("investigue X no examples/firmware/cubecell-otaa-test") ou use subagentes |

---

## 7. Notificacoes (Linux)

Para ser avisado quando o Claude terminar uma tarefa longa, adicione em `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Claude Code precisa da sua atencao'"
          }
        ]
      }
    ]
  }
}
```

---

## 8. Resumo rapido de modelos por tarefa

| Tarefa | Modelo | Esforco |
|---|---|---|
| Consultar backlog | Haiku | min |
| Anotar tarefa | Haiku/Sonnet | min |
| Ler/entender firmware C/C++ | Sonnet | default |
| Ler/entender infra (ChirpStack, MQTT) | Sonnet | default |
| Bug fix firmware simples (1-2 arquivos) | Sonnet | default |
| Debug LoRaWAN join/timing (cross-layer) | Opus | high |
| Planejamento de migracao | Opus | high |
| Analise de consumo/bateria | Opus | high |
| Provisionar device no ChirpStack | Sonnet | default |
| Criar novo firmware template | Sonnet | default |
| Verificar logs SSH | Haiku | min |
| Comparar abordagens tecnicas | Opus | high |
| Criar commit | Sonnet | min |
| Stress test | Sonnet | default |
| Pergunta lateral rapida | `/btw` | — |
