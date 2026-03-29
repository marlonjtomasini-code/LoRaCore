---
id: TASK-2026-0005
title: Release Engineering — tags, semver, GitHub Releases
status: pending
phase: analise
severity: S3
owner: coordenador
created: 2026-03-29
updated: 2026-03-29
depends_on: []
blocked_by: []
parent: ~
children: []
plan_doc: ~
write_scope:
  - CHANGELOG.md
  - README.md
context_reads:
  - CHANGELOG.md
  - README.md
  - CONTRIBUTING.md
acceptance:
  - git tag v0.1.0 existe no commit correspondente ao CHANGELOG [0.1.0]
  - secao [Nao publicado] do CHANGELOG promovida para [0.2.0] com data
  - git tag v0.2.0 existe no HEAD atual
  - GitHub Releases criadas para v0.1.0 e v0.2.0 (via gh release create)
  - README.md contem secao "Versionamento" explicando semver e breaking changes
restrictions: []
hardware_required: []
bom: []
tags:
  - producao
  - release
---

## Retomada

ESTADO: aguardando_execucao
AGENTE: coordenador
PROXIMA: criar tag v0.1.0 no commit correto, promover CHANGELOG, criar tag v0.2.0, criar GitHub Releases
LER:
- CHANGELOG.md
- CONTRIBUTING.md (secao Contrato de Interface)
DECIDIDO:
- semver: MAJOR = breaking (topics MQTT, schema codecs), MINOR = novos templates, PATCH = fixes
- v0.1.0 = infraestrutura validada (2026-03-28), v0.2.0 = hardening + stress tests + backup + reestruturacao
PENDENTE:
- nenhuma

## Analise Preliminar

### Contexto

O projeto tem 20+ commits e CHANGELOG com versao [0.1.0] definida, mas zero git tags. Consumidores nao conseguem pinar versao conhecida. Formalizar versionamento e o primeiro passo para producao — sem custo tecnico, alto valor de governanca.

### Decisoes ja tomadas

- Semantic versioning (MAJOR.MINOR.PATCH)
- v0.1.0 = baseline da infraestrutura validada
- v0.2.0 = tudo que veio depois (hardening, stress tests v2/v3, backup, reestruturacao open-source)
- O que e breaking change: mudanca em topicos MQTT, schema de output dos codecs, parametros de templates

### Perguntas a Investigar

#### Versionamento
1. Qual commit exato corresponde ao [0.1.0] no CHANGELOG? (buscar por data 2026-03-28)
2. O README ja menciona versao em algum lugar que precise ser atualizado?

### Fontes de Referencia

- https://keepachangelog.com/pt-BR/1.1.0/
- https://semver.org/lang/pt-BR/
- CONTRIBUTING.md (secao Contrato de Interface)

## Checklist

- [ ] Identificar commit exato do v0.1.0
- [ ] Criar git tag v0.1.0
- [ ] Promover [Nao publicado] para [0.2.0] no CHANGELOG.md
- [ ] Criar git tag v0.2.0
- [ ] Criar GitHub Release v0.1.0 com release notes
- [ ] Criar GitHub Release v0.2.0 com release notes
- [ ] Adicionar secao "Versionamento" no README.md
