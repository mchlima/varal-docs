# 01 — Fundação

## 1. Objetivo

Criar a base sobre a qual todos os módulos são construídos: estrutura do repositório, infraestrutura, convenções técnicas, isolamento entre organizações, autenticação dos três perfis, auditoria, envio de e-mail, tempo real e tolerância a queda de conexão.

## 2. Escopo

**Dentro**

- Monorepo com API, app dos clientes, app do admin e pacote compartilhado.
- Docker Compose para desenvolvimento e produção no VPS, com NGINX.
- Autenticação de dono, colaborador e admin da plataforma.
- Redefinição de senha e convite por e-mail.
- Auditoria de ações.
- Serviço de e-mail com registro de envios.
- Infraestrutura de WebSocket (salas, autenticação, reconexão).
- Fila local de ações no aparelho para quedas de conexão.

**Fora**

- Cobrança da assinatura.
- Modo offline completo (operar horas sem internet com resolução de conflitos).
- Cadastro do dono pelo site (no piloto o admin cria a conta).

## 3. Estrutura do monorepo

```
varal/
├── apps/
│   ├── api/        # NestJS — API REST + WebSocket, para os dois apps
│   ├── web/        # Nuxt — balcão, estações, caixa e painel do dono (PWA)
│   └── admin/      # Nuxt — admin da plataforma
├── packages/
│   └── shared/     # tipos, enums, schemas de validação, contratos de eventos
├── docs/specs/
├── infra/          # docker compose, nginx, scripts de backup
└── package.json    # pnpm workspaces
```

- Gerenciador: pnpm workspaces. Node 22 LTS. TypeScript em modo `strict` em todos os pacotes.
- `packages/shared` é a única fonte de enums de estado (`TabStatus`, `OrderStatus`…), schemas de validação de entrada e payloads de eventos em tempo real. API e apps importam dele; nada é duplicado.
- Validação: **zod (proposta)**, usada na API (pipe de validação) e nos formulários dos apps.
- ORM: **Prisma (proposta)**, com migrations versionadas em `apps/api/prisma`.

## 4. Infraestrutura

| Serviço | Imagem / app | Exposição |
| --- | --- | --- |
| `nginx` | NGINX | Portas 80/443, termina HTTPS |
| `api` | `apps/api` | Interna, porta 3000 |
| `web` | `apps/web` (build estático servido pelo NGINX) | Via NGINX |
| `admin` | `apps/admin` (build estático servido pelo NGINX) | Via NGINX |
| `postgres` | PostgreSQL 16 | Interna, volume persistente |

Domínios **(proposta)**, sob kratinho.com.br enquanto não houver domínio próprio:

| Host | Serve |
| --- | --- |
| `varal.kratinho.com.br` | App `web`; `/api` e `/ws` encaminhados para `api` |
| `admin.varal.kratinho.com.br` | App `admin`; `/api` encaminhado para `api` |

- API e app no mesmo host evitam CORS e permitem cookies `SameSite=Strict`.
- Os apps são SPAs (Nuxt com `ssr: false`) instaláveis como PWA no `web`.
- Backup: `pg_dump` diário às 04:00 (horário de Brasília), comprimido, enviado para armazenamento fora do VPS, com retenção de 30 dias. O destino é questão aberta.
- Variáveis sensíveis (SMTP, segredos de token, banco) só em variáveis de ambiente, nunca no repositório. Um `.env.example` lista todas.

### 4.1 Desenvolvimento com vários agentes em paralelo

O repositório é trabalhado por vários agentes ao mesmo tempo, cada um num git worktree em `.worktrees/` (regras no `AGENTS.md`). O ambiente de desenvolvimento precisa permitir vários worktrees rodando juntos na mesma máquina.

- **RN-01.06** Um Postgres de desenvolvimento compartilhado roda num projeto Compose fixo (`varal-dev-db`, porta 5432). Cada worktree usa **um banco próprio** nesse servidor, chamado `varal_<slug-da-branch>`.
- **RN-01.07** Cada worktree tem um `.env.local` (fora do git) com `WORKTREE_SLUG`, `PORT_OFFSET`, as portas resultantes, `DATABASE_URL` do seu banco e `COMPOSE_PROJECT_NAME=varal-<slug>`.
- **RN-01.08** Portas: API `3000 + PORT_OFFSET`, web `3100 + PORT_OFFSET`, admin `3200 + PORT_OFFSET`. O checkout principal usa `PORT_OFFSET=0`; cada worktree recebe o próximo valor livre entre 1 e 99.
- Um script `scripts/worktree.sh` faz o ciclo completo:
  - `new <tipo>/<descricao>`: cria o worktree a partir da `main`, escolhe um `PORT_OFFSET` livre, gera o `.env.local`, cria o banco, instala dependências e aplica migrations e seed;
  - `list`: mostra worktrees com branch, portas e banco;
  - `remove <nome>`: apaga o banco do worktree e remove o worktree (recusa se houver alterações sem commit).
