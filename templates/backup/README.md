# Backup e Restauracao da Infraestrutura LoRaWAN

Backup diario automatizado da infraestrutura LoRaWAN com sync remoto para Google Drive via [rclone](https://rclone.org/).

**Referencia canonica:** [DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md](../../docs/DOC_PROTOCOLO_COMUNICACAO_LORAWAN.md), Secao 17.4

## Artefatos do Backup

| Arquivo | Conteudo | Metodo |
|---------|----------|--------|
| `chirpstack_YYYYMMDD.dump` | Banco PostgreSQL completo (devices, session keys, configs) | `pg_dump -Fc` |
| `redis_YYYYMMDD.rdb` | Snapshot do Redis (cache de sessao) | BGSAVE + copy |
| `configs_YYYYMMDD.tar.gz` | Todos os arquivos de configuracao + crontabs | `tar czf` |

## Arquivos

| Arquivo | Descricao |
|---------|-----------|
| `lorawan-backup.sh` | Script de backup diario + sync para Google Drive |
| `lorawan-restore.sh` | Script de restauracao guiada (interativo) |

## Placeholders

| Placeholder | Descricao | Exemplo |
|-------------|-----------|---------|
| `<USER>` | Usuario do sistema | `marlon` |
| `<BACKUP_DIR>` | Diretorio de backup local | `/home/marlon/backups` |
| `<RCLONE_REMOTE>` | Nome do remote rclone | `gdrive` |
| `<REMOTE_DIR>` | Pasta no Google Drive | `LoRaCore-backups` |
| `<PG_DATABASE>` | Banco PostgreSQL | `chirpstack` |
| `<RETENTION_DAYS>` | Dias de retencao | `30` |

## Setup Completo

### 1. Instalar rclone

```bash
# Debian/Ubuntu (RPi OS)
sudo apt install rclone

# Fedora
sudo dnf install rclone

# Ou via script oficial
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configurar Google Drive (headless)

O RPi5 nao tem browser. Use o fluxo de autorizacao remota:

**Opcao A — Autorizar direto no RPi5:**

```bash
sudo rclone config

# Responder:
#   n) New remote
#   name> gdrive
#   Storage> drive
#   client_id> (Enter — usa default)
#   client_secret> (Enter)
#   scope> 1 (Full access)
#   service_account_file> (Enter)
#   Edit advanced config? n
#   Use auto config? n
#
# rclone vai imprimir uma URL. Abra essa URL em um computador COM browser.
# Complete o consentimento OAuth no browser.
# Cole o token de volta no terminal do RPi5.
```

**Opcao B — Configurar em outra maquina e copiar:**

```bash
# Na maquina com browser:
rclone config   # completar setup normalmente

# Copiar o config para o RPi5:
scp ~/.config/rclone/rclone.conf marlon@192.168.1.129:/tmp/
ssh marlon@192.168.1.129 "sudo mkdir -p /root/.config/rclone && sudo mv /tmp/rclone.conf /root/.config/rclone/ && sudo chmod 600 /root/.config/rclone/rclone.conf"
```

### 3. Verificar conectividade

```bash
# Listar pastas no Drive
sudo rclone lsd gdrive:

# Criar pasta de backup
sudo rclone mkdir gdrive:LoRaCore-backups

# Teste de upload
echo "test" | sudo rclone rcat gdrive:LoRaCore-backups/test.txt
sudo rclone ls gdrive:LoRaCore-backups/
sudo rclone delete gdrive:LoRaCore-backups/test.txt
```

### 4. Instalar o script de backup

```bash
# Copiar template e preencher placeholders
cp templates/backup/lorawan-backup.sh ~/lorawan-backup.sh
chmod +x ~/lorawan-backup.sh

# Editar e substituir placeholders:
#   <USER>           -> marlon
#   <BACKUP_DIR>     -> /home/marlon/backups
#   <RCLONE_REMOTE>  -> gdrive
#   <REMOTE_DIR>     -> LoRaCore-backups
#   <PG_DATABASE>    -> chirpstack
#   <RETENTION_DAYS> -> 30
```

### 5. Primeira execucao manual

```bash
sudo bash ~/lorawan-backup.sh

# Verificar artefatos locais
ls -lh ~/backups/

# Verificar artefatos no Google Drive
sudo rclone ls gdrive:LoRaCore-backups/

# Verificar log
cat /var/log/lorawan-backup.log
```

### 6. Configurar cron

```bash
# Adicionar ao crontab do root
sudo crontab -e

# Adicionar a linha:
0 3 * * * /bin/bash /home/marlon/lorawan-backup.sh
```

### 7. Instalar script de restore (opcional)

```bash
cp templates/backup/lorawan-restore.sh ~/lorawan-restore.sh
chmod +x ~/lorawan-restore.sh
# Editar e substituir os mesmos placeholders
```

## Restore

### Restaurar do backup local

```bash
sudo bash ~/lorawan-restore.sh --date 20260329
```

### Restaurar puxando do Google Drive

```bash
sudo bash ~/lorawan-restore.sh --date 20260329 --from-remote
```

### Simular sem executar

```bash
sudo bash ~/lorawan-restore.sh --date 20260329 --dry-run
```

## Verificacao Periodica

### Testar restore em banco temporario (sem afetar producao)

```bash
sudo -u postgres createdb chirpstack_restore_test
sudo -u postgres pg_restore -d chirpstack_restore_test ~/backups/chirpstack_$(date +%Y%m%d).dump
sudo -u postgres psql -d chirpstack_restore_test -c "SELECT count(*) FROM device"
sudo -u postgres dropdb chirpstack_restore_test
```

### Verificar retencao

```bash
# Contar backups locais
ls ~/backups/chirpstack_*.dump | wc -l   # deve ser <= 30

# Contar backups remotos
sudo rclone ls gdrive:LoRaCore-backups/ | grep chirpstack | wc -l
```

## Troubleshooting

### Token OAuth expirou

```bash
# Re-autorizar o remote
sudo rclone config reconnect gdrive:
```

O backup local continua funcionando mesmo sem token valido — apenas o sync remoto falha.

### Disco cheio

O script verifica espaco antes de iniciar. Se o disco estiver com menos de 500 MB livres, o backup e abortado com log de erro. A retencao de 30 dias limita o crescimento — cada dia ocupa aproximadamente 10-60 MB dependendo do numero de devices.

### Backup local funciona mas sync falha

Comportamento esperado quando o RPi5 esta sem internet. O rclone sync e independente — na proxima execucao com internet, todos os backups locais acumulados serao sincronizados.

### pg_dump falha com permissao negada

O script deve rodar como root. Verificar: `sudo bash ~/lorawan-backup.sh`
