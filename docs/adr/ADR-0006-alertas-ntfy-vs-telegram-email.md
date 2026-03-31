# ADR-0006: Alertas externos via ntfy.sh vs Telegram vs Email

**Data:** 2026-03-31
**Status:** Aceito
**Contexto:** Plano de auto-recuperacao para operacao remota desassistida

## Decisao

Usar **ntfy.sh** como backend primario de alertas externos, com suporte a webhook generico como secundario. Alertas sao spoolados localmente e entregues quando internet esta disponivel.

## Contexto

O gateway RPi5 operara em local de dificil acesso sem internet garantida. Os scripts de monitoramento existentes (ADR-0004) apenas gravam logs locais — o operador precisa fazer SSH para verificar. Falhas criticas podem passar despercebidas por dias.

### Opcao A: Telegram Bot API (descartada)

- Requer registrar bot e obter chat_id (processo manual)
- API mais complexa (JSON response parsing)
- Dependencia de servico terceiro (Telegram servers)
- Parsing de resposta necessario para confirmar entrega

### Opcao B: Email via ssmtp/msmtp (descartada)

- Requer configuracao de relay SMTP (servidor, TLS, credenciais)
- Depurar falhas de email e dificil remotamente
- Atraso de entrega variavel (minutos a horas)
- TLS certificates podem expirar silenciosamente

### Opcao C: ntfy.sh (aceita)

- Um unico `curl -d "msg" ntfy.sh/topic` — zero configuracao
- App nativo mobile (Android/iOS) com push instantaneo
- Self-hostavel para privacidade
- Suporta prioridades, tags e formatacao
- Token de acesso opcional (topicos publicos funcionam sem auth)

## Justificativa

1. **Simplicidade**: ntfy.sh requer apenas `curl` (ja presente para `device_monitor.sh`). Nenhuma dependencia adicional.

2. **Offline-first**: alertas sao spoolados em `/var/spool/lorawan-alerts/` e entregues pelo `alert_flush.sh` quando internet retorna. O monitoramento local nunca e afetado.

3. **Zero conta obrigatoria**: topicos publicos funcionam sem registro. Para privacidade, tokens sao opcionais.

4. **Webhook como escape-hatch**: o webhook generico cobre qualquer backend HTTP (Discord, Slack, Home Assistant, custom).

## Consequencias

- **Positivas**: operador recebe push notification no celular em segundos; alertas sobrevivem outages de internet; zero impacto no monitoramento existente
- **Negativas**: topicos publicos sem token sao vissiveis por qualquer um que adivinhe o nome; spool consome espaco em disco (mitigado por prune de 48h)
- **Riscos**: se ntfy.sh (servico publico) ficar indisponivel, alertas ficam no spool indefinidamente — mitigado por self-hosting ou webhook alternativo

## Referencia

- https://docs.ntfy.sh/
- ADR-0004 (observabilidade scripts vs Prometheus)
- `templates/alerting/README.md`
