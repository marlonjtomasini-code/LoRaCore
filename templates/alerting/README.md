# Templates de Alertas Externos

Sistema de notificacao push para a infraestrutura LoRaWAN. Usa ntfy.sh como backend primario com suporte a webhook generico. Degrada graciosamente quando offline.

## Arquitetura

```
Scripts de monitoramento → alert_dispatch.sh (spool local)
                                    ↓
                        alert_flush.sh (cron, 5 min)
                                    ↓
                         ntfy.sh / webhook (internet)
                                    ↓
                           Push notification (celular)
```

**Modelo cebola:** monitoramento funciona 100% offline. Alertas sao best-effort — se internet esta indisponivel, alertas ficam no spool e sao entregues quando conectividade retorna. Alertas expiram apos 48h.

## Scripts

| Script | Funcao | Tipo |
|--------|--------|------|
| `alert_dispatch.sh` | Biblioteca sourceable — funcao `alert_send()` para spool de alertas | source |
| `alert_flush.sh` | Entrega alertas do spool para backends externos | cron |

## Placeholders

| Placeholder | Descricao | Exemplo | Usado em |
|-------------|-----------|---------|----------|
| `<USER>` | Usuario do sistema | `seuusuario` | ambos |
| `<NTFY_TOPIC>` | URL do topico ntfy.sh | `https://ntfy.sh/loracore-meusite` | ambos |
| `<NTFY_TOKEN>` | Token de acesso ntfy.sh (opcional) | `tk_abc123` | ambos |
| `<ALERT_WEBHOOK_URL>` | URL de webhook generico (opcional) | `https://hooks.example.com/notify` | ambos |
| `<ALERT_HOST_NAME>` | Nome legivel do gateway | `fazenda-norte-gw01` | dispatch |
| `<ALERT_RATE_LIMIT>` | Max alertas por hora por source | `10` | dispatch |
| `<ALERT_DEDUP_MINUTES>` | Minutos para deduplicacao | `30` | dispatch |

## Deploy

1. Copie os scripts:
   ```bash
   cp alert_dispatch.sh alert_flush.sh ~/
   chmod +x ~/alert_flush.sh
   ```

2. Substitua os placeholders:
   ```bash
   sed -i 's|<USER>|seuusuario|g; s|<NTFY_TOPIC>|https://ntfy.sh/loracore-meusite|g; s|<NTFY_TOKEN>||g; s|<ALERT_WEBHOOK_URL>||g; s|<ALERT_HOST_NAME>|fazenda-norte-gw01|g; s|<ALERT_RATE_LIMIT>|10|g; s|<ALERT_DEDUP_MINUTES>|30|g' ~/alert_dispatch.sh ~/alert_flush.sh
   ```

3. Crie o diretorio de spool:
   ```bash
   sudo mkdir -p /var/spool/lorawan-alerts
   sudo chown seuusuario:seuusuario /var/spool/lorawan-alerts
   ```

4. Configure o crontab do usuario:
   ```bash
   crontab -e
   # Adicionar:
   */5 * * * * /bin/bash /home/seuusuario/alert_flush.sh
   ```

## Severidades

| Severidade | Prioridade ntfy | Eventos |
|------------|-----------------|---------|
| `CRITICAL` | urgent | Concentrador falhou restart, circuit breaker abriu, disco >95% |
| `WARNING` | high | Servico inativo, device offline, backup falhou, disco >80% |
| `INFO` | default | Relatorio diario, backup OK |

## Integracao com Scripts Existentes

Os scripts de monitoramento fazem `source alert_dispatch.sh` no inicio. Se o arquivo nao existir, a linha `|| true` garante que o script continua funcionando normalmente (log-only).

## Configuracao ntfy.sh

1. Instale o app ntfy no celular (Android/iOS)
2. Inscreva-se no topico escolhido (ex: `loracore-meusite`)
3. Para topicos protegidos, gere um token em https://ntfy.sh/account
4. Para self-hosting: https://docs.ntfy.sh/install/
