# TASK-2026-0013 — Melhorar confiabilidade do backup

- **Severidade:** S2
- **Status:** pendente
- **Origem:** Code review 2026-04-02

## O que

Corrigir riscos de data loss e falhas silenciosas no sistema de backup.

## Por que

Backup pode copiar snapshot stale do Redis sem aviso claro. Falha do rclone é ignorada no exit code.

## Itens

### Críticos
1. **Data loss Redis em `lorawan-backup.sh:114-124`** — se BGSAVE dá timeout, copia snapshot antigo sem marcar backup como parcial. Validar que snapshot foi atualizado antes de copiar; se não, marcar fase como falha.

### Altos
2. **Falha silenciosa do rclone em `lorawan-backup.sh:214-229`** — sync remoto falha mas backup reporta sucesso. Incluir falha rclone no exit code final.
3. **pg_dump sem validação de tamanho** — verificar que dump não está vazio antes de considerar sucesso.

### Médios
4. **tar exit code 1 aceito silenciosamente em `lorawan-backup.sh:182-188`** — documentar melhor que arquivos podem estar incompletos.

## Aceite
- [ ] Backup com Redis stale é reportado como falha/parcial
- [ ] Falha rclone reflete no exit code do script
- [ ] pg_dump vazio é detectado como erro
- [ ] Nenhuma regressão no backup existente
