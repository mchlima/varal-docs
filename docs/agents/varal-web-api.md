## Este repositório: varal-web-api

API do Varal: NestJS com REST em `/api/v1` e WebSocket (Socket.IO) em `/ws`, PostgreSQL, migrations e o `openapi.json` consumido pelos apps. Specs principais: 01 a 07.

Stack: Node 22, TypeScript estrito, NestJS, PostgreSQL 17, Prisma, zod, pg-boss para filas, nodemailer com SMTP Locaweb.

### Comandos

```sh
pnpm install            # dependências (gera o Prisma Client no postinstall)
pnpm dev                # API em http://localhost:$PORT (3000 + PORT_OFFSET), com recarga
pnpm test               # Vitest; testes de integração rodam quando há DATABASE_URL_TEST
pnpm lint && pnpm format:check && pnpm typecheck
pnpm build && pnpm start
pnpm openapi            # regenera o openapi.json (commite junto com a mudança; a CI compara)
pnpm db:migrate         # cria e aplica migration em desenvolvimento (prisma migrate dev)
pnpm db:deploy          # aplica migrations pendentes (CI e produção)
scripts/worktree.sh new <tipo>/<descricao>   # worktree com porta, .env.local e bancos próprios
scripts/worktree.sh list | remove <nome>
```

- Precisa do Postgres de desenvolvimento do `varal-infra` (`docker compose -f ../varal-infra/dev/compose.yml up -d`).
- Prisma fixo em **7.10.0 exato**: não atualize para o 8 (RC) sem decisão registrada no plano.
- `dev` e `openapi` rodam com `@swc-node/register`, porque o Nest precisa dos metadados de decorators (tsx e esbuild não geram).

### Regras que não podem quebrar

1. **Isolamento entre organizações.** Toda tabela de dados de cliente tem `organization_id`. A organização vem do token, nunca de parâmetro do cliente. Todo recurso novo ganha um teste que prova que a organização A não lê nem altera dados da B.
2. **Auditoria.** Toda ação que cria, altera, cancela ou estorna dado relevante grava em `audit_logs` na mesma transação, com ator, aparelho e, em "entrar como", o admin responsável.
3. **Idempotência.** Escritas operacionais aceitam `Idempotency-Key`; reenviar a mesma requisição nunca duplica pedido, pagamento ou movimento.
4. **Concorrência.** Mudanças de etapa e cancelamentos conferem a `version` do registro e respondem 409 se outro aparelho mudou antes.
5. **Contextos separados.** Sessões do app dos clientes e do admin nunca são aceitas uma no lugar da outra.
6. **Valores copiados no pedido.** O item guarda nome e preço do momento da venda; relatórios nunca leem o preço atual do cardápio.

### Contratos

- Todo PR que muda rota, schema, enum, permissão ou evento em tempo real regenera e commita o `openapi.json` (spec 01, RN-01.09 e RN-01.10). A CI recusa o PR se o arquivo estiver desatualizado.
- Prefira mudanças compatíveis (só adicionar). Mudança incompatível exige PRs coordenados nos apps e `BREAKING CHANGE` no commit.

### Banco e migrations

- No máximo uma migration por PR. Se a `main` ganhou migrations depois que você criou a sua, refaça a sua em cima delas antes do PR.
- Cada worktree usa o próprio banco `varal_<slug>` no Postgres de desenvolvimento do `varal-infra`. Nunca rode migrations ou seeds no banco de outro worktree.

### Ambiente

Porta da API: `3000 + PORT_OFFSET` (spec 01, seção 4.1).

Escopos de commit adicionais: `db`, `openapi`, `deps`.