- Os testes automatizados de cada worktree usam um banco de teste próprio (`varal_<slug>_test`), recriado a cada execução.
- Nenhum script do projeto pode apagar bancos, volumes ou containers que não sejam do próprio worktree.

## 5. Convenções da API

- REST com JSON, prefixo `/api/v1`. Rotas do admin da plataforma em `/api/v1/admin/...`.
- Erros no formato:
  ```json
  { "error": { "code": "TAB_ALREADY_CLOSED", "message": "Esta comanda já foi fechada.", "details": {} } }
  ```
  `code` é estável e em inglês; `message` é em português e pode ser mostrada ao usuário.
- Listas paginadas por cursor: `?limit=50&cursor=...`, resposta `{ "data": [...], "nextCursor": "..." }`.
- **Idempotência:** toda requisição que cria ou altera dado operacional (pedido, pagamento, mudança de etapa, movimento de caixa) aceita o cabeçalho `Idempotency-Key` (UUID gerado no aparelho). A API guarda a chave por 24 h e devolve a mesma resposta se ela se repetir. Isso permite reenviar com segurança após queda de conexão.
- Datas em ISO 8601 com fuso; valores em centavos.

## 6. Multi-tenant

- Toda tabela com dados de cliente tem `organization_id NOT NULL` e índice que começa por ela.
- A organização da requisição vem do token, nunca de parâmetro enviado pelo cliente.
- Um contexto por requisição (AsyncLocalStorage) guarda `organizationId`, `actor` e `deviceId`. Uma extensão do ORM aplica o filtro `organization_id` automaticamente em leituras e escritas de tabelas de tenant **(proposta)**.
- Rotas do admin da plataforma usam um cliente de banco sem esse filtro, disponível só no módulo do admin.
- Testes automatizados garantem que um usuário da organização A não lê nem altera nada da organização B em nenhum endpoint (teste de isolamento obrigatório para cada novo recurso).

**RN-01.01** Uma organização com situação `suspended` ou `canceled` não abre turnos novos; turnos já abertos podem ser fechados.

## 7. Autenticação

### 7.1 Perfis e formas de login

| Perfil | App | Login | Identificador único |
| --- | --- | --- | --- |
| Dono | `web` | e-mail + senha | e-mail, global |
| Colaborador | `web` | código do estabelecimento + username + senha | `(organization_id, username)` |
| Admin da plataforma | `admin` | e-mail + senha | e-mail, global entre admins |

- O código do estabelecimento é a coluna `organizations.access_code`: 6 caracteres alfanuméricos maiúsculos, sem caracteres ambíguos (0/O, 1/I), único, gerado na criação.
- O link de acesso do colaborador é `https://varal.kratinho.com.br/e/{access_code}`; abre a tela de login com o código preenchido. O QR code codifica esse link.
- Dono e colaborador usam o mesmo app; depois do login, o colaborador escolhe a estação entre as liberadas, e o dono vê o painel e pode abrir qualquer estação.

### 7.2 Sessão

- **(proposta)** Token de acesso JWT com validade de 15 min e token de renovação opaco com validade de 30 dias, rotativo, guardado como hash no banco. Ambos em cookies `httpOnly`, `Secure`, `SameSite=Strict`.
- Cookies do admin usam nome e segredo de assinatura diferentes dos do app `web`; um token de um contexto nunca é aceito no outro.
- Cada aparelho recebe um `device_id` (UUID guardado no aparelho) enviado em todas as requisições, usado na auditoria e na lista de sessões.
- Logout encerra a sessão do aparelho. Troca ou redefinição de senha encerra todas as sessões daquele usuário.
- Desativar um colaborador encerra todas as sessões dele imediatamente; o WebSocket dele é desconectado.

### 7.3 Senhas

- Hash com argon2id.
- Mínimo de 8 caracteres. Sem outras regras de composição.
- Bloqueio temporário de 15 min após 10 tentativas erradas seguidas para o mesmo identificador.

