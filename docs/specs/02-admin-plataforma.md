# 02 — Admin da plataforma

## 1. Objetivo

Dar à equipe do Varal um painel próprio, separado dos clientes, para criar e acompanhar organizações, controlar a situação da assinatura, falar com os donos, medir o uso e dar suporte entrando na conta de um cliente.

## 2. Escopo

**Dentro**

- Usuários do admin com RBAC: permissões granulares, papéis como grupos e permissões avulsas.
- Organizações: listar, buscar, ver, criar (com a primeira unidade e o convite do dono), editar, suspender e reativar.
- Situação da assinatura registrada manualmente.
- Comunicados para os donos.
- Métricas de uso.
- Entrar como (acesso total no MVP).
- Consumo e histórico de e-mails.
- Consulta à auditoria.

**Fora**

- Cobrança, planos e limites por plano.
- Funções ligadas por organização.
- Logs de erro e saúde do sistema.
- Permissões finas para o "entrar como".

## 3. RBAC

### 3.1 Regras

- **RN-02.01** Toda rota do admin exige uma permissão do catálogo. Sem a permissão, a API responde 403 e a interface esconde a ação.
- **RN-02.02** Permissão efetiva = união das permissões dos papéis do usuário com as permissões avulsas dele. Não há negação no MVP.
- **RN-02.03** O catálogo de permissões é fixo no código da API e publicado no OpenAPI (enum `Permission`), de onde o `varal-admin-web` o lê. Uma permissão nova entra por deploy; papéis e atribuições são dados.
- **RN-02.04** Os papéis do sistema (`is_system = true`) vêm do seed e não podem ser excluídos. O papel Super admin tem sempre todas as permissões do catálogo, inclusive as que forem criadas depois, e não pode ser editado. Os demais papéis do sistema mantêm o nome, mas descrição e permissões podem mudar. Cada papel do sistema é identificado por `system_key`.
- **RN-02.05** Sempre existe pelo menos um usuário ativo com o papel Super admin. A API recusa desativar ou remover o papel do último (`LAST_SUPER_ADMIN`). Não há exclusão de usuário do admin, só desativação. O primeiro admin é criado por um comando de linha na API (`create-platform-admin`), que lhe dá Super admin quando ainda não há nenhum ativo.
- **RN-02.06** Um usuário não pode alterar os próprios papéis nem as próprias permissões avulsas, nem desativar a si mesmo.
- **RN-02.07** Papéis personalizados podem ser criados, renomeados, ter permissões alteradas e ser excluídos (se nenhum usuário os tiver).
- **RN-02.08** Mudanças de papel ou permissão valem na próxima requisição do usuário afetado.

### 3.2 Catálogo de permissões e papéis do sistema

| Permissão | Permite | Super admin | Suporte | Financeiro | Leitura |
| --- | --- | --- | --- | --- | --- |
| `admin.users:manage` | Convidar, editar, desativar usuários do admin; atribuir papéis e permissões avulsas | Sim | — | — | — |
| `admin.roles:manage` | Criar, editar e excluir papéis personalizados | Sim | — | — | — |
| `organizations:read` | Ver lista e detalhes das organizações | Sim | Sim | Sim | Sim |
| `organizations:create` | Criar organização com unidade e convite do dono | Sim | Sim | — | — |
| `organizations:update` | Editar nome, reenviar convite do dono, trocar o e-mail do dono | Sim | Sim | — | — |
| `organizations:suspend` | Suspender e reativar | Sim | — | Sim | — |
| `subscriptions:update` | Mudar a situação da assinatura | Sim | — | Sim | — |
| `announcements:read` | Ver comunicados e leituras | Sim | Sim | Sim | Sim |
| `announcements:manage` | Criar, editar, agendar, publicar e arquivar comunicados | Sim | Sim | — | — |
| `metrics:read` | Ver métricas | Sim | Sim | Sim | Sim |
| `impersonation:use` | Entrar como o dono de uma organização | Sim | Sim | — | — |
| `emails:read` | Ver consumo e histórico de e-mails | Sim | Sim | — | — |
| `audit:read` | Consultar a auditoria | Sim | — | — | — |

