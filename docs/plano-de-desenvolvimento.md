# Plano de desenvolvimento do MVP

Como construir o MVP descrito nas [specs](specs/README.md): versões e escolhas técnicas, fases, entregas por repositório e como os agentes trabalham em paralelo. Pesquisa feita em 2026-10-01 nas documentações, changelogs e no npm. As specs prevalecem sobre este plano; quando uma escolha daqui virar regra, ela vai para a spec.

## 1. Versões de referência

Versões estáveis em 2026-10-01. Fixe a versão maior (`^`) no `package.json`, exceto onde indicado.

| Camada | Pacote | Versão |
| --- | --- | --- |
| Runtime | Node | 22 LTS (22.12 ou mais nova) |
| Runtime | pnpm | 10 |
| API | NestJS (`@nestjs/*`) | 12.1 |
| API | `@nestjs/swagger` | 12.0 |
| API | Prisma (`prisma`, `@prisma/client`, `@prisma/adapter-pg`) | **7.10.0 exato** |
| API | zod | 4.6 |
| API | pg-boss | 12.35 |
| API | socket.io | 4.8 |
| API | `@node-rs/argon2` | 2.2 |
| API | nodemailer | atual |
| Apps | Nuxt | 4.5 |
| Apps | Tailwind CSS | 4.3 |
| Apps | Reka UI (painel) / Nuxt UI (admin) | 2.10 / 4.11 |
| Apps | `@vite-pwa/nuxt` | 1.1 |
| Apps | Dexie | 4.4 |
| Apps | openapi-typescript / openapi-fetch | 7.13 / 0.17 |
| Apps | Pinia / VueUse | 4.0 / atual |
| Apps | socket.io-client | 4.8 |
| Testes | Vitest / `@nuxt/test-utils` / Playwright | 5.0 / 4.3 / 1.63 |
| Qualidade | ESLint (flat config) + typescript-eslint / Prettier | 10 + 8 / 3 |

> **Atenção:** no npm, a tag `latest` do CLI `prisma` aponta para o 8.0.0-rc, que ainda não é estável e muda bastante coisa. Instale `prisma@7.10.0` e `@prisma/client@7.10.0` com versão exata.

## 2. Escolhas técnicas

### 2.1 API (`varal-web-api`)

- **NestJS 12 em ESM, com Express 5.** Cookies com `cookie-parser`. Fastify só se um dia houver gargalo.
- **Validação com zod 4 pela validação nativa do Nest 12** (Standard Schema: `@Body({ schema })` e `StandardSchemaValidationPipe` global). O pacote `nestjs-zod` ainda não suporta o Nest 12 e não será usado.
- **OpenAPI 3.1** gerado pelo `@nestjs/swagger` 12 a partir dos schemas zod. Enums e eventos do WebSocket (RN-01.10) são registrados com `.meta({ id })`, convertidos com `z.toJSONSchema` e mesclados em `components.schemas`. Um script `pnpm openapi` grava o `openapi.json`; a CI falha se o arquivo commitado estiver diferente (CA-01.11).
- **Prisma 7:** generator `prisma-client` com saída em `src/generated/prisma` (fora do git), driver adapter `@prisma/adapter-pg`, URL do banco no `prisma.config.ts`. `migrate dev` só na máquina; `migrate deploy` na CI de testes e no deploy.
- **UUID v7** com `@default(uuid(7))`: o id é gerado pela aplicação, porque o PostgreSQL 17 ainda não tem `uuidv7()`. Inserções feitas fora do Prisma geram o id no código.
- **Multi-tenant (spec 01, seção 6):** uma client extension do Prisma aplica `organization_id` a partir do contexto da requisição (AsyncLocalStorage), mais o teste automatizado do CA-01.02 cobrindo todos os endpoints. A extension não cobre `$queryRaw`: consultas cruas recebem o filtro à mão e revisão no PR. Row-Level Security no Postgres fica como reforço para depois do piloto (ver seção 6).
- **Conexões:** o Postgres compartilhado aceita 50. O Varal usa no máximo 10: pool da API com 7 e pg-boss com `max: 3`. Testes limitam workers e pool para caber no Postgres de desenvolvimento.
- **pg-boss 12:** um `PgBossService` inicia e para junto com a aplicação. Filas criadas com `createQueue` no boot. O e-mail é enfileirado na mesma transação da ação que o gera (`db` do pg-boss com a transação do Prisma). Até 3 tentativas com espera crescente (`retryLimit: 3`, `retryBackoff: true`).
- **Senhas:** `@node-rs/argon2`, argon2id com `memoryCost 19456`, `timeCost 2`, `parallelism 1` (mínimo da OWASP). Hash refeito no login quando os parâmetros mudarem.
- **Socket.IO** em `/ws`: autenticação por cookie num middleware do servidor; salas por organização, unidade e estação; CORS com a lista exata de origens (RN-01.20). Ao renovar o token, o cliente reconecta; o servidor desconecta sockets com token vencido. Os intervalos padrão (ping a cada 25 s) passam pelo limite de 100 s do Cloudflare.
- **Testes:** Vitest 5 com `unplugin-swc` (sem ele a injeção de dependências do Nest quebra). Integração contra Postgres real, com o banco de teste do worktree (RN-01.06).
- **Qualidade:** ESLint 10 com regras que usam tipos (`no-floating-promises`, `no-misused-promises`) e Prettier.

