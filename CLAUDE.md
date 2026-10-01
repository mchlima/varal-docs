@AGENTS.md

## Específico do Claude Code

- As instruções completas do projeto estão em `AGENTS.md`, importado acima. Mantenha as regras do projeto lá, não aqui, para que outros agentes também as vejam.
- O documento de escopo original, que deu origem às specs, é o Claude Doc "Varal — Escopo do MVP": https://claude.ai/code/artifact/57311d5e-1f4b-4c92-a53e-2574eade0a3a. As specs em `docs/specs/` prevalecem sobre ele.
- Converse com o usuário em português do Brasil.
- Vários agentes trabalham neste repositório ao mesmo tempo. Antes de editar qualquer arquivo, entre num worktree próprio, criado em `.worktrees/` como descrito no `AGENTS.md` (a ferramenta `EnterWorktree` do Claude Code também serve). Nunca edite na raiz do repositório.
