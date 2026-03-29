# Politica de Seguranca

## Reportar Vulnerabilidades

Se voce encontrar uma vulnerabilidade de seguranca no LoRaCore, **nao abra uma issue publica**. Entre em contato diretamente com os mantenedores para que possamos avaliar e corrigir antes da divulgacao.

## Credenciais nos Templates

Os arquivos em `templates/` contem **placeholders** (ex: `<GATEWAY_ID>`, `<SECRET>`) que devem ser substituidos por valores unicos em cada instalacao. Nunca use credenciais de exemplo em producao.

Os valores encontrados em `examples/firmware/cubecell-otaa-test/` (DevEUI, AppKey) sao exclusivamente para **teste e validacao** em ambiente de desenvolvimento. Dispositivos de producao devem gerar chaves unicas via ChirpStack.

## Modelo de Seguranca

O LoRaCore opera em modo **100% offline** — sem dependencia de servicos em nuvem. Isso reduz significativamente a superficie de ataque:

- Sem APIs expostas a internet
- Sem telemetria para terceiros
- Comunicacao LoRaWAN criptografada end-to-end (AES-128)
- MQTT restrito a rede local (`allow_anonymous true` e aceitavel em rede isolada; adicione autenticacao se expor a rede mais ampla)

## Boas Praticas para Deploy

- Gerar `secret` unico no `chirpstack.toml` com `openssl rand -base64 32`
- Gerar DevEUI e AppKey unicos por dispositivo
- Restringir acesso SSH ao Raspberry Pi
- Manter firmware e ChirpStack atualizados
- Monitorar logs via `journalctl` regularmente