### 2.2 Apps (`varal-panel-web` e `varal-admin-web`)

- **Nuxt 4** com `ssr: false` e `nuxi generate`; código em `app/`. Saída estática servida pelo NGINX (já configurado).
- **URL da API definida no build.** Em app estático, `runtimeConfig` fica fixo no build; cada ambiente tem o próprio build (produção aponta para `https://api-web-varal.kratinho.com.br`).
- **Cliente da API:** `pnpm gen:api` gera os tipos com openapi-typescript; um plugin cria o cliente openapi-fetch com `credentials: 'include'`. Um middleware renova a sessão em 401 com uma única renovação compartilhada entre requisições simultâneas (sem passar pelo próprio middleware, para não entrar em loop).
- **Componentes:**
  - **Painel:** Tailwind 4 + Reka UI (só primitivas acessíveis: diálogo, aviso, seleção) e componentes próprios. Botões de 56 a 64 px, texto grande, alto contraste, sem visual genérico.
  - **Admin:** Nuxt UI 4, que traz tabelas, formulários e modais prontos. A identidade visual tem de ser equivalente à do painel (decisão de 2026-10-01): mesmos tokens de cor, status, tipografia e logo da spec 08, aplicados pelo tema do Nuxt UI (`app.config` e variáveis `--ui-*`), sem o visual padrão da biblioteca. O `@nuxt/fonts` e o modo de cor automático ficam desligados.
- **Logo e ícones:** copiados de `varal-docs/docs/brand/` (spec 08, RN-08.01).
- **Estado:** Pinia para sessão, unidade atual e fila; VueUse para rede, armazenamento e tela sempre acesa na cozinha (`useWakeLock`). Sem i18n: textos em pt-BR num módulo próprio e `Intl` para moeda e data.

### 2.3 PWA e fila offline (`varal-panel-web`, spec 01, seção 11)

- **@vite-pwa/nuxt** com precache do app e `registerType: 'prompt'`: a versão nova só é aplicada quando o usuário aceita e a fila está vazia, nunca no meio de um pedido.
- O service worker não faz cache da API. Os dados offline ficam na fila do app.
- **Fila em IndexedDB com Dexie.** Cada ação guarda a requisição e uma `Idempotency-Key`. Um único processador envia em ordem, com espera crescente, quando a rede volta, quando o app volta ao primeiro plano e quando o socket reconecta. `navigator.locks` impede duas abas de processar ao mesmo tempo. Erro 4xx (exceto 408 e 429) vira falha definitiva, mostrada na tela.
- Background Sync só existe em navegadores Chromium; é bônus, não base.
- **iOS:** não há convite de instalação, e o Safari apaga dados de sites não instalados após 7 dias sem uso. O app explica como instalar (Compartilhar → Adicionar à Tela de Início) e pede armazenamento persistente.
- Ao reconectar o socket, o app recarrega o estado pela API (eventos perdidos não são reenviados) e dispara a fila.

### 2.4 CI, versões e deploy