### 7.4 Convite e redefinição

| Fluxo | Quem dispara | Entrega | Validade |
| --- | --- | --- | --- |
| Convite do dono | Admin da plataforma, ao criar a organização | E-mail com link para definir a senha | 7 dias |
| Redefinição do dono | O próprio dono, em "Esqueci a senha" | E-mail | 1 hora |
| Redefinição do colaborador | O dono, no painel | E-mail (se houver) e/ou link para copiar ou enviar por WhatsApp | 1 hora |
| Convite e redefinição de admin | Admin com `admin.users:manage` | E-mail | 7 dias / 1 hora |

- O token do link é aleatório (32 bytes), guardado só como hash, de uso único.
- Ao gerar um novo token do mesmo tipo para o mesmo usuário, os anteriores são invalidados.
- **RN-01.02** No máximo 3 links de redefinição por usuário por hora.
- **RN-01.03** "Esqueci a senha" responde sempre com a mesma mensagem, exista ou não o e-mail.

## 8. Auditoria

Toda ação que cria, altera, cancela ou remove dado relevante grava uma linha em `audit_logs`.

- Campos: quem (tipo de ator e id), em nome de quem (quando for "entrar como"), ação (`tab.discount_applied`, `order_item.canceled`…), entidade e id, dados antes e depois (somente campos alterados), `device_id`, IP, data.
- A gravação acontece na mesma transação da ação.
- Ações auditadas no mínimo: login e logout, criação e alteração de cadastros, abertura e fechamento de turno e caixa, abertura, fechamento, reabertura e cancelamento de comanda, cancelamento de item, mudança de etapa, desconto, pagamento e estorno, sangria e suprimento, pendurar e quitar, todas as ações do admin da plataforma.
- A auditoria é somente inserção: não há endpoint para alterar ou apagar.

## 9. E-mail

- Envio via SMTP Locaweb com nodemailer, remetente fixo `Varal <nao-responda@kratinho.com.br>` **(proposta)**.
- Envio assíncrono por fila no próprio PostgreSQL (**pg-boss, proposta**), para que lentidão do SMTP não trave a requisição. Até 3 tentativas com espera crescente.
- Cada envio grava `email_logs` (destinatário, tipo, situação, erro, datas).
- **RN-01.04** Limite do plano: 10.000 envios por mês. Ao atingir 80% (8.000), o admin da plataforma vê um alerta no painel. Ao atingir 100%, envios não críticos param; convites e redefinições continuam e o alerta muda para crítico.
- Nenhum e-mail é disparado por evento operacional (pedido, pagamento, turno).
- Tipos no MVP: `owner_invite`, `owner_password_reset`, `staff_password_reset`, `admin_invite`, `admin_password_reset`.

## 10. Tempo real

- Socket.IO no NestJS, caminho `/ws`.
- A conexão é autenticada pelo mesmo cookie de sessão; sem sessão válida, a conexão é recusada.
- Salas:
  - `unit:{unitId}` — tudo que acontece na unidade (balcão e painel do dono);
  - `station:{stationId}` — itens que entram, mudam ou saem da fila de uma estação.
- O servidor só coloca o aparelho em salas da organização e das unidades e estações que o usuário pode acessar.
- Eventos levam `organizationId`, `unitId`, `occurredAt` e um número de versão do recurso. O app ignora eventos com versão menor que a que já tem.
- **RN-01.05** Ao reconectar, o app sempre busca o estado atual por REST (comandas abertas, fila da estação) antes de voltar a aplicar eventos. Eventos perdidos durante a desconexão nunca são necessários para chegar ao estado correto.
- Os eventos de cada módulo estão definidos nas specs 03, 04 e 05.

## 11. Queda de conexão (fila local)

- O app `web` guarda numa fila local (IndexedDB) toda ação operacional que não conseguiu enviar: criar pedido, mudar etapa, cancelar item, registrar pagamento, movimento de caixa.
- Cada ação na fila tem sua `Idempotency-Key`, gerada no momento da ação.
- Quando a conexão volta, a fila é enviada em ordem. Uma ação recusada pela API (ex.: comanda já fechada) é retirada da fila e mostrada ao usuário com o motivo.
- Um indicador fixo no topo mostra "Sem conexão — N ações aguardando envio" enquanto houver pendências.
- O app não tenta prever o resultado de ações de outros aparelhos enquanto estiver sem conexão.

## 12. Modelo de dados

