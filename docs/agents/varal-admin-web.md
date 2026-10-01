## Este repositório: varal-admin-web

Admin da plataforma Varal: Nuxt em modo SPA, usado pela equipe do Varal para organizações, assinatura, comunicados, métricas, "entrar como", e-mails, auditoria, usuários e papéis. Specs principais: 01 (autenticação, rotas), 02 (admin) e 08 (identidade visual).

Stack: Node 22, TypeScript estrito, Nuxt (`ssr: false`), cliente gerado do OpenAPI com openapi-typescript e openapi-fetch **(proposta)**.

### Comandos

Ainda não há código. Quando o projeto for criado, registre aqui os comandos de instalação, desenvolvimento, testes, lint, `gen:api` e build, e mantenha esta seção atualizada.

### Regras do app

- **Contratos:** tipos, cliente da API e o catálogo de permissões (`Permission`) vêm de `pnpm gen:api`. Nunca edite os arquivos gerados.
- **RBAC:** esconda as ações para as quais o usuário não tem permissão, mas lembre que quem decide é a API; a interface nunca é a única barreira.
- **Contexto separado:** o admin usa a própria sessão; nunca reaproveite cookies ou tokens do app dos clientes. O "entrar como" abre o `varal-panel-web` com a sessão emitida pela API (spec 02, seção 7).
- **Rotas em português,** conforme o mapa da spec 01, seção 14.1.
- **Interface:** siga a spec 08 (cores, tipografia, componentes). O admin é usado em computador e celular; layout com navegação lateral a partir de 1024 px.

### Ambiente

Porta: `3200 + PORT_OFFSET`. `API_BASE_URL` no `.env.local` aponta para a API (padrão: `http://localhost:3000`).

Escopos de commit adicionais: `deps`.
