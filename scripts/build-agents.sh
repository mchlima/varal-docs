#!/usr/bin/env bash
# Builds the AGENTS.md of a Varal repository: repo-specific section + common rules.
# Usage: scripts/build-agents.sh <repository> > path/to/AGENTS.md
set -euo pipefail

repo="${1:?usage: scripts/build-agents.sh <repository>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
specific="$root/docs/agents/$repo.md"
common="$root/docs/agents/regras-comuns.md"

if [[ ! -f "$specific" ]]; then
  echo "error: $specific not found" >&2
  exit 1
fi

cat <<HEADER
# AGENTS.md

Instruções para agentes de código (Claude Code, Codex, Cursor e similares) que trabalham no \`$repo\`.

> Arquivo gerado a partir do [varal-docs](https://github.com/mchlima/varal-docs/tree/main/docs/agents) (\`docs/agents/$repo.md\` + \`docs/agents/regras-comuns.md\`). Não edite aqui: mude no varal-docs e regenere com \`scripts/build-agents.sh $repo\`.

HEADER
cat "$specific"
echo
cat "$common"