## 4. Organizações e assinatura

- **RN-02.09** Criar organização exige: nome da organização, nome da primeira unidade, nome e e-mail do dono. Na mesma transação são criados a organização (com `access_code`), a unidade com o template padrão de estações e etapas (spec 03), o usuário dono sem senha e o convite por e-mail.
- **RN-02.10** O e-mail do dono não pode já existir em outra organização.
- **RN-02.11** Situações da assinatura: `pilot`, `active`, `suspended`, `canceled`. Toda mudança exige um motivo, que vai para a auditoria (e fica guardado na organização em `suspended` e `canceled`). Suspender só a partir de `pilot` ou `active`; reativar a partir de `suspended` ou `canceled`; pedir a situação atual responde 409. Na criação, a situação é escolhida (padrão `active`).
- **RN-02.12** Efeitos de `suspended` e `canceled`: não é possível abrir turno; turnos abertos podem ser operados até o fechamento; o painel do dono mostra uma faixa explicando a situação. Reativar volta a `active` ou `pilot`.
- Detalhe da organização mostra: situação, data de criação, dono (com situação do convite), unidades, número de colaboradores ativos, últimos 10 turnos, último acesso de qualquer usuário, comunicados não lidos.

## 5. Comunicados

- **RN-02.13** Um comunicado tem título (até 80 caracteres), texto (markdown simples, até 2.000 caracteres), público e data de publicação.
- **RN-02.14** Públicos possíveis: todas as organizações; organizações em uma ou mais situações de assinatura; organizações escolhidas uma a uma.
- **RN-02.15** Situações do comunicado: `draft`, `scheduled`, `published`, `archived`. Um comunicado agendado é publicado automaticamente na data marcada. Depois de publicado, só pode ser arquivado; o texto não muda. O comunicado nasce como rascunho; publicar aceita uma data futura (`scheduled`), e ele aparece para o dono a partir dela. O público "por situação" é avaliado no momento da leitura.
- **RN-02.16** No painel do dono, comunicados publicados e não lidos aparecem numa faixa no topo; o dono abre, lê e marca como lido. A leitura fica registrada por usuário. Leituras feitas durante o "entrar como" não são registradas.
- O admin vê, para cada comunicado, quantos donos do público já leram.

## 6. Métricas

Painel com filtro de período (padrão: últimos 30 dias), em horário de Brasília.

| Métrica | Definição |
| --- | --- |
| Organizações por situação | Contagem atual por situação da assinatura |
| Organizações ativas no período | Com pelo menos um turno aberto no período |
| Turnos | Turnos fechados no período, total e por semana |
| Comandas | Comandas pagas, penduradas ou quitadas no período |
| Valor vendido registrado | Soma do total das comandas pagas, penduradas ou quitadas no período, em reais |
| Ticket médio | Valor vendido / comandas |
| Uso por organização | Tabela com turnos, comandas, valor vendido e último acesso, ordenável |

As métricas usam só dados já existentes; não há tabela própria no MVP. Turnos, comandas e valores aparecem zerados até as specs 04 a 06 estarem implementadas. O último acesso vem das sessões, que são apagadas 30 dias depois de vencidas.

## 7. Entrar como

