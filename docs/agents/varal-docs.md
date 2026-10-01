## Este repositório: varal-docs

Documentação do produto. Não há código.

- `docs/specs/`: specs do MVP (fonte da verdade de todas as regras de produto).
- `docs/agents/`: regras dos agentes. `regras-comuns.md` vale para todos os repositórios; os demais arquivos têm a parte específica de cada um.
- `scripts/build-agents.sh`: monta o `AGENTS.md` de um repositório juntando a parte específica e as regras comuns.

Regras deste repositório:

- Mudança de regra de produto começa aqui, num PR, antes ou junto do PR de código que a implementa.
- Ao mudar `docs/agents/`, regenere o `AGENTS.md` de cada repositório afetado (`scripts/build-agents.sh <repositório>`) e abra um PR em cada um. Nunca edite a parte comum diretamente no `AGENTS.md` de outro repositório.
- A identidade visual está na spec 08; os tokens de cor e tipografia dos apps seguem a tabela de lá.
- Escopos de commit adicionais: `specs`, `agents`, `glossary`.
