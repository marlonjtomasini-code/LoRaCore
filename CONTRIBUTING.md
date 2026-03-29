# Contribuindo com o LoRaCore

## Como Contribuir

1. Fork o repositorio
2. Crie uma branch para sua feature ou fix (`git checkout -b feat/minha-feature`)
3. Faca suas alteracoes seguindo os padroes abaixo
4. Commit seguindo o padrao de mensagens
5. Abra um Pull Request

## Padrao de Commits

Prefixos obrigatorios:

| Prefixo | Uso |
|---------|-----|
| `feat:` | Nova funcionalidade |
| `fix:` | Correcao de bug |
| `docs:` | Alteracao em documentacao |
| `refactor:` | Refatoracao sem mudanca de comportamento |
| `test:` | Adicao ou alteracao de testes |
| `chore:` | Manutencao, CI, configs |

Exemplo: `feat: adicionar template de device profile Class B`

## Requisitos

- **Templates:** devem ser extraidos da documentacao canonica e usar placeholders para valores instance-specific
- **Codecs:** devem ser testados com payloads reais no ChirpStack
- **Firmware de teste:** deve compilar com `pio run` sem erros
- **Documentacao:** toda mudanca de comportamento deve atualizar a documentacao correspondente (docs-as-code)

## TDD para Embedded

Firmwares de teste seguem a metodologia TDD por fases descrita no [CLAUDE.md](CLAUDE.md). Cada fase aborda uma unica preocupacao e tem gate de verificacao obrigatorio.

## Estilo de Codigo

Siga as configuracoes do [.editorconfig](.editorconfig):
- C/C++: indent 4 espacos
- YAML/JSON/TOML/Markdown: indent 2 espacos
- UTF-8, LF, trailing whitespace removido