- **GitHub Actions** (plano free: 2.000 minutos por mês). Em cada repositório de código: lint, tipos, testes e build em todo PR e na `main`; cancelamento de execuções antigas da mesma branch; cache do pnpm; documentação não dispara a CI. Artefatos guardados por 1 a 3 dias.
- **Título do PR** checado por action (Conventional Commits). No plano free o check não bloqueia o merge; serve de aviso.
- **Versões:** release-please em cada repositório de código. Ele mantém um PR de release com versão e changelog; o merge desse PR cria a tag, e a tag dispara o deploy. Assim todo deploy passa por um merge explícito.
- **Imagem da API** no GitHub Container Registry, construída em várias etapas sobre `node:22-alpine` (o Prisma 7 não depende mais do motor em Rust). Tags `sha-<curto>` e `vX.Y.Z`; produção sempre fixa a versão.
- **Deploy (a decidir antes da fase 2).** Proposta: GitHub Actions via SSH, com um usuário `deploy` no VPS cuja chave só pode rodar o script de deploy do `varal-infra`. O script é o mesmo se o deploy for disparado à mão:
  - **API:** `deploy.sh api vX.Y.Z` baixa a imagem, roda `prisma migrate deploy` num container temporário e só então troca o container `varal-api`. Migrations seguem o padrão expandir e depois contrair, para a versão anterior continuar funcionando durante a troca.
  - **Apps:** o build vai por rsync para `/opt/nginx/html/<app>/releases/<versão>`, e um link `current` troca de versão de uma vez. Voltar versão é trocar o link.
  - **Segredos:** os de deploy ficam nos secrets do GitHub; os da aplicação ficam num `.env` no VPS (permissão 600), fora do git.
- **Dependências:** Dependabot, ligado no fim da fase 0, com atualizações agrupadas num PR semanal por repositório (npm, Docker e GitHub Actions).

## 3. Fases

Cada fase lista o que entra em cada repositório. Uma fase só termina com os critérios de aceite (CA) citados passando. Dentro da fase, a API vai primeiro e os apps seguem o contrato publicado no `openapi.json`. Mudanças compatíveis permitem trabalho em paralelo.

### Fase 0 — Esqueleto e ferramentas

Base de todos os repositórios, sem regra de negócio.

| Repositório | Entregas |
| --- | --- |
| `varal-infra` | `dev/compose.yml` com o Postgres de desenvolvimento (`varal-dev-db`, `postgres:17`) |
| `varal-web-api` | NestJS 12, TypeScript estrito, ESLint e Prettier, Vitest com SWC, Prisma 7 configurado, endpoint de saúde, `openapi.json` gerado, `.env.example`, `scripts/worktree.sh` (RN-01.06 a 01.08), CI |
| `varal-panel-web` | Nuxt 4 SPA, Tailwind 4, tokens e fontes da spec 08, logo e favicon, `pnpm gen:api`, `scripts/worktree.sh`, CI |
| `varal-admin-web` | O mesmo, com Nuxt UI 4 |
| Todos | Action de título de PR, release-please; Dependabot semanal e agrupado, ligado por último |

Critério: CA-01.01 (cada worktree sobe o projeto rodando). O seed da API vem na fase 1.

### Fase 1 — Fundação da API (spec 01)

- Modelo base: organizações, unidades, donos, colaboradores, admins da plataforma, sessões, aparelhos, auditoria, e-mails.
- Contexto da requisição e filtro por organização.
- Login dos três perfis, sessão com renovação, redefinição de senha e convite.
- Idempotência, controle de versão (409), auditoria, envio de e-mail pela fila, gateway de tempo real com salas.
- Seed de exemplo.

Critérios: CA-01.01 a 01.06, 01.08, 01.09 e 01.11.

### Fase 2 — Base dos apps e primeiro deploy

- **Apps:** layout, telas de login (dono, colaborador por `/e/{code}`, admin), redefinição de senha, sessão com renovação, tratamento de erros.
- **Painel:** PWA instalável, fila offline e cliente de tempo real.
- **Infraestrutura:**
  - Compose de produção com `varal-api`;
  - banco e usuário `varal` (RN-01.16);
  - script de deploy e workflow de imagem;
  - forma de disparar o deploy (seção 6).
- **Primeiro deploy** com a página provisória substituída pelos apps reais. Fazer isso cedo tira o risco do fim do projeto.

Critérios: CA-01.07, 01.12, 01.13, 01.14 e 01.15.

### Fase 3 — Admin da plataforma (spec 02)

RBAC, organizações (o admin cria a organização do piloto), assinatura registrada à mão, comunicados, métricas e "entrar como".

