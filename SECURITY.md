# Politica de Seguranca

## Reportar Vulnerabilidades

Se voce encontrar uma vulnerabilidade de seguranca no LoRaCore, **nao abra uma issue publica**. Entre em contato diretamente com os mantenedores para que possamos avaliar e corrigir antes da divulgacao.

## Credenciais nos Templates

Os arquivos em `templates/` contem **placeholders** (ex: `<GATEWAY_ID>`, `<SECRET>`) que devem ser substituidos por valores unicos em cada instalacao. Nunca use credenciais de exemplo em producao.

Os valores encontrados em `examples/firmware/cubecell-otaa-test/` (DevEUI, AppKey) sao exclusivamente para **teste e validacao** em ambiente de desenvolvimento. Dispositivos de producao devem gerar chaves unicas via ChirpStack.

## Modelo de Seguranca

O LoRaCore opera em modo **100% offline** — sem dependencia de servicos em nuvem. A postura de seguranca depende de **isolamento de rede** como controle primario.

### Camadas de protecao

| Camada | Mecanismo |
|--------|-----------|
| RF (LoRaWAN) | AES-128 end-to-end (NwkSKey + AppSKey), geradas via OTAA |
| Network Server | ChirpStack valida MIC de cada frame, rejeita replay attacks |
| MQTT | Anonimo em rede isolada (decisao consciente — ver abaixo) |
| Banco de dados | PostgreSQL bind a localhost, acesso via unix socket |
| Cache | Redis bind a localhost, sem senha (padrao para single-node) |
| SSH | Unico ponto de acesso remoto ao RPi5 |

## Topologia de Rede e Portas

### Servicos e bind addresses

| Servico | Porta | Bind | Acesso esperado |
|---------|-------|------|-----------------|
| ChirpStack Web UI | 8080 | `0.0.0.0` | LAN (navegador do operador) |
| ChirpStack REST API | 8090 | `0.0.0.0` | LAN (scripts, integracao) |
| ChirpStack gRPC | 8083 | `localhost` | Apenas local (REST proxy) |
| Mosquitto MQTT | 1883 | `0.0.0.0` | LAN (devices e integracao) |
| PostgreSQL | 5432 | `localhost` | Apenas local (ChirpStack) |
| Redis | 6379 | `localhost` | Apenas local (ChirpStack) |

**Nota:** ChirpStack Web UI, REST API e Mosquitto escutam em `0.0.0.0` para permitir acesso via LAN. Se a rede nao for isolada, restringir com firewall (`ufw`, `nftables`) ou bind a IP especifico.

### Decisao sobre MQTT sem autenticacao

O Mosquitto opera com `allow_anonymous true` por decisao consciente:

- **Contexto:** rede industrial isolada sem acesso a internet
- **Consumidores:** apenas ChirpStack, MQTT Forwarder e scripts locais
- **Risco aceito:** qualquer dispositivo na LAN pode publicar/subscrever em qualquer topico MQTT
- **Quando mudar:** se a rede deixar de ser isolada, ou se dispositivos nao-confiados forem conectados

Para habilitar autenticacao MQTT, use o template `templates/mosquitto/password_auth.conf`.

## Checklist de Hardening SSH

O RPi5 e acessivel via SSH. Recomendacoes minimas:

- [ ] Desabilitar login com senha, usar apenas chave publica
  ```bash
  # /etc/ssh/sshd_config
  PasswordAuthentication no
  PubkeyAuthentication yes
  ```
- [ ] Desabilitar login root
  ```bash
  PermitRootLogin no
  ```
- [ ] Alterar porta padrao (opcional, dificulta scan)
  ```bash
  Port 2222
  ```
- [ ] Instalar fail2ban para bloquear brute-force
  ```bash
  sudo apt install fail2ban
  sudo systemctl enable fail2ban
  ```
- [ ] Restringir acesso SSH por IP (se rede tem faixa fixa)
  ```bash
  # /etc/ssh/sshd_config
  AllowUsers <USER>@192.168.1.*
  ```

## Rotacao de Tokens e Credenciais

### API Token do ChirpStack

O ChirpStack usa API tokens para autenticacao na REST API. Recomendacoes:

- Gerar um token por aplicacao/integracao (nao compartilhar)
- Rotacionar tokens a cada 6 meses ou quando um operador perder acesso
- Para gerar novo token via Web UI: Tenant > API Keys > Create
- Para gerar via psql (quando REST login indisponivel):
  ```bash
  sudo -u postgres psql -d chirpstack -c "SELECT encode(id::bytea, 'hex') FROM api_key;"
  ```

### Secret do ChirpStack

O `secret` no `chirpstack.toml` protege sessoes e tokens internos:

```bash
# Gerar secret unico
openssl rand -base64 32
```

Trocar o secret invalida todas as sessoes ativas — rotacionar em janela de manutencao.

### Chaves LoRaWAN (DevEUI, AppKey)

- Geradas automaticamente pelo ChirpStack durante OTAA join
- Nao rotacionar manualmente (gerenciamento pelo network server)
- Para revogar um device: deletar do ChirpStack e re-registrar com nova AppKey

## Boas Praticas para Deploy

- Gerar `secret` unico no `chirpstack.toml` com `openssl rand -base64 32`
- Gerar DevEUI e AppKey unicos por dispositivo
- Restringir acesso SSH ao Raspberry Pi (ver checklist acima)
- Manter firmware e ChirpStack atualizados
- Monitorar logs via `journalctl` e scripts de monitoramento
- Manter backup diario funcional e verificado
- Se expor MQTT fora da rede isolada: habilitar autenticacao (ver template)
