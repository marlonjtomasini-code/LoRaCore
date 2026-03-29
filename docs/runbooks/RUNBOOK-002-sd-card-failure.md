# RUNBOOK-002: Falha de MicroSD / Filesystem Read-Only

**Trigger:** Erros de I/O em `dmesg`, filesystem monta em read-only, servicos nao conseguem gravar.

**Tempo estimado:** 30-60 minutos (inclui restore)

---

## 1. Deteccao

Sinais de problema no microSD:

```bash
# Erros de I/O no kernel
$ dmesg | grep -iE "i/o error|read-only|ext4.*error|mmc"

# Filesystem read-only (servicos falham ao gravar)
$ touch /tmp/test-write && echo "OK write" || echo "FALHA: filesystem read-only"

# Disco reportando erros
$ journalctl -k --since "1 hour ago" | grep -iE "error|fail|mmc"

# Servicos falhando com "Read-only file system"
$ journalctl -u postgresql --since "30 minutes ago" | grep -i "read-only"
```

---

## 2. Triagem

### O filesystem esta read-only?

```bash
$ mount | grep " / " | grep -o "ro\|rw"
# Se "ro" → filesystem em read-only, SD pode estar falhando
# Se "rw" → SD OK, problema pode ser de espaco
```

### E problema de espaco?

```bash
$ df -h /
# Se >95% usado, liberar espaco antes de investigar SD
```

### Quantos erros de I/O?

```bash
$ dmesg | grep -c "I/O error"
# Poucos erros isolados = pode ser transitorio
# Muitos erros continuos = SD provavelmente danificado
```

### Idade do microSD

MicroSD em RPi5 com escritas constantes (PostgreSQL, Redis, logs) tem vida util limitada. Se o SD tem mais de 1 ano de uso intenso, considere substituicao preventiva.

---

## 3. Recovery

### 3.1 Erro transitorio (poucos erros, filesystem rw)

Se o filesystem ainda esta em rw e os erros sao esporadicos:

```bash
# Forcar sync de buffers
$ sudo sync

# Verificar e corrigir filesystem (requer reboot)
$ sudo touch /forcefsck
$ sudo reboot
```

Apos reboot, verificar se os erros pararam:

```bash
$ dmesg | grep -iE "i/o error|mmc"
```

### 3.2 Filesystem read-only (SD danificado)

O SD esta danificado e precisa ser substituido. Procedimento:

**Passo 1 — Verificar se o ultimo backup esta disponivel:**

```bash
$ ls -la <BACKUP_DIR>/chirpstack_*.dump | tail -3
$ cat /var/log/lorawan-backup.log | grep "backup finalizado" | tail -1
```

**Passo 2 — Se possivel, copiar backup para maquina externa:**

```bash
# Do seu computador, copiar backups do RPi antes que morra completamente
$ scp <USER>@<LORACORE_HOST>:<BACKUP_DIR>/*.dump ./backup-emergencia/
$ scp <USER>@<LORACORE_HOST>:<BACKUP_DIR>/*.tar.gz ./backup-emergencia/
```

**Passo 3 — Se backup local inacessivel, usar Google Drive:**

O backup diario sincroniza para Google Drive. Acesse os artefatos de la.

**Passo 4 — Substituir o microSD:**

1. Desligar RPi5 (`sudo poweroff`)
2. Remover o microSD danificado
3. Gravar imagem base do Raspberry Pi OS no novo microSD
4. Reinstalar os servicos da stack (seguir DOC_PROTOCOLO secoes 3-16)
5. Copiar templates do LoRaCore e substituir placeholders

**Passo 5 — Restaurar dados do backup:**

```bash
# Modo dry-run primeiro (mostra o que faria sem executar)
$ sudo bash ~/lorawan-restore.sh --date YYYYMMDD --dry-run

# Restaurar de backup local
$ sudo bash ~/lorawan-restore.sh --date YYYYMMDD

# Ou restaurar puxando do Google Drive
$ sudo bash ~/lorawan-restore.sh --date YYYYMMDD --from-remote
```

O script de restore e interativo — pede confirmacao antes de cada operacao destrutiva (PostgreSQL, Redis, configs).

---

## 4. Pos-incidente

```bash
# Confirmar todos os servicos ativos
$ systemctl is-active lora-pkt-fwd chirpstack-mqtt-forwarder mosquitto chirpstack chirpstack-rest-api postgresql redis-server

# Confirmar que devices estao registrados
$ curl -s http://localhost:8090/api/devices?limit=10 -H "Authorization: Bearer <CHIRPSTACK_TOKEN>" | grep -c devEui

# Verificar que backup esta funcionando no novo SD
$ sudo bash ~/lorawan-backup.sh
$ tail -5 /var/log/lorawan-backup.log

# Monitorar por 1 hora para confirmar estabilidade
$ journalctl -f -u lora-pkt-fwd -u chirpstack
```

### Prevencao

- Manter `vm.swappiness=10`, `vm.dirty_ratio=10` (sysctl tuning para reduzir escritas)
- Usar microSD de alta durabilidade (classe A2, marca reconhecida)
- Verificar `dmesg | grep mmc` periodicamente no `daily_report.sh`
- Manter backup diario funcional e verificado