- **RN-02.17** O admin escolhe a organização e confirma; não há motivo a informar. A sessão "entrar como" não tem prazo: dura até o admin encerrar, no admin ou pelo "Encerrar acesso" no app.
- **RN-02.18** No MVP o acesso é total: o admin age no app `varal-panel-web` com as mesmas permissões do dono daquela organização.
- **RN-02.19** Durante a sessão, uma faixa fixa e destacada no topo do app mostra "Você está acessando como {organização} — {admin}" e o botão "Encerrar acesso". Como não há prazo, a faixa não mostra tempo restante.
- **RN-02.20** Toda ação feita na sessão grava na auditoria o ator como o dono e `impersonator_id` com o admin, mais o id da sessão de "entrar como".
- **RN-02.21** A sessão é aberta num cookie próprio do app `varal-panel-web`, emitido a partir do admin; ela não dá acesso a outras organizações nem ao admin. Fluxo:
  1. `POST /admin/impersonations` cria a sessão (sem prazo) e devolve um link `{painel}/entrar-como#token=...`, de uso único, válido por 2 minutos, guardado só como hash. A validade do link protege só a entrega dele; não limita o acesso.
  2. A página `/entrar-como` do painel troca o token por uma sessão do app (`POST /auth/impersonation`), e a API exige que o mesmo navegador tenha a sessão do admin que gerou o link: um link vazado não funciona em outro navegador.
  3. A sessão do app não é limitada por prazo (segue as regras normais de renovação da spec 01), mas termina junto com o "entrar como": encerrar pelo admin ou pelo "Encerrar acesso" no app derruba a sessão e o tempo real na hora. Trocar a senha do dono durante o acesso é recusado.
- **RN-02.22** O dono vê, no próprio painel, a lista de acessos de suporte feitos na conta dele (admin, início e fim; o motivo só aparece nos acessos antigos, em que era informado).

## 8. E-mails e auditoria

- Tela de e-mails: consumo do mês (barra contra 10.000, alerta a partir de 8.000), lista filtrável por tipo, situação, organização e período, com o erro quando houver falha.
- Tela de auditoria: lista filtrável por organização, ator, ação, entidade e período, com o detalhe das alterações.

## 9. Modelo de dados

**platform_admins**: `name`, `email` (único), `password_hash`, `active`, `last_login_at`.

**roles**: `name` (único), `description`, `is_system bool`, `system_key` (nos papéis do sistema).

**role_permissions**: `role_id`, `permission` (chave do catálogo). Único por par.

**platform_admin_roles**: `platform_admin_id`, `role_id`. Único por par.

**platform_admin_permissions** (avulsas): `platform_admin_id`, `permission`. Único por par.

**announcements**: `title`, `body`, `audience_type` (`all`, `by_status`, `selected`), `audience_statuses text[]`, `status`, `publish_at ts`, `published_at ts`, `archived_at ts`, `created_by`.

**announcement_targets**: `announcement_id`, `organization_id` (só para `selected`).

**announcement_reads**: `announcement_id`, `organization_id`, `user_id`, `read_at`. Único por par.

**impersonation_sessions**: `platform_admin_id`, `organization_id`, `owner_id`, `reason` (opcional), `started_at`, `expires_at` (opcional), `ended_at`, `ended_by` (`admin`, `expired`), e o hash e a validade do link de troca. `audit_logs` ganha `impersonation_id`. `reason`, `expires_at` e `ended_by = expired` ficam só por compatibilidade, no histórico dos acessos feitos quando havia motivo e limite de 60 minutos; acessos novos não têm motivo nem prazo e terminam só por `admin`.

## 10. API

Todas sob `/api/v1/admin`, com a permissão exigida entre colchetes. As permissões também aparecem no OpenAPI (`x-permissions`). Escritas do admin não usam `Idempotency-Key`.

