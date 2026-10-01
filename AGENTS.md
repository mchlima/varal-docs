# AGENTS.md

Instruções para agentes de código (Claude Code, Codex, Cursor e similares) que trabalham neste repositório.

## O projeto

Varal é um SaaS de assinatura mensal para barracas de feirinha (espetos, pastéis, tapiocas). Cada colaborador usa o próprio celular como estação de trabalho: o balcão registra o pedido e ele cai direto na tela da cozinha, em tempo real. O sistema cobre comandas, pagamentos registrados, caixa, fiado e relatórios, além de um admin para a equipe do Varal.

Situação atual: specs escritas, código ainda não iniciado. Piloto: um vendedor de espetos de churrasco.

## Specs: a fonte da verdade

- Todas as regras estão em [`docs/specs/`](docs/specs/README.md). Leia o README (convenções e glossário) e a spec do módulo antes de implementar qualquer coisa.
- Regras de negócio têm id `RN-XX.YY` e critérios de aceite `CA-XX.YY`. Cite os ids nos testes, nos comentários que explicam uma regra e nas mensagens de commit.
- Cada critério de aceite implementado tem pelo menos um teste automatizado.
- Itens marcados **(proposta)** ainda não foram confirmados pelo dono do projeto. Não trate como decisão definitiva; se a implementação depender de um deles, pergunte.
- Se o comportamento implementado precisar divergir da spec, atualize a spec no mesmo commit e explique o motivo. Nunca deixe código e spec contando histórias diferentes.
- Não use frameworks de planejamento externos (como GSD) neste projeto. Planos e specs são arquivos markdown em `docs/`.

## Arquitetura

Monorepo com pnpm workspaces:

```
apps/api       NestJS — API REST (/api/v1) e WebSocket (/ws)
apps/web       Nuxt (SPA + PWA) — balcão, estações, caixa, painel do dono
apps/admin     Nuxt (SPA) — admin da plataforma
packages/shared  tipos, enums de estado, schemas de validação, contratos de eventos
infra/         docker compose, nginx, backup
docs/specs/    specs do MVP
```

Infraestrutura: VPS próprio com Docker, NGINX e PostgreSQL. E-mail via SMTP Locaweb (limite de 10.000 envios por mês). Domínio provisório: kratinho.com.br.

## Comandos

Ainda não há código. Quando o monorepo for criado, registre aqui os comandos de instalação, desenvolvimento, testes, lint, migrations e build, e mantenha esta seção atualizada.

## Convenções de código

- **Idioma:**
  - **Inglês** em toda a codebase: variáveis, funções, classes, componentes, arquivos, tabelas e colunas, rotas da API (`/api/v1/tabs`), eventos, enums e chaves de permissão. Use os nomes do glossário em `docs/specs/README.md` (ex.: comanda = `Tab`, turno = `Shift`, fiado = `on_credit`).
  - **Português do Brasil** em tudo que o usuário vê: textos da interface, mensagens de erro exibidas e **rotas do front** (`/balcao`, `/painel/cardapio`). Specs e mensagens de commit também em português.
  - No Nuxt, os arquivos em `pages/` seguem o nome da rota em português (`pages/balcao.vue`), por ser o roteamento por arquivo. É a única exceção ao inglês; componentes, composables e stores continuam em inglês.
- **TypeScript estrito** em todos os pacotes. Sem `any` sem justificativa.
- **Fonte única de contratos:** enums de estado, schemas de entrada e payloads de eventos ficam em `packages/shared`. Nunca duplique um enum ou formato de evento em `api` ou nos apps.
- **Dinheiro:** sempre inteiro em centavos, colunas e campos com sufixo `_cents` / `Cents`. Nunca `float` ou `decimal` em JavaScript.
- **Datas:** `timestamptz` em UTC no banco; exibição em `America/Sao_Paulo`.
- **IDs:** UUID v7.
- **Nada operacional é apagado:** comandas, pedidos, itens, pagamentos e movimentos de caixa são cancelados ou estornados, nunca removidos. Cadastros são desativados.
- **Valores copiados no pedido:** o item guarda nome e preço do momento da venda; relatórios nunca leem o preço atual do cardápio.