Tipos abreviados: `uuid`, `text`, `int`, `bool`, `ts` (`timestamptz`), `jsonb`. Toda tabela tem `id uuid PK`, `created_at ts`, `updated_at ts`.

**organizations**

| Coluna | Tipo | Regra |
| --- | --- | --- |
| `name` | text | obrigatório |
| `access_code` | text | único, 6 caracteres |
| `subscription_status` | text | `pilot`, `active`, `suspended`, `canceled` |
| `suspended_reason` | text | opcional |

**units**

| Coluna | Tipo | Regra |
| --- | --- | --- |
| `organization_id` | uuid | FK |
| `name` | text | único dentro da organização |
| `active` | bool | |
| `late_after_minutes` | int | padrão 15; usado na spec 04 |

**users** (donos)

| Coluna | Tipo | Regra |
| --- | --- | --- |
| `organization_id` | uuid | FK |
| `name` | text | |
| `email` | text | único global, minúsculas |
| `password_hash` | text | nulo até aceitar o convite |
| `email_verified_at` | ts | preenchido ao aceitar o convite |
| `active` | bool | |

No MVP cada organização tem um dono. A tabela já permite mais de um.

**staff_members**

| Coluna | Tipo | Regra |
| --- | --- | --- |
| `organization_id` | uuid | FK |
| `name` | text | |
| `username` | text | único por `(organization_id, lower(username))`; letras, números, ponto e sublinhado |
| `email` | text | opcional |
| `password_hash` | text | |
| `active` | bool | |

**staff_unit_permissions**

| Coluna | Tipo | Regra |
| --- | --- | --- |
| `organization_id` | uuid | FK |
| `staff_member_id` | uuid | FK |
| `unit_id` | uuid | FK; único com `staff_member_id` |
| `station_ids` | uuid[] | estações liberadas na unidade |
| `can_operate_cash` | bool | pode abrir, movimentar e fechar caixa |

**sessions**: `subject_type` (`owner`, `staff`, `platform_admin`), `subject_id`, `device_id`, `refresh_token_hash`, `expires_at`, `revoked_at`, `last_used_at`, `user_agent`, `ip`, `impersonation_id` (opcional, spec 02).

**password_tokens**: `subject_type`, `subject_id`, `purpose` (`invite`, `reset`), `token_hash`, `expires_at`, `used_at`.

**audit_logs**: `organization_id` (nulo para ações só da plataforma), `actor_type`, `actor_id`, `impersonator_id` (opcional), `action`, `entity_type`, `entity_id`, `changes jsonb`, `device_id`, `ip`, `created_at`. Índices por `(organization_id, created_at)` e `(entity_type, entity_id)`.

**email_logs**: `organization_id` (opcional), `to`, `type`, `status` (`queued`, `sent`, `failed`), `error`, `sent_at`.

**idempotency_keys**: `key`, `subject_id`, `request_hash`, `response jsonb`, `status_code`, `expires_at`.

## 13. API

| Método e rota | Descrição |
| --- | --- |
| `POST /api/v1/auth/owner/login` | Login do dono |
| `POST /api/v1/auth/staff/login` | Login do colaborador (`accessCode`, `username`, `password`) |
| `GET /api/v1/auth/access-code/{code}` | Nome da organização para exibir na tela de login; 404 se inválida |
| `POST /api/v1/auth/refresh` | Renova a sessão |
| `POST /api/v1/auth/logout` | Encerra a sessão do aparelho |
| `GET /api/v1/auth/me` | Perfil, organização, unidades e estações permitidas |
| `POST /api/v1/auth/password/forgot` | Dono pede redefinição |
| `POST /api/v1/auth/password/reset` | Define nova senha com token (convite ou redefinição) |
| `POST /api/v1/auth/password/change` | Troca de senha logado |
| `POST /api/v1/admin/auth/login` | Login do admin da plataforma |
| `POST /api/v1/admin/auth/refresh`, `/logout`, `GET /me` | Equivalentes no contexto do admin |

## 14. Telas

| Tela | App | Conteúdo |
| --- | --- | --- |
| Login | web | Abas "Sou dono" e "Sou colaborador". Pela rota `/e/{code}`, abre direto em colaborador com o nome da barraca no topo |
| Escolher estação | web | Botões grandes com as estações liberadas na unidade; se houver mais de uma unidade, escolhe a unidade antes |
| Definir senha | web e admin | Usada no convite e na redefinição |
| Esqueci a senha | web (dono) e admin | Pede o e-mail |
| Indicador de conexão | web | Faixa fixa no topo quando desconectado ou com ações pendentes |

