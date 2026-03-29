# Changelog

Todas as mudancas relevantes do projeto sao documentadas neste arquivo.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Nao publicado]

### Adicionado
- Templates de monitoramento (`templates/monitoring/`): health check, watchdog do concentrador, monitor de devices offline, relatorio diario, logrotate
- Script de deploy automatizado (`templates/deploy/setup-loracore.sh`): instalacao completa em 13 fases, interativo, idempotente
- Testes automatizados de codecs (`templates/codecs/tests/`): 5 testes standalone com Node.js assert, validacao de decode/encode/roundtrip
- Runbooks operacionais (`docs/runbooks/`): 5 cenarios — service failure, SD card, gateway, backup, device offline
- ADR-0004: Observabilidade via scripts shell vs Prometheus/Grafana
- ADR-0005: Confirmed uplinks degradam sob stress — usar unconfirmed para telemetria
- Template de autenticacao MQTT (`templates/mosquitto/password_auth.conf`) para redes nao-isoladas
- Job `test-codecs` no CI (`validate-core.yml`)
- Release engineering: tags v0.1.0 e v0.2.0, GitHub Releases, secao Versionamento no README

### Alterado
- SECURITY.md expandido: topologia de rede, portas, decisao MQTT ACLs, checklist SSH hardening, rotacao de tokens
- CLAUDE.md, README.md e docs/README.md atualizados com novos diretorios e ADRs

### Corrigido
- `applicationId` obrigatorio na API de devices do ChirpStack v4 nos scripts de monitoramento

## [0.2.0] - 2026-03-29

### Adicionado
- Relatorio de stress test v2 (`docs/RELATORIO_STRESS_TEST_V2.md`): validacao do MQTT Forwarder (Rust) sob 6 fases de carga progressiva — entrega de 79% sob stress total vs 0% com Gateway Bridge (Go)
- Relatorio de stress test v3 (`docs/RELATORIO_STRESS_TEST_V3.md`): validacao de 2 devices simultaneos sob carga extrema — D1 delivery 85%, D2 delivery 11%
- Systemd overrides para chirpstack e mosquitto (`templates/systemd/chirpstack-priority.conf`, `mosquitto-priority.conf`): CPUWeight, Nice, MemoryHigh/MemoryMax
- Limites de memoria (MemoryHigh/MemoryMax) adicionados a todos os servicos criticos via systemd
- Sysctl tuning para durabilidade do microSD: vm.swappiness=10, vm.dirty_ratio=10, vm.dirty_background_ratio=5
- Firmware dual-device para stress test (`src/device1.cpp`, `src/device2.cpp`) com PlatformIO multi-environment
- Codec para Device 2 do stress test (`templates/codecs/cubecell-stress-test-device2.js`): payload 14 bytes
- Templates de backup e restore (`templates/backup/`): script de backup diario com sync para Google Drive via rclone, script de restauracao guiada interativo, guia de setup completo
- Reestruturacao completa do repositorio para padrao open-source GitHub
- Diretorio `templates/` com configuracoes reutilizaveis extraidas da documentacao
- Diretorio `examples/` para firmwares de teste e validacao
- Estrutura `.github/` com templates de issues, PR e CI/CD
- Arquivos padrao: README.md, LICENSE (MIT), CONTRIBUTING.md, SECURITY.md, CHANGELOG.md, .editorconfig

### Corrigido
- Codec error handling: retorno de `{ errors: [...] }` em vez de `{ data: {} }` para payloads invalidos — erros agora visiveis no ChirpStack Web UI e MQTT

### Alterado
- Documentacao publica generalizada: IPs, usuarios e credenciais hardcoded substituidos por placeholders (`<LORACORE_HOST>`, `<USER>`, etc.)
- IP da RPi5 atualizado de 192.168.1.129 para 192.168.1.200 em documentacao e templates
- Tarefas concluidas (TASK-0001, 0002, 0004) arquivadas; TASK-0003 marcada como bloqueada
- CLAUDE.md, README.md e docs/README.md atualizados com arquivos ausentes (GUIA_CONSUMIDOR, RELATORIO_STRESS_TEST_V2)
- Firmware CubeCell movido para `examples/firmware/cubecell-otaa-test/` (reclassificado como codigo de teste)
- Documentacao canonica movida para `docs/`
- `.gitignore` expandido para PlatformIO e IDEs

## [0.1.0] - 2026-03-28

### Adicionado
- Infraestrutura LoRaWAN completa validada: RPi5 + RAK2287 + ChirpStack v4.17.0
- Firmware de referencia CubeCell HTCC-AB01 (OTAA, Class A, US915 sub-band 1)
- Documentacao canonica do protocolo de comunicacao (22 secoes, 1400+ linhas)
- Relatorio de stress test com validacao de performance sob carga extrema
- Documentacao canonica do protocolo e relatorio de stress test
- Sistema de gestao de tarefas (backlog) com templates TDD