## Regras que não podem quebrar

1. **Isolamento entre organizações.** Toda tabela de dados de cliente tem `organization_id`. A organização vem do token, nunca de parâmetro do cliente. Todo recurso novo ganha um teste que prova que a organização A não lê nem altera dados da B.
2. **Auditoria.** Toda ação que cria, altera, cancela ou estorna dado relevante grava em `audit_logs` na mesma transação, com ator, aparelho e, em "entrar como", o admin responsável.
3. **Idempotência.** Escritas operacionais aceitam `Idempotency-Key`; reenviar a mesma requisição nunca duplica pedido, pagamento ou movimento.
4. **Concorrência.** Mudanças de etapa e cancelamentos conferem a `version` do registro e respondem 409 se outro aparelho mudou antes.
5. **Tempo real não é fonte de verdade.** Ao reconectar, o app sempre recarrega o estado por REST; eventos perdidos nunca são necessários.
6. **Contextos separados.** Sessões do app `web` e do `admin` nunca são aceitas uma no lugar da outra.
7. **Segredos** só em variáveis de ambiente. Nunca commitar `.env`, credenciais de SMTP ou chaves.

## Interface

Siga [`docs/specs/08-identidade-visual.md`](docs/specs/08-identidade-visual.md):

- Tema claro, pensado para uso no sol. Cor primária Framboesa `#BE185D`.
- Uma única ação principal (botão preenchido) por tela de operação.
- Status sempre com texto e ícone, nunca só cor.
- Alvos de toque de no mínimo 48 px; botões principais com 52 px de altura.
- Celular primeiro. Nada de visual genérico de template: sem degradês, sombras pesadas ou emojis como ícones.

## Vários agentes ao mesmo tempo

Este repositório é trabalhado por vários agentes em paralelo. Para que um não atrapalhe o outro:

### Uma branch por assunto, um agente por branch

- Cada agente desenvolve na **branch do assunto em que está trabalhando** (ex.: `feat/fechamento-de-caixa`), nunca na `main` e nunca na branch de outro agente.
- Uma branch trata de **um único assunto**. Se aparecer algo de outro assunto no meio do trabalho (um bug em outro módulo, uma melhoria não relacionada), anote para o usuário ou abra outra branch; não misture no mesmo PR.
- Assuntos diferentes = branches diferentes, mesmo que o mesmo agente trabalhe em ambos.

### Cada agente no seu worktree

- **O checkout principal (a raiz do repositório) fica sempre na `main`, limpo.** Ninguém edita arquivos nem troca de branch nele; ele só serve de base.
- Cada tarefa roda num **git worktree próprio**, dentro de `.worktrees/` (ignorada pelo git), com a sua branch:
  ```
  git fetch origin && git worktree add .worktrees/<tipo>-<descricao> -b <tipo>/<descricao> origin/main
  ```
  Sem remoto configurado, use `main` no lugar de `origin/main`.
- Trabalhe, rode comandos e faça commits **somente dentro do seu worktree**. Nunca edite arquivos de outro worktree nem da raiz.
- Ao terminar (PR aberto e aceito, ou tarefa abandonada), remova o worktree: `git worktree remove .worktrees/<nome>`.

### Antes de começar

- Rode `git worktree list` para ver as branches em andamento. Não pegue uma tarefa ou módulo que já tenha branch aberta; se precisar mexer no mesmo módulo, combine com o usuário.
- Prefira tarefas pequenas e de um módulo só. PRs pequenos reduzem conflito.

### Comandos proibidos fora do seu worktree