| Método e rota | Permissão |
| --- | --- |
| `GET /users`, `GET /users/{id}` | `admin.users:manage` |
| `POST /users` (convite) | `admin.users:manage` |
| `PATCH /users/{id}` (nome, ativo) | `admin.users:manage` |
| `PUT /users/{id}/roles`, `PUT /users/{id}/permissions` | `admin.users:manage` |
| `POST /users/{id}/password-link` (link de redefinição) | `admin.users:manage` |
| `GET /roles`, `POST /roles`, `PATCH /roles/{id}`, `DELETE /roles/{id}` | `admin.roles:manage` (leitura também com `admin.users:manage`) |
| `GET /permissions` (catálogo) | qualquer admin |
| `GET /organizations`, `GET /organizations/{id}` | `organizations:read` |
| `POST /organizations` | `organizations:create` |
| `PATCH /organizations/{id}` | `organizations:update` |
| `POST /organizations/{id}/owner-invite` (reenviar) | `organizations:update` |
| `POST /organizations/{id}/suspend`, `/reactivate` | `organizations:suspend` |
| `PUT /organizations/{id}/subscription-status` | `subscriptions:update` |
| `GET /announcements`, `GET /announcements/{id}` | `announcements:read` |
| `POST /announcements`, `PATCH /announcements/{id}`, `POST /announcements/{id}/publish`, `/archive` | `announcements:manage` |
| `GET /metrics/overview`, `GET /metrics/organizations` | `metrics:read` |
| `POST /impersonations` (só a organização; sem motivo nem prazo), `GET /impersonations` | `impersonation:use` |
| `POST /impersonations/{id}/end` | o próprio admin da sessão |
| `GET /emails`, `GET /emails/usage` | `emails:read` |
| `GET /audit-logs` | `audit:read` |

No `varal-panel-web` (lado do dono):

| Método e rota | Descrição |
| --- | --- |
| `GET /api/v1/announcements/unread` | Comunicados publicados, do público do dono, ainda não lidos |
| `POST /api/v1/announcements/{id}/read` | Marca como lido |
| `GET /api/v1/support-access` | Acessos de suporte feitos na organização (admin, início e fim; motivo se houver) |
| `POST /api/v1/auth/impersonation` | Troca o link do "entrar como" por uma sessão do app (RN-02.21) |

## 11. Telas

| Tela | Conteúdo e ações |
| --- | --- |
| Início | Cartões com organizações por situação, alerta de e-mail, atalhos |
| Organizações | Lista com busca por nome, e-mail do dono ou código; filtro por situação; botão "Nova organização" |
| Organização | Detalhe (seção 4), botões Suspender/Reativar, Mudar situação, Reenviar convite, Entrar como |
| Comunicados | Lista por situação; editor com prévia; escolha de público; agendamento; contagem de leituras |
| Métricas | Indicadores do período e tabela de uso por organização |
| E-mails | Consumo do mês e histórico |
| Auditoria | Busca com filtros |
| Usuários do admin | Lista, convite, papéis e permissões avulsas de cada usuário, com a lista de permissões efetivas |
| Papéis | Lista de papéis, matriz de permissões, criação de papel personalizado |

Ações sem permissão não aparecem na interface.

## 12. Critérios de aceite

- **CA-02.01** Um admin só com o papel Leitura vê organizações e métricas, mas a API recusa com 403 criar organização, suspender ou entrar como.
- **CA-02.02** Dar a um usuário Leitura a permissão avulsa `organizations:create` permite que ele crie organizações, sem ganhar outras permissões.
- **CA-02.03** A API recusa desativar o último Super admin ativo.
- **CA-02.04** Criar uma organização gera unidade com o template padrão, `access_code` único e e-mail de convite; o dono define a senha pelo link e entra no painel.
- **CA-02.05** Suspender uma organização impede abrir turno (erro `ORGANIZATION_SUSPENDED`) e mostra a faixa no painel do dono; um turno que já estava aberto continua operando até ser fechado.
- **CA-02.06** Um comunicado agendado para todas as organizações aparece para os donos na data marcada e some da faixa depois de marcado como lido.
- **CA-02.07** Durante um "entrar como", uma alteração no cardápio fica na auditoria com o admin em `impersonator_id`, e a faixa de aviso fica visível em todas as telas.
- **CA-02.08** A sessão "entrar como" termina quando o admin encerra (no admin ou pelo "Encerrar acesso" no app), sem prazo; depois disso, as requisições com aquele cookie são recusadas.
- **CA-02.09** O dono vê na lista de acessos de suporte o acesso feito, com o admin e os horários.

## 13. Questões abertas

- Permissões finas do "entrar como" (só leitura × alteração) — decidido adiar.
- Métricas adicionais (receita recorrente, cancelamentos) dependem da cobrança, fora do MVP.
