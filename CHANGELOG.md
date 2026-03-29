# Changelog

Todas as mudancas relevantes do projeto sao documentadas neste arquivo.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Nao publicado]

### Adicionado
- Reestruturacao completa do repositorio para padrao open-source GitHub
- Diretorio `templates/` com configuracoes reutilizaveis extraidas da documentacao
- Diretorio `examples/` para firmwares de teste e validacao
- Estrutura `.github/` com templates de issues, PR e CI/CD
- Arquivos padrao: README.md, LICENSE (MIT), CONTRIBUTING.md, SECURITY.md, CHANGELOG.md, .editorconfig

### Alterado
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
