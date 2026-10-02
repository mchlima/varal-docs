# Plano de desenvolvimento do MVP

Como construir o MVP descrito nas [specs](specs/README.md): versões e escolhas técnicas, fases, entregas por repositório e como os agentes trabalham em paralelo. Pesquisa feita em 2026-10-01 nas documentações, changelogs e no npm. As specs prevalecem sobre este plano; quando uma escolha daqui virar regra, ela vai para a spec.

## 1. Versões de referência

Versões estáveis em 2026-10-01. Fixe a versão maior (`^`) no `package.json`, exceto onde indicado.

| Camada | Pacote | Versão |
| --- | --- | --- |
| Runtime | Node | 26 (26.10 ou mais nova; LTS a partir de 28/10/2026), fixado em `.nvmrc` |
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

### 1.1 Node 26

Escolhido em 2026-10-01 no lugar do Node 22, para aproveitar as novidades. Lançado em 05/05/2026, vira LTS em 28/10/2026 e tem suporte até 30/04/2029. Todas as dependências do projeto aceitam o 26, e a fase 0 foi verificada nele (testes, builds e imagem Docker).

**O que muda na prática:**

- **Sem corepack.** O Node 25+ não traz mais o corepack. Instale o pnpm com `npm install -g pnpm@10`. Na imagem Docker, o pnpm é instalado na versão do campo `packageManager`. Na CI, o `pnpm/action-setup` já cuida disso.
- **TypeScript direto no Node (type stripping) não serve para a API.** Não suporta decorators nem gera os metadados de que o Nest precisa. A API continua compilada (tsc em produção, SWC em desenvolvimento e testes). Scripts soltos sem decorators, como seed e utilitários, podem rodar `.ts` direto.

**Adotar:**

| Recurso | Estado | Uso no Varal |
| --- | --- | --- |
| `Temporal` (global, sem flag) | Novo no 26 | Datas do domínio em `America/Sao_Paulo`: dia do turno, "hoje", horários de relatório (spec 07), atraso de itens. Prisma, `pg` e zod continuam com `Date`; a conversão fica nas bordas (repositórios e DTOs). Só calendário ISO. |
| `AsyncLocalStorage` (sobre AsyncContextFrame) | Estável, mais rápido | Contexto da requisição: organização, ator, aparelho e id de correlação (spec 01, seção 6) |
| `using` / `await using` | Estável | Liberar recursos com garantia: locks, conexões avulsas, recursos de teste |
| `process.loadEnvFile` / `--env-file-if-exists` | Estável | Carregar `.env.local` sem o pacote dotenv |
| `node --run`, `--watch` | Estável | Scripts e recarga em desenvolvimento |
| `WebSocket` global | Estável | Cliente de tempo real em testes da API (o app continua com o Socket.IO) |
| `Promise.try`, `Error.isError`, `RegExp.escape`, iterator helpers, `Map.prototype.getOrInsert` | Estável | Código mais simples onde couber |

**Evitar por enquanto:**

- `URLPattern`: ainda experimental.
- Permission model (`--permission`) em produção: ainda não testado com Prisma, pg-boss e Socket.IO.
- `node:sqlite`, `node:ffi` e VFS: sem uso no projeto.

**Cuidados:**

