## Este repositório: varal-admin-web

Admin da plataforma Varal: Nuxt em modo SPA, usado pela equipe do Varal para organizações, assinatura, comunicados, métricas, "entrar como", e-mails, auditoria, usuários e papéis. Specs principais: 01 (autenticação, rotas), 02 (admin) e 08 (identidade visual).

Stack: Node 22, TypeScript estrito, Nuxt (`ssr: false`), cliente gerado do OpenAPI com openapi-typescript e openapi-fetch.

### Comandos

```sh
pnpm install
pnpm dev                # http://localhost:$PORT (3200 + PORT_OFFSET)
pnpm test               # Vitest + @nuxt/test-utils
pnpm lint && pnpm typecheck
pnpm generate           # build estático em .output/public
pnpm gen:api            # regenera app/api/schema.d.ts a partir de ../varal-web-api/openapi.json (ou OPENAPI_SOURCE)
scripts/worktree.sh new <tipo>/<descricao>   # worktree com porta e .env.local próprios
scripts/worktree.sh list | remove <nome>
```

- A URL da API vem de `NUXT_PUBLIC_API_BASE_URL` e fica fixa no build (app estático).
- Cores só pelos tokens de `app/assets/css/tokens.css`, iguais aos da spec 08. O tema do Nuxt UI (`app.config.ts` e variáveis `--ui-*` em `main.css`) aponta para esses tokens; não use as cores padrão da biblioteca.

### Regras do app

- **Contratos:** tipos, cliente da API e o catálogo de permissões (`Permission`) vêm de `pnpm gen:api`. Nunca edite os arquivos gerados.
- **RBAC:** esconda as ações para as quais o usuário não tem permissão, mas lembre que quem decide é a API; a interface nunca é a única barreira.
- **Contexto separado:** o admin usa a própria sessão; nunca reaproveite cookies ou tokens do app dos clientes. O "entrar como" abre o `varal-panel-web` com a sessão emitida pela API (spec 02, seção 7).
- **Rotas em português,** conforme o mapa da spec 01, seção 14.1.
- **Interface:** siga a spec 08 (cores, tipografia, componentes). O admin é usado em computador e celular; layout com navegação lateral a partir de 1024 px.

### Ambiente

Porta: `3200 + PORT_OFFSET`. `NUXT_PUBLIC_API_BASE_URL` no `.env.local` aponta para a API (padrão: `http://localhost:3000`).

Escopos de commit adicionais: `deps`.