Critérios: CA-02.

### Fase 4 — Configuração da unidade (spec 03)

Unidades, estações, fluxo de etapas com template padrão, cardápio com modificadores, colaboradores e permissões, código de acesso e QR.

Critérios: CA-03.

### Fase 5 — Turno, comandas e estações (spec 04)

O coração do produto:
- abertura e fechamento de turno, acordo e preços do turno;
- comandas abertas e pagas antes;
- pedidos e avanço de etapa, incluindo avançar parte da quantidade;
- telas de balcão e estações em tempo real, com a fila offline em uso real.

Critérios: CA-04.

### Fase 6 — Fechamento, caixa e fiado (specs 05 e 06)

Descontos, pagamentos, estorno, caixas, sangria e suprimento, conferência, pendurar e quitar.

Critérios: CA-05 e CA-06.

### Fase 7 — Relatórios (spec 07)

Relatório do turno e histórico.

Critérios: CA-07.

### Fase 8 — Piloto

- Teste de ponta a ponta nos aparelhos reais do piloto (Android e iPhone, sol, rede ruim).
- Ensaio de um turno completo.
- Ajustes de usabilidade, observação dos relatórios de DMARC e acompanhamento do primeiro turno real.

### Paralelismo

```
Fase 0 ─► Fase 1 ─► Fase 2 ─┬─► Fase 4 ─► Fase 5 ─► Fase 6 ─► Fase 7 ─► Fase 8
                            └─► Fase 3 (em paralelo a partir da 4)
```

- Fases 0 e 2: cada repositório avança em paralelo, um agente por repositório.
- A partir da fase 3: um agente na API e um em cada app por fase. O app começa assim que o PR da API com o contrato estiver mergeado.
- O admin (fase 3) corre em paralelo com as fases 4 e 5, porque só depende da fundação.

## 4. Como cada entrega é feita

1. Branch de trabalho num worktree próprio, com o mesmo nome em todos os repositórios afetados (regras comuns dos agentes).
2. Na API: migration, código, testes citando as regras (`RN-xx.yy`) e critérios (`CA-xx.yy`), `openapi.json` atualizado.
3. Nos apps: `pnpm gen:api`, telas, testes de componente e, nos fluxos principais, Playwright (Android e iPhone emulados, com teste sem rede).
4. PR com título no padrão Conventional Commits; merge com squash na ordem docs → api → apps → infra.

## 5. Riscos e cuidados

| Risco | Cuidado |
| --- | --- |
| Instalar o Prisma 8 RC sem querer | Versão exata 7.10.0 nos dois pacotes |
| Vazamento entre organizações | Extension de tenant, teste do CA-01.02 em todos os endpoints, revisão de toda consulta crua |
| Estourar as 50 conexões compartilhadas | Pool de 7 na API e 3 no pg-boss; testes com poucos workers |
| Atualização do app no meio de um pedido | Service worker em modo `prompt`, aplicado só com a fila vazia |
| iOS apagando a fila offline | Exigir instalação do PWA e pedir armazenamento persistente |
| Eventos perdidos na reconexão | Recarregar o estado pela API ao reconectar |
| Renovação de sessão em loop ou em corrida | Uma única renovação compartilhada; a rota de renovação não passa pelo middleware |
| Chave de deploy com acesso amplo ao VPS | Usuário `deploy` limitado ao script de deploy |
| PR fora do padrão no plano free | Action de título como aviso e regra dos agentes |
| Migration destrutiva sem backup | Padrão expandir/contrair; `pg_dump` manual antes de migrations destrutivas, enquanto não houver backup |
| Minutos de CI no plano free | Cache, cancelamento de execuções antigas, CI só para código, Dependabot agrupado e semanal |

## 6. Para decidir

Pontos com recomendação. Até a confirmação, valem as recomendações.

Decididos em 2026-10-01:

- **Componentes do admin:** Nuxt UI 4, com identidade visual equivalente à do painel (seção 2.2).
- **Row-Level Security** no Postgres como segunda camada do multi-tenant: depois do piloto.
- **Atualização de dependências:** Dependabot, agrupado e semanal, a partir do fim da fase 0.

Pendente:

1. **Deploy:** pelo GitHub Actions com usuário `deploy` restrito ou por script rodado à mão. Decidir antes da fase 2.