- Algumas tags antigas de `node:26-alpine` saíram sem `Temporal`; a 26.10 tem. Quando o código passar a usar `Temporal`, um teste confere que ele existe.
- O 26 removeu APIs legadas (`_stream_*`, `writeHeader`) e passou a desaconselhar `module.register()`. Dependência que quebrar por isso é atualizada ou trocada.
- Fontes: [Node 26.0.0](https://nodejs.org/en/blog/release/v26.0.0), [Node 26.10.0](https://nodejs.org/en/blog/release/v26.10.0), [calendário de releases](https://github.com/nodejs/Release).

## 2. Escolhas técnicas

### 2.1 API (`varal-web-api`)

- **NestJS 12 em ESM, com Express 5.** Cookies com `cookie-parser`. Fastify só se um dia houver gargalo.
- **Validação com zod 4 pela validação nativa do Nest 12** (Standard Schema: `@Body({ schema })` e `StandardSchemaValidationPipe` global). O pacote `nestjs-zod` ainda não suporta o Nest 12 e não será usado.
- **OpenAPI 3.1** gerado pelo `@nestjs/swagger` 12 a partir dos schemas zod. Enums e eventos do WebSocket (RN-01.10) são registrados com `.meta({ id })`, convertidos com `z.toJSONSchema` e mesclados em `components.schemas`. Um script `pnpm openapi` grava o `openapi.json`; a CI falha se o arquivo commitado estiver diferente (CA-01.11).
- **Prisma 7:** generator `prisma-client` com saída em `src/generated/prisma` (fora do git), driver adapter `@prisma/adapter-pg`, URL do banco no `prisma.config.ts`. `migrate dev` só na máquina; `migrate deploy` na CI de testes e no deploy.
- **UUID v7** com `@default(uuid(7))`: o id é gerado pela aplicação, porque o PostgreSQL 17 ainda não tem `uuidv7()`. Inserções feitas fora do Prisma geram o id no código.
- **Multi-tenant (spec 01, seção 6):** uma client extension do Prisma aplica `organization_id` a partir do contexto da requisição (AsyncLocalStorage), mais o teste automatizado do CA-01.02 cobrindo todos os endpoints. A extension não cobre `$queryRaw`: consultas cruas recebem o filtro à mão e revisão no PR. Row-Level Security no Postgres fica como reforço para depois do piloto (ver seção 6).
- **Conexões:** o Postgres compartilhado aceita 50. O Varal usa no máximo 10: pool da API com 7 e pg-boss com `max: 3`. Testes limitam workers e pool para caber no Postgres de desenvolvimento.
- **pg-boss 12:** um `PgBossService` inicia e para junto com a aplicação. Filas criadas com `createQueue` no boot. O e-mail é enfileirado na mesma transação da ação que o gera (`db` do pg-boss com a transação do Prisma). Até 3 tentativas com espera crescente (`retryLimit: 2`, ou seja, 3 tentativas no total, com `retryBackoff: true`).
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
- **Imagem da API:** construída pela CI em várias etapas sobre `node:26-alpine` (o Prisma 7 não depende mais do motor em Rust), com a tag da versão (`vX.Y.Z`). Não passa por registro de imagens: a CI envia a imagem direto ao VPS (`docker save | gzip | ssh`), o que dispensa guardar no VPS um token de leitura do GitHub. O VPS guarda as 3 versões mais recentes.
- **Deploy pelo GitHub Actions** (decidido em 2026-10-01). O merge do PR de release do release-please cria a tag, e o mesmo workflow publica a versão (o GitHub não dispara outros workflows a partir de tags criadas pelo próprio Actions). Também dá para disparar à mão (Actions → deploy) para repetir ou voltar uma versão. Detalhes em `varal-infra/prod/README.md`.
  - **Usuário `deploy` no VPS:** a chave dele só roda o `deploy-gate` (forced command com `restrict`: sem shell, sem túnel), que aceita `api`, `app` e `status`.
  - **API:** `deploy-api` carrega a imagem, roda `prisma migrate deploy` num container temporário e só então troca o container `varal-api`; se a versão nova não ficar saudável em 90 s, volta para a anterior. Migrations seguem o padrão expandir e depois contrair, para a versão anterior continuar funcionando durante a troca.
  - **Apps:** `deploy-app` extrai o build em `/opt/nginx/html/varal-<app>/releases/<versão>` e troca o link `current` de uma vez. Voltar versão é trocar o link.
  - **Segredos:** os de deploy (`DEPLOY_SSH_KEY`, `DEPLOY_HOST`, `DEPLOY_KNOWN_HOSTS`) ficam nos secrets do GitHub de cada repositório de código; os da aplicação ficam em `/opt/varal/.env` no VPS (permissão 640, grupo `deploy`) e nas credenciais locais, fora do git.
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
  - scripts de deploy, usuário `deploy` e workflows de deploy (seção 2.4).
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

### Fase 7.5 — Redesenho pós-teste

O primeiro teste real do piloto (2026-10-02) mostrou que o turno confundia, que o painel não dizia o que fazer e que, ao abrir as estações, não havia como voltar ao painel. As specs foram reescritas (decisões na seção 6); esta fase leva o código até elas antes do piloto.

Ordem: `varal-docs` (specs) → `varal-web-api` → `varal-panel-web` e `varal-admin-web` → `varal-infra` (só procedimento). Branch com o mesmo nome em todos: `feat/caixa-da-unidade`. A API remove as rotas de turno (`BREAKING CHANGE`), então API e painel são publicados juntos, numa janela sem caixa aberto (fora do horário da feira).

| Repositório | Entregas |
| --- | --- |
| `varal-docs` | Specs 01 a 08 e este plano (feito nesta branch); `docs/agents/` sem `Shift` no glossário de exemplo e com os escopos novos; `AGENTS.md` regenerado em cada repositório |
| `varal-web-api` | Migração de dados (abaixo); caixas cadastrados e aberturas de caixa (spec 05); dia de operação e numeração por dia (RN-04.09, RN-04.29); tabelas de preço e tabela vigente (RN-03.20 a 03.24, RN-04.31 a 04.33); eventos (RN-04.34 a 04.37); `GET /units/{id}/operation` e `unit.operation_updated`; fila da estação agrupada por pedido e avanço do pedido inteiro (RN-04.39 a 04.45); fechamento de caixa com pendentes, preparo e evento (RN-05.28, RN-05.29); relatórios por dia, caixa e evento (spec 07); métricas do admin por dia de operação (spec 02); seed com "Caixa 1" e uma tabela "Evento"; `openapi.json`; testes de todos os CA novos e reescritos |
| `varal-panel-web` | Início do painel orientado à tarefa e menus novos (spec 01, seção 14.2); botão "Painel" e "Trocar de estação" no balcão, nas estações e em `/estacoes` (RN-01.24 a 01.27); telas de caixas (`/caixas`, abrir, fechar) e cadastro de caixas; faixa de operação do balcão e estado sem caixa aberto; troca da tabela vigente; tabelas de preço no cardápio e no editor de produto; eventos; tela da estação no formato KDS (cartão por pedido, grade em toda a largura, contadores, filtro, tela cheia, desfazer e recentes); relatórios (histórico em abas, período, caixa, evento); fila offline para as rotas novas; redirecionamentos de `/painel/turnos` e `/painel/relatorios/turnos/{id}`; Playwright do dia completo (abrir caixa → vender → cozinha → receber → fechar com comanda pendente) |
| `varal-admin-web` | `pnpm gen:api`; métricas e detalhe da organização com dias de operação no lugar de turnos |
| `varal-infra` | No `prod/README.md`, o passo de `pg_dump` manual do banco `varal` antes de aplicar a migração desta fase (ainda não há backup automático) |

**Migração de dados** (uma migration de expansão nesta fase; a de contração, que apaga o que sobrou do turno, vai na versão seguinte, depois de os apps novos estarem no ar):

1. **Caixas:** a tabela `cash_registers` atual (um caixa por turno) é renomeada para `cash_register_sessions`, e as colunas `cash_register_id` de `payments`, `cash_movements` e `cash_register_counts` viram `cash_register_session_id`. Os nomes distintos de cada unidade (sem diferenciar maiúsculas) viram os caixas cadastrados da nova `cash_registers`; unidade sem nenhum ganha "Caixa 1". Cada abertura recebe o `business_date` do dia de abertura do turno dela (fuso de São Paulo) e pendentes zerados. Histórico preservado: nenhum pagamento, movimento ou conferência muda de valor.
2. **Comandas e itens:** `tabs.business_date` e `closed_business_date` = dia do turno; `order_items.canceled_business_date` = dia do turno nos cancelados. O único `(shift_id, number)` dá lugar ao índice parcial das comandas em aberto. Cada unidade recebe `business_date` e `next_tab_number` do último turno.
3. **Preços do turno → tabelas de preço:** cada turno com preços vira uma tabela inativa, chamada pelo contratante (turno contratado) ou "Preços de dd/mm/aaaa", com os mesmos preços em `product_prices`; os itens vendidos com preço do turno recebem o `price_list_id` dessa tabela. O dono reativa e renomeia a que quiser reaproveitar (ex.: "Evento").
4. **Acordos → eventos:** cada turno contratado vira um evento `finished` (contratante, data do turno, acordo e a tabela do passo 3), e as comandas do turno recebem o `event_id`.
5. **Turno aberto na hora da migração** (a janela de deploy evita, mas a migration trata): as aberturas dele continuam abertas; se for contratado, o evento fica `in_progress`; se tiver preços, a tabela dele fica ativa e vigente.
6. **Conferência:** um script compara, para cada turno antigo, venda, recebido, pendurado, perdas e diferença de caixa calculados pelo relatório de turno (antes) e pelo relatório do dia e dos caixas (depois); a migration só é aplicada em produção com o script sem diferenças no banco de desenvolvimento restaurado do `pg_dump`.
7. **Contração (versão seguinte):** apaga `shifts`, `shift_agreements`, `shift_prices` e as colunas `shift_id` de `tabs`, `orders` e `payments`.

Critérios: CA-01.16 a 01.18, CA-02.05, CA-03.03, CA-03.09 a 03.11, CA-04 (reescritos e CA-04.14 a 04.23), CA-05.08, CA-05.10 a 05.14, CA-06.03, CA-07 e CA-08.05, mais a conferência da migração sem diferenças.

### Fase 8 — Piloto

- Teste de ponta a ponta nos aparelhos reais do piloto (Android e iPhone, sol, rede ruim), incluindo a tela da cozinha num tablet ou TV.
- Ensaio de um dia completo: abrir o caixa, vender, preparar, receber, fechar o caixa com comanda pendente e abrir no dia seguinte.
- Ajustes de usabilidade, observação dos relatórios de DMARC e acompanhamento do primeiro turno real.

### Paralelismo

```
Fase 0 ─► Fase 1 ─► Fase 2 ─┬─► Fase 4 ─► Fase 5 ─► Fase 6 ─► Fase 7 ─► Fase 7.5 ─► Fase 8
                            └─► Fase 3 (em paralelo a partir da 4)
```

- Fases 0 e 2: cada repositório avança em paralelo, um agente por repositório.
- A partir da fase 3: um agente na API e um em cada app por fase. O app começa assim que o PR da API com o contrato estiver mergeado.
- O admin (fase 3) corre em paralelo com as fases 4 e 5, porque só depende da fundação.
- Na fase 7.5, depois do PR da API com o contrato, o painel pode ser dividido entre agentes por assunto (início e navegação; caixas; tabelas e eventos; estação KDS; relatórios), cada um no seu worktree, todos com merge na mesma release.

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

- **Deploy:** pelo GitHub Actions, com usuário `deploy` restrito (seção 2.4).
- **Versões:** começam em 0.1.0; a primeira versão no ar sai no fim da fase 2.

Decididos em 2026-10-02, depois do primeiro teste real (fase 7.5):

- **Fim do turno:** o turno deixa de existir para o usuário. O caixa é cadastrado na unidade; abrir o caixa (com fundo de troco) começa o dia e libera vender; fechar o caixa (contagem por forma e diferença) termina. Cada abertura até o fechamento é uma "abertura de caixa" (`cash_register_sessions`). Pagamentos ficam ligados à abertura em que foram recebidos (spec 05).
- **Comandas abertas não travam o fechamento:** aparecem como pendentes e seguem abertas para o próximo dia ou outro caixa (spec 04, RN-04.07; spec 05, RN-05.28).
- **Numeração das comandas:** sequencial por dia de operação da unidade (fuso de São Paulo), pulando os números de comandas ainda abertas de dias anteriores. O dia de operação só muda ao abrir o primeiro caixa num dia novo, para que a feira que passa da meia-noite não reinicie a numeração (spec 04, RN-04.09 e RN-04.29).
- **Tabelas de preço** no lugar dos preços do turno: preenchidas uma vez no cardápio; a unidade tem uma tabela vigente trocada com um toque, que vale para itens novos (spec 03, seção 5.3; spec 04, seção 3.2).
- **Evento contratado** continua no MVP como cadastro opcional da unidade (contratante, data, acordo, tabela de preço); em andamento, liga as comandas novas e impõe a tabela dele (spec 04, seção 3.3).
- **Relatórios** por dia ou período, por abertura de caixa e por evento; o relatório do turno sai (spec 07).
- **Navegação:** início do painel com uma ação principal conforme a situação da unidade; botão "Painel" e "Trocar de estação" em toda tela de operação para quem tem painel (spec 01, seção 14.2).
- **Estação (KDS):** um pedido, um cartão, em todas as estações; avanço por item e do pedido inteiro; grade em toda a largura em telas grandes; tela cheia (spec 04, seção 8.2).

Nenhum ponto pendente no momento.