Estes comandos afetam o trabalho de outros agentes e só podem ser usados dentro do seu próprio worktree, e nunca na raiz:
`git switch`/`git checkout` de branch, `git stash`, `git reset --hard`, `git clean`, `git rebase`, `git restore` em massa, `rm -rf` em pastas do projeto.

Também é proibido: apagar ou mover worktrees de outros, apagar branches que não são suas, `git push --force` em branch que não é sua, e alterar a configuração global do git.

### Pontos de conflito conhecidos

- **`packages/shared`** (enums, schemas, eventos) e **o schema do banco** são compartilhados por todos os módulos. Mantenha mudanças pequenas e atualize sua branch com a `main` (`git rebase origin/main`, dentro do seu worktree) antes de abrir o PR.
- **Migrations:** no máximo uma migration por PR. Se a `main` ganhou migrations depois que você criou a sua, refaça a sua em cima delas antes do PR.
- **`pnpm-lock.yaml`:** em conflito, não edite à mão; resolva o `package.json` e rode `pnpm install` para regenerar.
- **Specs:** se duas tarefas precisarem mudar a mesma spec, a segunda espera a primeira entrar na `main`.

### Ambiente isolado por worktree

Cada worktree roda o próprio ambiente de desenvolvimento sem disputar portas nem banco com os outros (detalhes na spec 01, seção 4.1):

- portas próprias (API, web, admin) definidas no `.env.local` do worktree;
- banco de dados próprio no Postgres de desenvolvimento compartilhado;
- nome de projeto do Docker Compose próprio.

Nunca rode migrations, seeds ou `docker compose down -v` apontando para o banco ou o projeto de outro worktree.

## Commits e branches

### Fluxo de branches

- **Nada vai direto para a `main`.** Nem commit, nem push, nem merge local. Toda mudança nasce numa branch de trabalho e entra na `main` por pull request.
- Antes de começar qualquer mudança, crie a branch a partir da `main` atualizada: `git switch main && git pull && git switch -c <tipo>/<descricao-curta>`.
- **Nome da branch:** `<tipo>/<descricao-curta>`, com o mesmo `tipo` do Conventional Commits e descrição em minúsculas com hífens. Ex.: `feat/reabrir-comanda`, `fix/troco-em-dinheiro`, `docs/spec-fiado`.
- O PR vai da branch de trabalho para a `main`, com título no formato Conventional Commits e descrição com o que mudou, as regras e critérios de aceite cobertos (`RN-XX.YY`, `CA-XX.YY`) e como testar.
- Se estiver na `main` com alterações por fazer commit, crie a branch antes de commitar (`git switch -c ...` leva as alterações junto).
- Não faça push nem abra PR sem pedido explícito.

### Mensagens de commit

Todo commit segue o [Conventional Commits 1.0.0](https://www.conventionalcommits.org/pt-br/v1.0.0/):

```
<tipo>(<escopo opcional>): <descrição>

<corpo opcional>

<rodapés opcionais>
```

- **Tipos:** `feat` (funcionalidade), `fix` (correção), `docs` (documentação e specs), `refactor`, `test`, `perf`, `style` (formatação, sem mudar comportamento), `build` (dependências, empacotamento), `ci`, `chore` (manutenção).
- **Escopo:** o app ou módulo afetado, em inglês e minúsculas: `api`, `web`, `admin`, `shared`, `infra`, ou o módulo (`auth`, `tabs`, `shifts`, `cash`, `credit`, `reports`, `menu`, `staff`, `rbac`).
- **Descrição:** em português, no imperativo, minúscula no início, sem ponto final, até cerca de 72 caracteres. Cite a regra quando houver: `feat(tabs): permite reabrir comanda em fechamento (RN-04.12)`.
- **Mudança incompatível:** `!` depois do tipo/escopo e rodapé `BREAKING CHANGE: <explicação>`.
- Um commit por mudança coerente; specs alteradas junto com o código que as afeta.

