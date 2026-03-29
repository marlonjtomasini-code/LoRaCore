# Script de Deploy Automatizado

Script interativo para deploy completo da infraestrutura LoRaWAN em um Raspberry Pi 5. Automatiza os 18+ passos manuais documentados na Secao 19 do DOC_PROTOCOLO.

## Prerequisitos

- Raspberry Pi 5 com Ubuntu 24.04 ou Raspberry Pi OS (Bookworm)
- Conectividade de rede (para instalar pacotes — apos deploy, funciona 100% offline)
- Concentrador LoRa (RAK2287) conectado via hat SPI
- Clone do LoRaCore disponivel no host

## Uso

```bash
# Clone o LoRaCore no RPi
git clone https://github.com/marlonjtomasini-code/LoRaCore.git

# Execute o script de deploy
sudo bash LoRaCore/templates/deploy/setup-loracore.sh --loracore-dir ./LoRaCore
```

## Opcoes

| Opcao | Descricao |
|-------|-----------|
| `--loracore-dir DIR` | Path do clone do LoRaCore (obrigatorio) |
| `--non-interactive` | Usar defaults sem prompts |
| `--skip-pktfwd` | Pular compilacao do packet forwarder |
| `--dry-run` | Mostrar o que seria feito sem executar |

## O que o script faz

| Fase | Acao | Idempotente |
|------|------|-------------|
| 0 | Coleta configuracoes (prompts interativos) | — |
| 1 | Configura swap 2GB | Sim (verifica se ja existe) |
| 2 | Instala pacotes base (PostgreSQL, Redis, Mosquitto) | Sim (verifica dpkg) |
| 3 | Cria role e database PostgreSQL | Sim (verifica existencia) |
| 4 | Ativa Redis | Sim |
| 5 | Aplica config do Mosquitto | Sim (verifica arquivo) |
| 6 | Instala ChirpStack via repositorio | Sim (verifica dpkg) |
| 7 | Copia e configura templates (chirpstack, region, MQTT forwarder) | Sobrescreve |
| 8 | Aplica systemd overrides, sysctl, udev, offline mode | Sobrescreve |
| 9 | Compila packet forwarder (sx1302_hal) | Sim (verifica binario) |
| 10 | Ativa servicos ChirpStack | Sim |
| 11 | Copia scripts de monitoramento (opcional) | Sobrescreve |
| 12 | Copia scripts de backup (opcional) | Sobrescreve |
| 13 | Health check final (verifica todos os servicos) | — |

## Configuracoes solicitadas

O script pede as seguintes informacoes via prompt interativo:

| Configuracao | Descricao | Default |
|-------------|-----------|---------|
| Usuario | Usuario do sistema no RPi | (detectado automaticamente) |
| Gateway ID | EUI do gateway (16 hex) | `0000000000000000` |
| Senha PostgreSQL | Senha do role chirpstack | `chirpstack` |
| Secret ChirpStack | Secret para sessoes e tokens | (auto-gerado) |
| Path packet forwarder | Diretorio do binario | `/home/<user>/packet_forwarder` |
| Diretorio de backups | Diretorio para backups locais | `/home/<user>/backups` |

## Apos o deploy

1. Acessar ChirpStack Web UI em `http://<IP>:8080`
2. Criar tenant e application
3. Registrar gateway com o Gateway ID configurado
4. Criar device profiles (Class A / Class C)
5. Registrar devices
6. Configurar crontab para monitoramento e backup (ver `templates/monitoring/README.md` e `templates/backup/README.md`)

## Disaster Recovery

Em caso de falha de SD card ([RUNBOOK-002](../../docs/runbooks/RUNBOOK-002-sd-card-failure.md)):

1. Gravar imagem base no novo SD
2. Executar este script para reinstalar a infraestrutura
3. Restaurar dados com `lorawan-restore.sh --from-remote`

## Referencia manual

A Secao 19 do [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](../../docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md) permanece como referencia autoritativa para deploy manual passo a passo.
