## Este repositório: varal-panel-web

App dos clientes do Varal: Nuxt em modo SPA, instalável como PWA. Telas de balcão, estações (cozinha, balcão de entrega), caixa, fiado e o painel do dono. Specs principais: 01 (autenticação, fila offline, rotas), 03 a 07 (telas) e 08 (identidade visual).

Stack: Node 22, TypeScript estrito, Nuxt (`ssr: false`), PWA, cliente gerado do OpenAPI com openapi-typescript e openapi-fetch, Socket.IO client.

### Comandos

```sh
pnpm install
pnpm dev                # http://localhost:$PORT (3100 + PORT_OFFSET)
pnpm test               # Vitest + @nuxt/test-utils
pnpm lint && pnpm typecheck
pnpm generate           # build estático em .output/public
pnpm gen:api            # regenera app/api/schema.d.ts a partir de ../varal-web-api/openapi.json (ou OPENAPI_SOURCE)
scripts/worktree.sh new <tipo>/<descricao>   # worktree com porta e .env.local próprios
scripts/worktree.sh list | remove <nome>
```

- A URL da API vem de `NUXT_PUBLIC_API_BASE_URL` e fica fixa no build (app estático).
- Cores só pelos tokens de `app/assets/css/tokens.css`, iguais aos da spec 08. A paleta padrão do Tailwind está desligada.

### Regras do app

- **Contratos:** tipos e cliente da API vêm de `pnpm gen:api`, a partir do `openapi.json` do `varal-web-api`. Nunca edite os arquivos gerados nem redefina enums ou eventos à mão.
- **Tempo real não é fonte de verdade.** Ao reconectar o WebSocket, recarregue o estado por REST (varal de comandas, fila da estação) antes de voltar a aplicar eventos; ignore eventos com `version` menor que a que já tem.
- **Fila offline:** ações operacionais que não conseguiram ser enviadas ficam no IndexedDB com a sua `Idempotency-Key` gerada no momento da ação e são reenviadas em ordem quando a conexão volta (spec 01, seção 11).
- **Rotas em português,** conforme o mapa da spec 01, seção 14.1.
- **Interface (spec 08):** tema claro para uso no sol, cor primária Framboesa `#BE185D`, uma única ação principal por tela de operação, status sempre com texto e ícone, alvos de toque de no mínimo 48 px e botões principais com 52 px. Celular primeiro. Sem degradês, sombras pesadas ou emojis como ícones.
- **Estações:** tela sempre ligada (Wake Lock) com tratamento de recusa; som de alerta só depois de uma interação do usuário; vibração e destaque visual em item novo.

### Ambiente

Porta: `3100 + PORT_OFFSET`. `NUXT_PUBLIC_API_BASE_URL` no `.env.local` aponta para a API (padrão: a do checkout principal, `http://localhost:3000`).

Escopos de commit adicionais: `pwa`, `offline`, `deps`.
