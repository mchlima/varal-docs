# 01 — Fundação

## 1. Objetivo

Criar a base sobre a qual todos os módulos são construídos: estrutura do repositório, infraestrutura, convenções técnicas, isolamento entre organizações, autenticação dos três perfis, auditoria, envio de e-mail, tempo real e tolerância a queda de conexão.

## 2. Escopo

**Dentro**

- Repositórios separados para a API, o app dos clientes, o admin, a infraestrutura e a documentação.
- Tudo em Docker: Docker Compose no desenvolvimento e no VPS, reaproveitando o PostgreSQL e o proxy NGINX compartilhados do VPS.
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

## 3. Repositórios

Cada parte do sistema tem o próprio repositório no GitHub (`mchlima/...`):

| Repositório | Conteúdo | Stack |
| --- | --- | --- |
| `varal-docs` | Specs, glossário, decisões e regras comuns dos agentes | Markdown |
| `varal-web-api` | API REST (`/api/v1`) e WebSocket (`/ws`), banco e migrations | NestJS, PostgreSQL |
| `varal-panel-web` | App dos clientes: balcão, estações, caixa e painel do dono (PWA) | Nuxt |
| `varal-admin-web` | Admin da plataforma | Nuxt |
| `varal-infra` | Docker Compose de produção, configuração do Varal no NGINX compartilhado e Postgres de desenvolvimento | Docker, NGINX |

Na máquina de desenvolvimento, os repositórios ficam lado a lado numa pasta comum, para que agentes e scripts enxerguem os vizinhos por caminho relativo:

```
varal/                 (pasta comum, não é repositório)
├── varal-docs/
├── varal-web-api/
├── varal-panel-web/
├── varal-admin-web/
└── varal-infra/
```

- Node 26 (vira LTS em 28/10/2026) e TypeScript em modo `strict` nos três projetos de código, com a versão em `.nvmrc`. Gerenciador de pacotes: pnpm.
- Validação: **zod** na API e nos formulários dos apps.
- ORM: **Prisma**, com migrations versionadas no `varal-web-api`.

### 3.1 Contratos entre API e apps

Não há pacote compartilhado. A API é a fonte única dos contratos e os publica como OpenAPI:

- **RN-01.09** O `varal-web-api` gera o documento OpenAPI 3.1 a partir do código e o mantém commitado em `openapi.json`, na raiz do repositório. Todo PR que muda rota, schema, enum ou evento atualiza esse arquivo; a CI falha se o arquivo estiver desatualizado.
- **RN-01.10** Enums de estado (`TabStatus`, `OrderStatus`…) e os payloads dos eventos em tempo real entram no OpenAPI como schemas em `components.schemas` (eventos com o prefixo `Event`, ex.: `EventOrderCreated`), mesmo os que não aparecem em nenhuma rota.
- **RN-01.11** `varal-panel-web` e `varal-admin-web` geram os tipos e o cliente HTTP a partir desse arquivo com **openapi-typescript e openapi-fetch**, por um script `pnpm gen:api` que lê `../varal-web-api/openapi.json` (ou a URL do arquivo no GitHub, na CI). Os tipos gerados ficam commitados no app e nunca são editados à mão.
- **RN-01.12** Mudanças na API são compatíveis com versões anteriores sempre que possível (só adicionar campos, rotas e valores). Uma mudança incompatível exige PRs coordenados nos repositórios afetados e o rodapé `BREAKING CHANGE` no commit da API.
- Os tokens visuais (spec 08) são mantidos nos dois apps, com a spec 08 como fonte; mudança de token é feita nos dois.

## 4. Infraestrutura

Definida no `varal-infra`. O VPS de produção (SV-GENERAL-00, Locaweb: Ubuntu 24.04, 2 vCPUs, 4 GB de RAM, 70 GB de SSD) é compartilhado com outros projetos do usuário. Estado verificado em 2026-10-01:

- **PostgreSQL** já roda em Docker: container `postgres`, imagem `postgres:17`, Compose próprio em `/opt/postgres` (fora dos repositórios do Varal), volume externo `postgres_data` e rede Docker externa `postgres`. Os containers que entram nessa rede falam com ele em `postgres:5432`. A porta 5432 é publicada no host de propósito, para clientes externos. Configurado para a máquina compartilhada: `max_connections=50` e limite de 1,3 GB de memória.
- **NGINX** roda em Docker desde 2026-10-01: container `nginx` (`nginx:1.30-alpine`), Compose próprio em `/opt/nginx` (fora dos repositórios do Varal), rede Docker externa `proxy` e portas 80/443. Cada projeto entra com os próprios arquivos em `/opt/nginx/conf.d/<projeto>-<host>.conf` e os próprios builds estáticos em `/opt/nginx/html/<projeto>/`, servidos em `/srv/html/<projeto>`. O `server` padrão responde só `/healthz` e desafios ACME e fecha as demais conexões. O mesmo Compose tem um container `certbot` (Let's Encrypt) para projetos que não usam o Cloudflare. O NGINX que vinha instalado no host foi parado e desabilitado. O `/opt/nginx/README.md` descreve o uso.

Regras:

- **RN-01.14** Tudo no VPS roda em Docker. Nada do Varal é instalado direto no sistema do VPS (nem Node, nem NGINX, nem PostgreSQL, nem cron do host); tarefas agendadas rodam em container.
- **RN-01.15** O Varal não sobe PostgreSQL nem proxy reverso próprios: usa os compartilhados do VPS. No proxy, entra com arquivos de configuração próprios (um `server` por host), sem alterar a configuração dos outros projetos; o `varal-infra` guarda esses arquivos e descreve como instalá-los e recarregar o proxy.
- **RN-01.16** No PostgreSQL compartilhado, o Varal tem um banco `varal` e um usuário `varal` dono só desse banco, sem privilégio de superusuário. A API nunca conecta com o usuário `postgres`. Como as conexões são divididas entre projetos, o pool da API usa no máximo 10 conexões **(proposta)**.
- **RN-01.17** A API entra na rede Docker externa `postgres` e na rede do proxy; não publica porta no host.
- **RN-01.18** O DNS do domínio fica no **Cloudflare**, que também fornece o certificado HTTPS público. Os hosts do Varal ficam com proxy ligado (nuvem laranja) e modo SSL **Full (strict)**. Entre o Cloudflare e o VPS, o NGINX usa um **Cloudflare Origin Certificate** curinga (`*.kratinho.com.br` e `kratinho.com.br`, válido até 2041) guardado em `/opt/nginx/certs/kratinho.com.br/`, fora de qualquer repositório; o Varal não usa o certbot.
- **RN-01.19** Atrás do Cloudflare, o IP do cliente vem no cabeçalho `CF-Connecting-IP`. O NGINX restaura o IP real (`real_ip_header CF-Connecting-IP` e `set_real_ip_from` com as faixas de IP publicadas pelo Cloudflare) e repassa à API em `X-Forwarded-For`. A API confia nesse cabeçalho só vindo do proxy, e é esse o IP gravado em sessões e auditoria.
- O Cloudflare encaminha WebSocket. Conexões ociosas por mais de 100 segundos são encerradas, o que não afeta o Socket.IO, que envia ping a cada 25 segundos.
- Registros que não são HTTP, como os de e-mail (SPF, DKIM e DMARC do SMTP da Locaweb), também ficam na zona do Cloudflare, sem proxy (nuvem cinza).

| Serviço | Origem | Exposição |
| --- | --- | --- |
| Cloudflare | DNS e proxy na borda | HTTPS público |
| proxy (`nginx`) | container compartilhado `nginx` em `/opt/nginx` | Portas 80/443; HTTPS com o Origin Certificate |
| `api` | imagem do `varal-web-api`, no Compose do Varal, container `varal-api` | Via proxy em `api-web-varal.kratinho.com.br`; redes `postgres` e `proxy`, porta 3000 interna |
| `panel` | build estático do `varal-panel-web`, servido pelo proxy | Via proxy |
| `admin` | build estático do `varal-admin-web`, servido pelo proxy | Via proxy |
| `postgres` | container compartilhado `postgres` (`postgres:17`); banco e usuário `varal` | Rede `postgres` |

Domínios, sob kratinho.com.br enquanto não houver domínio próprio (no ar desde 2026-10-01):

| Host | Serve |
| --- | --- |
| `varal.kratinho.com.br` | front do painel (`varal-panel-web`) |
| `admin-varal.kratinho.com.br` | front do admin (`varal-admin-web`) |
| `api-web-varal.kratinho.com.br` | backend: API REST (`/api/v1`) e WebSocket (`/ws`) |

- Os subdomínios usam hífen, não ponto (`admin-varal`, e não `admin.varal`), porque o certificado curinga `*.kratinho.com.br` só cobre um nível.
- **RN-01.20** Os fronts chamam a API pelo host próprio dela (`NUXT_PUBLIC_API_BASE_URL=https://api-web-varal.kratinho.com.br`, definido no build). A API libera CORS com credenciais só para as origens exatas `https://varal.kratinho.com.br` e `https://admin-varal.kratinho.com.br` (em desenvolvimento, as do `localhost`), e o Socket.IO usa a mesma lista. Nunca usa `*`.
- Os três hosts são do mesmo site (`kratinho.com.br`), então os cookies `SameSite=Strict` da sessão continuam sendo enviados nas chamadas dos fronts à API. Os cookies são emitidos pela API sem atributo `Domain` (só valem no host da API); como os dois fronts usam o mesmo host de API, painel e admin se distinguem pelo nome do cookie (seção 7.2).
- Os apps são SPAs (Nuxt com `ssr: false`); o `varal-panel-web` é instalável como PWA.
- Cada repositório de código publica a própria imagem ou build; o `varal-infra` só referencia versões (tags), sem copiar código.
- **Backup fora do MVP** (decisão de 2026-10-01): por enquanto não há backup automático do banco. Quando entrar, a sugestão é `pg_dump` diário do banco `varal` em container, comprimido, enviado para fora do VPS, com retenção de 30 dias.
- Variáveis sensíveis (SMTP, segredos de token, banco) só em variáveis de ambiente, nunca em repositório. Cada repositório tem um `.env.example` com as suas.

### 4.1 Desenvolvimento com vários agentes em paralelo

Cada repositório é trabalhado por vários agentes ao mesmo tempo, cada um num git worktree próprio, criado fora do repositório, em `varal/.worktrees/<repositório>/<nome>` (regras no `AGENTS.md`). Worktree dentro do repositório quebra o build dos apps, porque Nuxt, Vite e TypeScript sobem pelas pastas e encontram a configuração do checkout principal. O ambiente de desenvolvimento precisa permitir vários worktrees rodando juntos na mesma máquina.

- **RN-01.06** Um Postgres de desenvolvimento compartilhado, definido no `varal-infra` (`dev/compose.yml`, projeto Compose fixo `varal-dev-db`, imagem `postgres:17`, a mesma versão da produção, porta 5432), atende todos os worktrees da API. Cada worktree do `varal-web-api` usa **um banco próprio** nesse servidor, chamado `varal_<slug-da-branch>`, e um banco de teste `varal_<slug>_test`, recriado a cada execução dos testes.
- **RN-01.07** Cada worktree tem um `.env.local` (fora do git) com `WORKTREE_SLUG`, `PORT_OFFSET` e as variáveis do seu projeto: na API, a porta e o `DATABASE_URL`; nos apps, a porta e `NUXT_PUBLIC_API_BASE_URL`.
- **RN-01.08** Portas: API `3000 + PORT_OFFSET`, `varal-panel-web` `3100 + PORT_OFFSET`, `varal-admin-web` `3200 + PORT_OFFSET`. O checkout principal usa `PORT_OFFSET=0`; cada worktree recebe o próximo valor livre entre 1 e 99. Por padrão, um app aponta para a API do checkout principal (`http://localhost:3000`); para testar contra a API de uma branch, ajusta-se `NUXT_PUBLIC_API_BASE_URL` no `.env.local`.
- Cada repositório de código tem um script `scripts/worktree.sh`:
  - `new <tipo>/<descricao>`: cria o worktree a partir da `main`, escolhe um `PORT_OFFSET` livre, gera o `.env.local`, instala dependências e, na API, cria o banco e aplica migrations e seed;
  - `list`: mostra worktrees com branch e portas (e banco, na API);
  - `remove <nome>`: remove o worktree, recusando se houver alterações sem commit; na API, apaga também o banco do worktree.
- Nenhum script pode apagar bancos, volumes ou containers que não sejam do próprio worktree.
- **RN-01.13** Todo repositório tem os git hooks de bloqueio da `main` em `.githooks/` e o hook do Claude Code em `.claude/`. O `scripts/worktree.sh new` falha se o clone não tiver `core.hooksPath` apontando para `.githooks`, mostrando o comando para ativar.

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
- Um contexto por requisição (AsyncLocalStorage) guarda `organizationId`, `actor` e `deviceId`. Uma extensão do Prisma aplica o filtro `organization_id` automaticamente em leituras e escritas de tabelas de tenant e recusa a consulta (erro interno, nunca dado de outra organização) quando o contexto não tem organização ou quando a escrita traz o id de outra. Não cobre SQL cru (`$queryRaw`) nem escritas aninhadas: nesses casos o filtro é feito à mão e revisado no PR.
- Rotas do admin da plataforma, a autenticação e os jobs usam um cliente de banco sem esse filtro; uma regra de lint impede importá-lo em outros módulos.
- Testes automatizados garantem que um usuário da organização A não lê nem altera nada da organização B em nenhum endpoint (teste de isolamento obrigatório para cada novo recurso).

**RN-01.01** Uma organização com situação `suspended` ou `canceled` não abre turnos novos; turnos já abertos podem ser fechados.

## 7. Autenticação

### 7.1 Perfis e formas de login

| Perfil | App | Login | Identificador único |
| --- | --- | --- | --- |
| Dono | `varal-panel-web` | e-mail + senha | e-mail, global |
| Colaborador | `varal-panel-web` | código do estabelecimento + username + senha | `(organization_id, username)` |
| Admin da plataforma | `varal-admin-web` | e-mail + senha | e-mail, global entre admins |

- O código do estabelecimento é a coluna `organizations.access_code`: 6 caracteres alfanuméricos maiúsculos, sem caracteres ambíguos (0/O, 1/I), único, gerado na criação.
- O link de acesso do colaborador é `https://varal.kratinho.com.br/e/{access_code}`; abre a tela de login com o código preenchido. O QR code codifica esse link.
- Dono e colaborador usam o mesmo app; depois do login, o colaborador escolhe a estação entre as liberadas, e o dono vê o painel e pode abrir qualquer estação.

### 7.2 Sessão

- Token de acesso JWT com validade de 15 min e token de renovação opaco com validade de 30 dias, rotativo, guardado como hash no banco. Ambos em cookies `httpOnly`, `Secure`, `SameSite=Strict`.
- Cookies do admin usam nome e segredo de assinatura diferentes dos do app dos clientes; um token de um contexto nunca é aceito no outro. Nomes: `__Host-varal_at` e `__Secure-varal_rt` (renovação, `Path=/api/v1/auth`) no app; `__Host-varal_admin_at` e `__Secure-varal_admin_rt` (`Path=/api/v1/admin/auth`) no admin.
- A cada requisição a API confere o token de acesso e se a sessão continua válida, então logout, troca de senha e desativação cortam o acesso na hora (o WebSocket é desconectado pelo mesmo evento). Um `X-Device-Id` diferente do da sessão é recusado.
- Renovação rotativa: reapresentar um token de renovação já trocado revoga a sessão (sinal de roubo). Nos 30 s seguintes a uma troca, o token anterior só é recusado, sem revogar (duas abas ou reenvio).
- Cada aparelho recebe um `device_id` (UUID guardado no aparelho) enviado em todas as requisições, usado na auditoria e na lista de sessões.
- Logout encerra a sessão do aparelho. Troca ou redefinição de senha encerra todas as sessões daquele usuário.
- Desativar um colaborador encerra todas as sessões dele imediatamente; o WebSocket dele é desconectado.

### 7.3 Senhas

- Hash com argon2id.
- Mínimo de 8 caracteres. Sem outras regras de composição.
- Bloqueio temporário de 15 min após 10 tentativas erradas seguidas para o mesmo identificador, exista ou não, com a mesma resposta de credenciais inválidas nos dois casos. Também há limite de requisições por IP nos logins e no "Esqueci a senha".
- Falhas de login não vão para `audit_logs` (identificadores inventados encheriam a tabela); ficam no contador de bloqueio e no log da aplicação.

### 7.4 Convite e redefinição

| Fluxo | Quem dispara | Entrega | Validade |
| --- | --- | --- | --- |
| Convite do dono | Admin da plataforma, ao criar a organização | E-mail com link para definir a senha | 7 dias |
| Redefinição do dono | O próprio dono, em "Esqueci a senha" | E-mail | 1 hora |
| Redefinição do colaborador | O dono, no painel | E-mail (se houver) e/ou link para copiar ou enviar por WhatsApp | 1 hora |
| Convite e redefinição de admin | Admin com `admin.users:manage` | E-mail | 7 dias / 1 hora |

- O token do link é aleatório (32 bytes), guardado só como hash, de uso único. O link é `/definir-senha#token=...&tipo=convite|redefinicao`: o token vai no fragmento, que o navegador não envia ao servidor nem grava em logs de acesso.
- Troca de senha logado encerra todas as sessões do usuário e abre uma nova para o aparelho atual.
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

- Envio via SMTP Locaweb com nodemailer, remetente fixo `Varal <nao-responda@kratinho.com.br>`.
- **RN-01.21** O endereço `nao-responda@kratinho.com.br` não recebe e-mail: no Cloudflare Email Routing (MX do domínio no Cloudflare), a regra desse endereço descarta as mensagens (ação *drop*). Respostas enviadas a ele se perdem (as devoluções vão para o Return Path, RN-01.22), por isso todo e-mail diz no rodapé que não deve ser respondido e indica onde pedir ajuda: o contato de suporte do Varal (configurado na API) para donos e admins, e o responsável pela barraca para colaboradores.
- **RN-01.22** Autenticação do e-mail, configurada em 2026-10-01 (registros na zona do Cloudflare, todos sem proxy):
  - **Return Path** em `bounce.kratinho.com.br` (CNAME para `smtplw.com`): é o envelope dos envios do SMTP Locaweb. O SPF passa nesse subdomínio (`include:_spf.smtplw.com`) e fica alinhado com `kratinho.com.br` para o DMARC. As devoluções vão para a Locaweb, não para o `nao-responda@`.
  - **SPF** do domínio principal: continua só com o Cloudflare Email Routing (`include:_spf.mx.cloudflare.net`). Não acrescente a Locaweb nele.
  - **DKIM** da Locaweb em `smtp._domainkey.bounce.kratinho.com.br`; o DMARC de `bounce` é um CNAME para `_dmarc.smtpdlv.com.br`, mantido pela Locaweb.
  - **DMARC** do domínio em `_dmarc.kratinho.com.br`, gerenciado pelo DMARC Management do Cloudflare (relatórios no painel do Cloudflare). Começa em `p=none`; passa a `quarantine` depois de algumas semanas sem falhas nos relatórios.
- Envio assíncrono por fila no próprio PostgreSQL (**pg-boss**), para que lentidão do SMTP não trave a requisição. Até 3 tentativas no total, com espera crescente. O e-mail é enfileirado na mesma transação da ação que o gera: se a ação for desfeita, nada é enviado. Os dados do job (destinatário e link) ficam cifrados no banco.
- Cada envio grava `email_logs` (destinatário, tipo, situação, erro, datas).
- **RN-01.04** Limite do plano: 10.000 envios por mês (mês no fuso de São Paulo; contam os e-mails na fila e enviados, não os que falharam). Ao atingir 80% (8.000), o admin da plataforma vê um alerta no painel. Ao atingir 100%, envios não críticos param; convites e redefinições continuam e o alerta muda para crítico.
- Nenhum e-mail é disparado por evento operacional (pedido, pagamento, turno).
- Tipos no MVP: `owner_invite`, `owner_password_reset`, `staff_password_reset`, `admin_invite`, `admin_password_reset`.

## 10. Tempo real

- Socket.IO no NestJS, caminho `/ws`, só com o transporte WebSocket (sem long-polling, então sem sticky session). Ping a cada 25 s, dentro do limite de 100 s do Cloudflare. O app conecta com `io(API, { path: '/ws', transports: ['websocket'], withCredentials: true, auth: { deviceId } })`.
- O servidor confere o `Origin` do handshake contra a mesma lista exata de origens da API (RN-01.20), já que o navegador não aplica CORS a WebSocket.
- A conexão é autenticada pelo mesmo cookie de sessão do app (nunca o do admin) e pelo `deviceId` da sessão; sem sessão válida, a conexão é recusada com `connect_error` no formato de erro da API (`UNAUTHENTICATED`, `DEVICE_ID_REQUIRED`).
- Sessão encerrada (logout, troca ou redefinição de senha, desativação) → evento `session.revoked` e desconexão na hora; o app volta ao login. Token de acesso vencido → `session.expired` e desconexão; o app renova por REST e reconecta. Permissões do colaborador alteradas → `session.access_changed` e desconexão; o app reconecta e recarrega o `/auth/me`.
- Salas:
  - `unit:{unitId}` — tudo que acontece na unidade (balcão e painel do dono);
  - `station:{stationId}` — itens que entram, mudam ou saem da fila de uma estação.
- O servidor só coloca o aparelho em salas da organização e das unidades e estações que o usuário pode acessar: o dono em todas as unidades ativas; o colaborador nas unidades e estações das suas permissões. O app pode pedir `rooms.join`/`rooms.leave`, sempre conferido no servidor (`ROOM_FORBIDDEN`).
- As salas são definidas na conexão. Mudança de permissão de um colaborador (spec 03) encerra as sessões dele ou as conexões de tempo real, para valer na hora.
- Eventos têm o envelope `{ type, organizationId, unitId, occurredAt, version, data }` e só são emitidos depois que a transação que os gerou é confirmada. O app ignora eventos com versão menor ou igual à que já tem. Os payloads entram no OpenAPI como schemas `Event…` (RN-01.10).
- No MVP a API roda numa instância só; salas e desconexões ficam na memória do processo. Mais de uma instância exigiria um adapter compartilhado do Socket.IO.
- **RN-01.05** Ao reconectar, o app sempre busca o estado atual por REST (comandas abertas, fila da estação) antes de voltar a aplicar eventos. Eventos perdidos durante a desconexão nunca são necessários para chegar ao estado correto.
- Os eventos de cada módulo estão definidos nas specs 03, 04 e 05.

## 11. Queda de conexão (fila local)

- O app `varal-panel-web` guarda numa fila local (IndexedDB) toda ação operacional que não conseguiu enviar: criar pedido, mudar etapa, cancelar item, registrar pagamento, movimento de caixa.
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

**sessions**: `organization_id` (nulo para admins da plataforma), `subject_type` (`owner`, `staff`, `platform_admin`), `subject_id`, `device_id`, `refresh_token_hash`, `expires_at`, `revoked_at`, `last_used_at`, `user_agent`, `ip`, `impersonation_id` (opcional, spec 02).

**password_tokens**: `subject_type`, `subject_id`, `purpose` (`invite`, `reset`), `token_hash`, `expires_at`, `used_at`.

**audit_logs**: `organization_id` (nulo para ações só da plataforma), `actor_type`, `actor_id`, `impersonator_id` (opcional), `action`, `entity_type`, `entity_id`, `changes jsonb`, `device_id`, `ip`, `request_id` (correlação com o cabeçalho `X-Request-Id`), `created_at`. Sem `updated_at`: a tabela é somente inserção, garantida por trigger no banco. Índices por `(organization_id, created_at)` e `(entity_type, entity_id)`.

**email_logs**: `organization_id` (opcional), `to`, `type`, `status` (`queued`, `sent`, `failed`), `error`, `sent_at`.

**idempotency_keys**: `key`, `organization_id` (opcional), `subject_id`, `request_hash`, `status` (`in_progress`, `completed`), `locked_at`, `response jsonb`, `status_code`, `expires_at`. Uma tentativa `in_progress` abandonada por mais de 60 s pode ser retomada; respostas 5xx não são guardadas.

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
| `POST /api/v1/admin/auth/password/forgot`, `/reset`, `/change` | Senha do admin (pedido, convite ou redefinição, troca) |

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

**App `varal-panel-web`**

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
| `/balcao/paga-antes` | Comanda paga antes: montar pedido e cobrar numa operação | 05 |
| `/estacao/{id}` | Fila de uma estação | 04 |
| `/caixas` | Caixas do turno | 05 |
| `/caixas/{id}/fechar` | Fechamento de caixa | 05 |
| `/painel` | Início do painel do dono | — |
| `/painel/unidades` | Unidades | 03 |
| `/painel/unidades/{id}/fluxo` | Estações e fluxo | 03 |
| `/painel/cardapio` | Cardápio | 03 |
| `/painel/colaboradores` | Colaboradores e permissões | 03 |
| `/painel/acesso-da-equipe` | Código, link e QR | 03 |
| `/painel/turnos` | Abrir turno e turno atual (dono e colaboradores com `can_operate_cash`, RN-04.02; o resto do `/painel` é só do dono) | 04 |
| `/painel/fiado` | Clientes e valores a receber | 06 |
| `/painel/relatorios` | Histórico | 07 |
| `/painel/relatorios/turnos/{id}` | Relatório do turno | 07 |
| `/painel/acessos-de-suporte` | Acessos de "entrar como" na conta | 02 |
| `/entrar-como` | Troca o link do "entrar como" por uma sessão (token no fragmento) | 02 |

**App `varal-admin-web`**

| Rota | Tela |
| --- | --- |
| `/entrar`, `/definir-senha`, `/esqueci-a-senha` | Acesso |
| `/` | Início |
| `/organizacoes`, `/organizacoes/nova`, `/organizacoes/{id}` | Organizações |
| `/comunicados`, `/comunicados/novo`, `/comunicados/{id}` | Comunicados |
| `/metricas` | Métricas |
| `/emails` | E-mails |
| `/auditoria` | Auditoria |
| `/acessos-de-suporte` | Sessões de "entrar como" (em andamento e encerradas) |
| `/usuarios`, `/usuarios/{id}` | Usuários do admin |
| `/papeis`, `/papeis/{id}` | Papéis |

## 15. Critérios de aceite

- **CA-01.01** Com o Postgres de desenvolvimento do `varal-infra` rodando, `scripts/worktree.sh new` em cada repositório de código deixa o projeto rodando localmente; na API, com migrations aplicadas e um seed de exemplo (uma organização, uma unidade com o template padrão, um dono, dois colaboradores, um admin Super admin).
- **CA-01.02** Um colaborador da organização A, com token válido, recebe 404 ao acessar qualquer recurso da organização B, em todos os endpoints (teste automatizado).
- **CA-01.03** O login do colaborador pelo link `/e/{code}` funciona digitando apenas username e senha.
- **CA-01.04** Um token do app `varal-panel-web` é recusado nas rotas `/api/v1/admin` e vice-versa.
- **CA-01.05** Redefinir a senha de um colaborador encerra as sessões abertas dele na hora: a próxima requisição de qualquer aparelho dele é recusada e o WebSocket é desconectado.
- **CA-01.06** Repetir uma requisição de criação com a mesma `Idempotency-Key` não cria registro duplicado e devolve a mesma resposta.
- **CA-01.07** Com o aparelho sem conexão, uma mudança de etapa feita na estação fica na fila local e é aplicada uma única vez quando a conexão volta.
- **CA-01.08** Cada ação listada na seção 8 gera exatamente uma linha de auditoria com ator, aparelho e alterações.
- **CA-01.09** Ao passar de 8.000 envios no mês, o painel do admin mostra o alerta de e-mail.
- **CA-01.11** A CI do `varal-web-api` falha quando o `openapi.json` commitado difere do gerado pelo código.
- **CA-01.12** Os apps compilam com os tipos gerados do `openapi.json` atual; um campo removido da API quebra a compilação do app que o usa.
- **CA-01.13** Em produção, nenhum processo do Varal roda fora de Docker; o Compose do Varal não define serviços `nginx` nem `postgres`; a API conecta com o usuário `varal`.
- **CA-01.14** Os hosts do Varal respondem por HTTPS pelo Cloudflare com SSL Full (strict) sem erro de certificado, e uma ação feita pelo app grava na auditoria o IP real do aparelho, não um IP do Cloudflare.
- **CA-01.15** Um e-mail de convite enviado para Gmail e Outlook chega na caixa de entrada com SPF, DKIM e DMARC aprovados (`pass` no cabeçalho `Authentication-Results`).

## 16. Questões abertas

- E-mail: quando endurecer o DMARC de `p=none` para `quarantine` (depende dos relatórios do Cloudflare).
- Backup: quando entrar e para onde enviar (ex.: Cloudflare R2, bucket S3 compatível, outro servidor).
- Restringir as portas 80/443 do VPS às faixas de IP do Cloudflare. Hoje elas aceitam qualquer origem, e a regra afetaria também os outros projetos do VPS.