### 14.1 Rotas do front

Rotas em português, sem acentos, com hífen entre palavras. Parâmetros identificam o recurso pelo id, exceto o código do estabelecimento e o número da comanda, que são o que o usuário reconhece.

**App `web`**

| Rota | Tela | Spec |
| --- | --- | --- |
| `/entrar` | Login (dono e colaborador) | 01 |
| `/e/{codigo}` | Login do colaborador com o código preenchido | 01 |
| `/definir-senha` | Convite e redefinição de senha | 01 |
| `/esqueci-a-senha` | Pedido de redefinição do dono | 01 |
| `/estacoes` | Escolha de unidade e estação | 01 |
| `/balcao` | Varal de comandas | 04 |
| `/balcao/comandas/{numero}` | Comanda do turno atual | 04 |
| `/balcao/comandas/{numero}/pedido` | Montar pedido | 04 |
| `/balcao/comandas/{numero}/receber` | Receber, desconto e pendurar | 05, 06 |
| `/estacao/{id}` | Fila de uma estação | 04 |
| `/caixas` | Caixas do turno | 05 |
| `/caixas/{id}/fechar` | Fechamento de caixa | 05 |
| `/painel` | Início do painel do dono | — |
| `/painel/unidades` | Unidades | 03 |
| `/painel/unidades/{id}/fluxo` | Estações e fluxo | 03 |
| `/painel/cardapio` | Cardápio | 03 |
| `/painel/colaboradores` | Colaboradores e permissões | 03 |
| `/painel/acesso-da-equipe` | Código, link e QR | 03 |
| `/painel/turnos` | Abrir turno e turno atual | 04 |
| `/painel/fiado` | Clientes e valores a receber | 06 |
| `/painel/relatorios` | Histórico | 07 |
| `/painel/relatorios/turnos/{id}` | Relatório do turno | 07 |
| `/painel/acessos-de-suporte` | Acessos de "entrar como" na conta | 02 |

**App `admin`**

| Rota | Tela |
| --- | --- |
| `/entrar`, `/definir-senha`, `/esqueci-a-senha` | Acesso |
| `/` | Início |
| `/organizacoes`, `/organizacoes/nova`, `/organizacoes/{id}` | Organizações |
| `/comunicados`, `/comunicados/novo`, `/comunicados/{id}` | Comunicados |
| `/metricas` | Métricas |
| `/emails` | E-mails |
| `/auditoria` | Auditoria |
| `/usuarios`, `/usuarios/{id}` | Usuários do admin |
| `/papeis`, `/papeis/{id}` | Papéis |

## 15. Critérios de aceite

- **CA-01.01** `docker compose up` sobe API, apps, NGINX e banco localmente, com migrations aplicadas e um seed de exemplo (uma organização, uma unidade com o template padrão, um dono, dois colaboradores, um admin Super admin).
- **CA-01.02** Um colaborador da organização A, com token válido, recebe 404 ao acessar qualquer recurso da organização B, em todos os endpoints (teste automatizado).
- **CA-01.03** O login do colaborador pelo link `/e/{code}` funciona digitando apenas username e senha.
- **CA-01.04** Um token do app `web` é recusado nas rotas `/api/v1/admin` e vice-versa.
- **CA-01.05** Redefinir a senha de um colaborador encerra as sessões abertas dele em até 15 minutos (expiração do token de acesso) e desconecta o WebSocket na hora.
- **CA-01.06** Repetir uma requisição de criação com a mesma `Idempotency-Key` não cria registro duplicado e devolve a mesma resposta.
- **CA-01.07** Com o aparelho sem conexão, uma mudança de etapa feita na estação fica na fila local e é aplicada uma única vez quando a conexão volta.
- **CA-01.08** Cada ação listada na seção 8 gera exatamente uma linha de auditoria com ator, aparelho e alterações.
- **CA-01.09** Ao passar de 8.000 envios no mês, o painel do admin mostra o alerta de e-mail.
- **CA-01.10** O backup diário gera um arquivo restaurável (teste de restauração documentado em `infra/`).

## 16. Questões abertas

- Destino do backup fora do VPS (ex.: bucket S3 compatível, outro servidor).
- Confirmar as propostas técnicas: Prisma, zod, pg-boss, JWT com renovação em cookie, subdomínios.
