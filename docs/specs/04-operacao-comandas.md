# 04 — Operação e comandas

## 1. Objetivo

Operar uma barraca no dia a dia: vender no balcão enquanto houver caixa aberto, registrar comandas e pedidos, aplicar a tabela de preço vigente (e a de um evento contratado, quando houver), fazer cada item chegar à estação certa em tempo real e acompanhar o preparo até a entrega.

> **Mudança de 2026-10-02 (redesenho pós-teste):** o turno deixou de existir. O que começa e termina o dia é **abrir e fechar o caixa** (spec 05). Os preços do turno viraram **tabelas de preço** salvas no cardápio (spec 03) e o turno contratado virou o **evento** (seção 3.3). Regras removidas mantêm o número, marcadas como removidas, para que as citações em código e testes continuem rastreáveis.

## 2. Escopo

**Dentro**

- Operação da unidade: dia de operação, tabela de preço vigente, eventos contratados.
- Comandas "paga antes" e "comanda aberta", com número e nome do cliente; comandas abertas que passam de um dia para o outro.
- Pedidos e itens com modificadores e observação.
- Fluxo dos itens pelas etapas, cancelamento e perda.
- Telas de balcão, de estação (KDS) e de eventos, com tempo real, alertas e tela sempre ligada.

**Fora** (outras specs)

- Caixas, abertura e fechamento de caixa, pagamentos e desconto: spec 05.
- Pendurar no fiado: spec 06.
- Relatórios do dia, do caixa e do evento: spec 07.
- Cadastro das tabelas de preço: spec 03.

## 3. Operação da unidade

- **RN-04.01** A unidade está **em operação** enquanto tiver pelo menos um caixa aberto (spec 05, seção 5). Não há turno: abrir o primeiro caixa começa o dia e fechar o último o termina.
- **RN-04.02** Abrir comanda (aberta ou paga antes) e lançar pedido exigem a unidade em operação; sem caixa aberto, a API recusa com `NO_CASH_REGISTER_OPEN`. As demais ações sobre comandas que já existem (avançar, voltar e cancelar item, pedir a conta, reabrir, desconto, pendurar, cancelar comanda) não dependem de caixa aberto. Receber pagamento depende (spec 05, RN-05.06).
- **RN-04.03** Organização `suspended` ou `canceled` (spec 02) não abre caixa (spec 05, RN-05.24), então não começa um dia novo. Caixas já abertos continuam operando até serem fechados.
- **RN-04.04** *(removida em 2026-10-02: tipo do turno. O atendimento contratado é o evento, seção 3.3.)*
- **RN-04.07** *(reescrita em 2026-10-02)* Comandas em `open` ou `closing` nunca impedem fechar um caixa. Elas continuam abertas, aparecem como pendentes no fechamento (spec 05, RN-05.20) e seguem no varal no próximo dia, com o mesmo número.
- **RN-04.08** *(reescrita em 2026-10-02)* Ao fechar o **último** caixa aberto da unidade, os itens que ainda estiverem em etapas não finais aparecem na confirmação do fechamento. Por padrão eles são levados à etapa final ("Encerrar o preparo pendente", marcado), com registro na auditoria, para que a cozinha comece o dia seguinte com a tela limpa; quem fecha pode desmarcar, e os itens continuam na fila.

### 3.1 Dia de operação

- **RN-04.29** A unidade tem um **dia de operação** (`business_date`, data no fuso `America/Sao_Paulo`). Ele muda quando um caixa é aberto, nenhum outro caixa da unidade está aberto e a data de hoje é diferente do dia de operação atual: nesse momento o dia de operação passa a ser hoje e a numeração das comandas volta a 1. Uma feira que passa da meia-noite continua no mesmo dia de operação até o último caixa fechar; fechar e reabrir o caixa no mesmo dia (almoço e jantar) mantém o dia e a numeração.
- **RN-04.30** Comandas, aberturas de caixa e cancelamentos de item guardam o dia de operação do momento em que aconteceram. É por ele que os relatórios agrupam por dia (spec 07).

### 3.2 Tabela de preço vigente

- **RN-04.06** *(reescrita em 2026-10-02)* A unidade tem uma **tabela vigente**: "Normal" (o preço normal do cardápio) ou uma das tabelas de preço ativas da unidade (spec 03, seção 5.3). Ela vale para os itens enviados a partir da troca; itens já enviados guardam o preço do momento (RN-04.18).
- **RN-04.31** Trocam a tabela vigente: o dono e colaboradores com `can_operate_cash` na unidade, com ou sem caixa aberto. A troca é um toque (Normal ↔ Evento), fica registrada na auditoria e chega a todos os balcões em tempo real. A tabela vigente continua a mesma de um dia para o outro até ser trocada; ao abrir o primeiro caixa do dia com uma tabela diferente de "Normal", a tela de abertura avisa qual está vigente e oferece voltar para "Normal".
- **RN-04.32** Enquanto houver um evento em andamento (seção 3.3), a **tabela efetiva** é a do evento (ou "Normal", se o evento não tiver tabela) e a troca manual fica bloqueada (`EVENT_IN_PROGRESS`). Quando o evento termina, volta a valer a tabela vigente da unidade.
- **RN-04.33** O balcão mostra sempre a tabela efetiva (ex.: "Preços: Evento"), no topo do varal e da montagem do pedido, com destaque quando for diferente de "Normal". Os preços dos botões de produto já são os da tabela efetiva.

### 3.3 Evento contratado

Um evento é um atendimento combinado com um contratante (casamento, festa de empresa). É um cadastro opcional da unidade: quem não cadastra eventos nunca vê nada disso no balcão.

- **RN-04.05** *(reescrita em 2026-10-02)* O evento tem: nome do contratante (obrigatório, até 60 caracteres), data (obrigatória) e data final opcional (eventos de mais de um dia), acordo e tabela de preço opcional (ativa, da mesma unidade). O acordo tem modalidade, valor combinado (centavos, opcional), quantidade combinada (inteiro, opcional, usada na comparação do relatório), limites (texto livre, opcional, ex.: "500 espetos" ou "das 18h às 23h") e observação. Modalidades: `fixed_fee` (valor fixo), `per_quantity` (por quantidade), `consumption_billed` (contratante paga o consumo no final), `other`. No MVP o acordo é informativo: nada é calculado a partir dele além da comparação do relatório (spec 07).
- **RN-04.34** Situações do evento: `scheduled` (agendado) → `in_progress` (em andamento) → `finished` (encerrado); `scheduled` → `canceled`. Cadastram, editam e cancelam eventos: o dono. Iniciam e encerram: o dono e colaboradores com `can_operate_cash`. Um evento encerrado ou cancelado não volta.
- **RN-04.35** A unidade tem no máximo um evento em andamento (`EVENT_ALREADY_IN_PROGRESS`). Iniciar não exige caixa aberto, mas a abertura do caixa oferece iniciar o evento agendado para hoje ("Hoje tem o evento Casamento Ana e Leo. Iniciar junto?"), e o fechamento do último caixa oferece encerrar o evento em andamento.
- **RN-04.36** Enquanto o evento está em andamento, toda comanda nova da unidade fica ligada a ele (`event_id`) e os itens usam a tabela do evento (RN-04.32). Comandas abertas antes do início não mudam de evento, nem as abertas durante o evento depois que ele termina.
- **RN-04.37** Editar o acordo e a tabela de preço é permitido até o evento ser encerrado; trocar a tabela de um evento em andamento vale para itens novos.
- **RN-04.15** *(reescrita em 2026-10-02)* Num evento com modalidade `consumption_billed`, o consumo do contratante é lançado em comandas abertas normais, normalmente uma com o nome do contratante; no fechamento ela é pendurada (spec 06, RN-06.08).

## 4. Comanda

- **RN-04.09** *(reescrita em 2026-10-02)* Toda comanda pertence a uma unidade e tem um número atribuído pela API, sequencial no dia de operação (RN-04.29), começando em 1. Ao numerar, a API pula os números de comandas de dias anteriores que ainda estejam em `open` ou `closing`: entre as comandas em aberto da unidade, o número nunca se repete. A comanda guarda o dia de operação em que foi aberta.
- **RN-04.10** Nome do cliente é obrigatório, de 1 a 40 caracteres. O balcão mostra sempre "número + nome" (ex.: "12 · Dona Marta"). Uma comanda aberta em dia anterior mostra também a data ("12 · Dona Marta · desde 01/10").
- **RN-04.11** Modos:
  - `pay_first` (paga antes): o balcão monta o pedido, recebe o pagamento e só então o pedido é enviado às estações. A comanda vai direto para `paid` ao enviar. Ela tem um único pedido.
  - `open_tab` (comanda aberta): recebe vários pedidos enquanto estiver `open` e é paga no fechamento (spec 05).
- **RN-04.12** Situações e transições:

| De | Para | Quando |
| --- | --- | --- |
| — | `open` | Comanda aberta é criada |
| — | `paid` | Comanda paga antes é criada com o pedido pago (spec 05) |
| `open` | `closing` | Balcão pede a conta |
| `closing` | `open` | Balcão reabre (cliente pediu mais) |
| `closing` | `paid` | Total pago igual ao total devido (spec 05) |
| `closing` | `on_credit` | Pendurada no fiado (spec 06) |
| `on_credit` | `settled` | Quitada (spec 06) |
| `open` ou `closing` | `canceled` | Todos os itens cancelados e nenhum pagamento registrado (senão `TAB_HAS_ACTIVE_ITEMS`; a comanda não cancela os itens sozinha) |

- **RN-04.13** Em `closing`, novos pedidos são recusados até reabrir.
- **RN-04.14** Valores da comanda: subtotal = soma dos itens não cancelados (preço unitário + acréscimos dos modificadores, vezes a quantidade); total = subtotal − desconto (spec 05).
- **RN-04.38** Quando a comanda sai de `open`/`closing` para `paid`, `on_credit` ou `canceled`, ela guarda o dia de operação desse momento (`closed_business_date`), usado na venda do dia (spec 07).

## 5. Pedido e itens

- **RN-04.16** Um pedido tem de 1 a 50 itens. Cada item: produto, quantidade de 1 a 99, modificadores escolhidos, observação opcional (até 140 caracteres).
- **RN-04.17** O pedido é recusado se algum produto estiver inativo ou esgotado, ou se faltar escolha em grupo obrigatório. A resposta aponta quais itens.
- **RN-04.18** *(ajustada em 2026-10-02)* No envio, cada item grava uma cópia do que foi vendido: nome do produto, preço unitário (o da tabela efetiva da unidade no momento do envio, RN-04.32, ou o preço normal quando o produto não tem preço nessa tabela), a tabela usada (`price_list_id`, nulo para "Normal"), nome e acréscimo de cada modificador, estação de preparo resolvida (spec 03, RN-03.08). Mudanças posteriores no cardápio, nas tabelas ou na tabela vigente não alteram itens já enviados.
- **RN-04.19** Todo item entra na primeira etapa do fluxo da unidade. A estação em que ele aparece é calculada pela etapa (spec 03, seção 4.2).
- Situações do pedido: `sent` enquanto houver item em etapa não final; `completed` quando todos os itens estiverem na etapa final ou cancelados.

### 5.1 Etapas

- **RN-04.20** Avançar um item move para a próxima etapa do fluxo. Pode avançar quem tem acesso à estação em que o item está.
- **RN-04.21** No balcão (`counter`), o colaborador também pode avançar itens que estejam na última etapa antes da final (no template: Pronto → Entregue), para registrar a entrega direto na comanda.
- **RN-04.22** Voltar um item para a etapa anterior é permitido para quem pode avançá-lo e também para quem tem acesso à estação da etapa anterior (quem avançou por engano consegue desfazer), com registro na auditoria. Não se volta da etapa final.
- **RN-04.23** *(ajustada em 2026-10-02)* O item guarda quando entrou na etapa atual. Ele está **em atenção** quando passou mais de `attention_after_minutes` e **atrasado** quando passou mais de `late_after_minutes` desde o envio do pedido sem chegar à etapa final, com os limites da estação em que ele está (spec 03, RN-03.25). No balcão, que não tem limites próprios, vale o atraso da estação de preparo do item.
- **RN-04.46** O cartão do pedido na estação (RN-04.40) tem três níveis de tempo, pelo pior nível entre as suas linhas pendentes: **normal**, **atenção** e **atrasado**. Os níveis mudam sozinhos com o relógio do aparelho, sem esperar evento da API, e sempre aparecem com texto e ícone (spec 08, seção 4).
- **RN-04.24** Avançar parte da quantidade: num item com quantidade maior que 1, quem avança pode escolher quantas unidades seguem (ex.: 2 de 3 espetos prontos); o padrão é todas. Avançar parte divide o item em duas linhas, como no cancelamento parcial (RN-04.26): uma linha nova, com a quantidade avançada, vai para a próxima etapa e aponta para a original em `split_from_id`; a original fica na etapa atual com o restante e mantém `stage_entered_at`. As duas linhas guardam a mesma cópia do vendido, e o total da comanda não muda. Voltar etapa (RN-04.22) vale para cada linha separadamente.
- **RN-04.39** Avançar o pedido inteiro na estação: o cartão do pedido (RN-04.40) tem uma ação que avança, de uma vez, todas as linhas desse pedido que ainda estão na estação. A API trata como uma operação só (todas ou nenhuma), conferindo a `version` de cada linha; se alguma mudou em outro aparelho, responde `409 ITEM_CHANGED` com o estado atual e nada é aplicado. Cada linha vai para a próxima etapa da sua etapa atual.

### 5.2 Pedido na estação: um pedido, um cartão

Decisão do usuário (2026-10-02): em KDS que quebram o pedido em um cartão por item, a cozinha perde a noção do pedido. No Varal, toda estação mostra o pedido inteiro num cartão só.

- **RN-04.40** Em toda estação `queue`, um pedido aparece em **um único cartão**, com todas as linhas desse pedido que pertencem à estação (as que estão, ou estiveram desde que o cartão apareceu, numa etapa ligada a ela). Nunca há um cartão por item.
- **RN-04.41** Tocar numa linha avança só aquela linha (RN-04.20). Se a próxima etapa ainda é desta estação (no template: Recebido → Preparando, ambas na Cozinha), a linha continua no cartão com o chip da etapa nova. Se a linha sai da estação (Preparando → Pronto, que vai para o Balcão de entrega), ela continua no cartão **marcada como feita** (riscada, com ícone de confirmação), sem ação, até o cartão sair.
- **RN-04.42** O cartão sai da estação quando todas as suas linhas saíram dela (avançadas para etapa de outra estação ou para a etapa final) ou foram canceladas. Com o filtro por etapa (seção 8.2), o cartão aparece na etapa de cada uma das suas linhas pendentes e sai do filtro de uma etapa quando nenhuma linha está mais nela.
- **RN-04.43** Linhas do mesmo pedido que são de outra estação não aparecem nesta. O cartão mostra, discretamente, "+ N itens em outra estação" (N = unidades ativas do pedido que estão em etapas de outras estações), para contexto; a resposta da fila traz esse número por pedido.
- **RN-04.44** Itens lançados depois na mesma comanda formam um pedido novo (RN-04.16), logo um cartão novo, marcado como **"Adicional"** com o número do pedido na comanda ("Adicional · pedido 2 da comanda 12"). O cartão do pedido anterior não muda.
- **RN-04.45** Uma linha cancelada enquanto o cartão está na estação continua visível no cartão, riscada, com o chip "Cancelado" (spec 08) em destaque e o motivo, até o cartão sair; se todas as linhas pendentes forem canceladas, o cartão fica com o destaque de cancelamento e só sai quando alguém toca em "Ciente". O cancelamento chega à estação com som e vibração, como item novo.

### 5.3 Cancelamento de item

- **RN-04.25** Qualquer colaborador com acesso ao balcão ou à estação do item pode cancelar, com motivo obrigatório (até 140 caracteres).
- **RN-04.26** Pode-se cancelar parte da quantidade: o item é dividido em uma linha cancelada com a quantidade cancelada e uma linha ativa com o restante.
- **RN-04.27** Item cancelado depois de sair da primeira etapa é marcado como perda (`wasted = true`), para o relatório. O item cancelado guarda o dia de operação do cancelamento (RN-04.30).
- **RN-04.28** Não se cancela item de comanda `paid`, `on_credit`, `settled` ou `canceled`. Na comanda paga antes, o cancelamento depois do pagamento é tratado como estorno (spec 05).
- Item na etapa final (entregue) pode ser cancelado enquanto a comanda estiver `open` ou `closing` (ex.: devolução), também contando como perda.

## 6. Modelo de dados

Toda tabela tem `organization_id`.

**units** (spec 03) ganha: `business_date date` (dia de operação, RN-04.29, nulo até o primeiro caixa ser aberto), `next_tab_number int` (próximo número no dia), `current_price_list_id` (tabela vigente, nulo = "Normal"), `operation_version int` (versão do evento `unit.operation_updated`).

**contracted_events**: `unit_id`, `contractor_name`, `starts_on date`, `ends_on date` (opcional, ≥ `starts_on`), `price_list_id` (opcional), `modality`, `agreed_amount_cents`, `agreed_quantity`, `limits`, `notes`, `status` (`scheduled`, `in_progress`, `finished`, `canceled`), `started_at`, `started_by_type`, `started_by_id`, `finished_at`, `finished_by_type`, `finished_by_id`, `version int`. Índice único parcial: um `in_progress` por `unit_id`.

**tabs**: `unit_id`, `number int`, `business_date date` (dia de operação da abertura), `closed_business_date date` (RN-04.38), `event_id` (opcional), `customer_name`, `mode` (`pay_first`, `open_tab`), `status`, `discount_type` (`amount`, `percent`, nulo), `discount_value int`, `discount_reason`, `customer_id` (spec 06), `opened_by_type`, `opened_by_id`, `closed_at`, `version int`. Índice único parcial `(unit_id, number)` entre as comandas em `open` ou `closing` (RN-04.09); índice `(unit_id, business_date)`.

**orders**: `tab_id`, `number_in_tab int`, `status` (`sent`, `completed`), `created_by_type`, `created_by_id`, `sent_at`, `completed_at`.

**order_items**: `order_id`, `tab_id`, `product_id`, `product_name`, `unit_price_cents`, `price_list_id` (opcional, RN-04.18), `quantity`, `note`, `prep_station_id`, `stage_id`, `stage_entered_at`, `canceled_at`, `canceled_business_date`, `canceled_by_type`, `canceled_by_id`, `cancel_reason`, `wasted bool`, `split_from_id` (opcional), `version int`.

**order_item_modifiers**: `order_item_id`, `modifier_id`, `group_name`, `modifier_name`, `price_delta_cents`.

O "valor de um item" é `(unit_price_cents + soma de price_delta_cents) × quantity`.

Tabelas que saem com o redesenho (migração no plano de desenvolvimento, fase 7.5): `shifts`, `shift_agreements` (vira `contracted_events`) e `shift_prices` (vira tabela de preço, spec 03). As colunas `shift_id` de `tabs`, `orders` e `payments` ficam só enquanto a migração de contração não roda.

## 7. API

| Método e rota | Descrição |
| --- | --- |
| `GET /api/v1/units/{id}/operation` | Situação da operação: dia de operação, caixas e aberturas em andamento (spec 05), tabela vigente e efetiva, evento em andamento e agendados para hoje, contadores de comandas em aberto (incluindo as de dias anteriores), as comandas abertas há mais de 2 dias (`staleTabs`, spec 01, RN-01.28) e o número de itens em preparo. Usada pelo início do painel e pelo balcão |
| `PUT /api/v1/units/{id}/current-price-list` | Troca a tabela vigente (`priceListId` ou `null` para "Normal"); RN-04.31 e RN-04.32 |
| `GET /api/v1/units/{id}/events?status=&from=&to=` | Eventos da unidade |
| `POST /api/v1/units/{id}/events` | Cadastra evento (dono) |
| `GET /api/v1/events/{id}`, `PATCH /api/v1/events/{id}` | Detalhe e edição (RN-04.37) |
| `POST /api/v1/events/{id}/start`, `/finish`, `/cancel` | Inicia, encerra, cancela (RN-04.34, RN-04.35) |
| `GET /api/v1/units/{id}/tabs?status=open,closing` | Varal: comandas em aberto da unidade, de qualquer dia, com totais e resumo dos itens (sem paginação: o varal precisa de todas) |
| `POST /api/v1/units/{id}/tabs` | Abre comanda aberta (`customerName`); RN-04.02 |
| `POST /api/v1/units/{id}/tabs/pay-first` | Cria comanda paga antes com pedido e pagamentos em uma operação (spec 05) |
| `GET /api/v1/tabs/{id}` | Comanda com pedidos, itens, pagamentos e totais |
| `POST /api/v1/tabs/{id}/orders` | Novo pedido na comanda aberta; RN-04.02 |
| `POST /api/v1/tabs/{id}/request-bill` | `open` → `closing` |
| `POST /api/v1/tabs/{id}/reopen` | `closing` → `open` |
| `POST /api/v1/tabs/{id}/cancel` | Cancela comanda (RN-04.12) |
| `GET /api/v1/stations/{id}/queue` | Pedidos da fila da estação, mais antigos primeiro, cada um com as suas linhas da estação (pendentes, feitas e canceladas desde que o pedido entrou nela, RN-04.40 a RN-04.45), o número do pedido na comanda e `otherStationsQuantity` (RN-04.43) |
| `POST /api/v1/order-items/{id}/advance` | Próxima etapa; `quantity` opcional para avançar parte (RN-04.24), devolvendo as duas linhas |
| `POST /api/v1/orders/{id}/advance` | Avança as linhas do pedido numa estação e etapa (`stationId`, `stageId`, `items: [{ id, version }]`); RN-04.39 |
| `POST /api/v1/order-items/{id}/back` | Etapa anterior |
| `POST /api/v1/order-items/{id}/cancel` | Cancela (`quantity`, `reason`) |

Saem: as rotas de `/shifts` (abrir, turno atual, preços do turno, fechar, comandas do turno).

Todas as rotas de escrita aceitam `Idempotency-Key` (spec 01). Mudanças de etapa e cancelamentos enviam a `version` conhecida do item; se outro aparelho já mudou o item, a API responde `409 ITEM_CHANGED` com o estado atual, e o app atualiza o cartão sem aplicar a ação.

### 7.1 Eventos em tempo real

| Evento | Salas | Payload |
| --- | --- | --- |
| `unit.operation_updated` | `unit` | situação da operação (mesmo formato do `GET /units/{id}/operation`) com `operation_version`; sai ao abrir ou fechar caixa, trocar a tabela vigente, iniciar ou encerrar evento e mudar o dia de operação (os balcões recarregam os preços) |
| `event.updated` | `unit` | evento com situação e `version` |
| `tab.created` | `unit` | comanda com totais |
| `tab.updated` | `unit` | comanda com situação, totais, contadores de itens prontos e atrasados e `version`; também sai quando uma mudança de etapa altera esses contadores |
| `order.created` | `unit` e `station` de cada item | pedido com itens (cada estação recebe só os seus) |
| `order_item.stage_changed` | `unit`, `station` de origem e de destino | item com etapa nova e `version` (no avanço do pedido inteiro, um evento por linha) |
| `order_item.canceled` | `unit` e `station` atual | item cancelado |
| `order.completed` | `unit` | `orderId`, `tabId` |

Saem: `shift.opened`, `shift.closed` e `shift.updated`.

## 8. Telas

### 8.1 Balcão (estação `counter`)

- **Faixa de operação** (topo do varal e da montagem do pedido): caixa aberto ("Caixa 1 aberto"), tabela efetiva ("Preços: Normal" ou, em destaque, "Preços: Evento") e evento em andamento ("Evento: Casamento Ana e Leo"). Para quem pode trocar a tabela (RN-04.31), tocar na tabela abre a escolha com as tabelas ativas; durante um evento, a escolha explica que a tabela é a do evento.
- **Sem caixa aberto:** o varal continua mostrando as comandas em aberto (podem ser atendidas, RN-04.02), mas "Nova comanda" e "Novo pedido" ficam desativados com a mensagem "Abra um caixa para vender". Quem opera caixa vê o botão principal "Abrir caixa" (leva a `/caixas`); os outros veem "Peça para quem cuida do caixa abri-lo".
- **Varal de comandas** (tela inicial): abas Abertas, Fechando e Fiado com contadores; cartões com número grande, nome, total, quantidade de itens e um sinal quando houver item pronto para entregar; comandas de dias anteriores com a data; busca por número ou nome; botão fixo "Nova comanda".
- **Nova comanda**: escolha entre "Comanda aberta" e "Paga antes" e nome do cliente. Com evento em andamento, mostra "Esta comanda é do evento {contratante}".
- **Montar pedido**: categorias em abas, produtos em botões grandes com o preço da tabela efetiva (esgotados bloqueados), folha de modificadores ao tocar no produto, observação, carrinho com quantidades e total; botão "Enviar pedido" (comanda aberta) ou "Cobrar e enviar" (paga antes).
- **Comanda**: pedidos com itens e a etapa de cada um, botão "Entregue" nos itens prontos, cancelar item, "Novo pedido", "Pedir conta", e em `closing` "Reabrir" e "Receber" (spec 05).
- Navegação de volta e troca de estação: spec 01, seção 14.2.

### 8.2 Estação (`queue`): tela de cozinha (KDS)

Inspirada nos KDS de mercado (Toast, Square, Fresh KDS, Oracle MICROS): pedidos como tickets em colunas, ordem de chegada, tempo em destaque, um toque para avançar.

**Cartão (ticket)**: um por pedido, nunca um por item (RN-04.40 a RN-04.45).

- **Cabeçalho:** número da comanda em letra grande e nome do cliente ("12 · Dona Marta"); "Adicional · pedido 2" quando não for o primeiro pedido da comanda (RN-04.44); hora do envio e tempo decorrido (`mm:ss`, atualizado a cada segundo; `h:mm` passada uma hora); o modo ("Paga antes") quando for. O cabeçalho usa a cor de status (spec 08, seção 4): "Novo" enquanto o cartão não for tocado; depois, o nível de tempo (RN-04.46): neutro no normal, "Atenção" (laranja, com ícone de ampulheta) a partir do limite de atenção da estação e "Atrasado" (com os minutos) a partir do limite de atraso. Um cartão novo que entra em atenção ou atraso antes de ser tocado mostra a cor do tempo, com a marca "Novo" mantida como chip.
- **Linhas:** quantidade e produto em 20 px negrito; modificadores logo abaixo, um por linha; observação em destaque, em bloco próprio com ícone e o texto "Obs.:"; chip da etapa da linha. Linha que saiu da estação fica riscada com ícone de confirmação (RN-04.41); linha cancelada fica riscada com o chip "Cancelado" e o motivo (RN-04.45).
- **Rodapé do cartão:** "+ N itens em outra estação", em texto secundário, quando houver (RN-04.43).
- **Avançar:**
  - tocar numa linha avança só aquela linha (RN-04.41); com quantidade maior que 1, o toque longo (ou o menu da linha) abre "Quantas seguem?" (RN-04.24);
  - o botão grande no rodapé do cartão avança todas as linhas que ainda estão na estação (RN-04.39), com o nome da próxima etapa quando todas vão para a mesma ("Começar", "Pronto") ou "Avançar tudo" quando não;
  - menu secundário do cartão e da linha: voltar etapa (RN-04.22) e cancelar com motivo (RN-04.25).
- **Desfazer:** quando um cartão sai da tela, aparece por 5 segundos o aviso "Comanda 12 · Pronto — Desfazer" (volta as linhas com RN-04.22). O botão "Recentes" no topo lista os últimos 10 pedidos que saíram desta estação, para voltar um deles.

**Grade:**

- Celular (até 640 px): uma coluna, cartões em lista vertical, mais antigo no topo.
- Tablet, TV e computador: colunas de largura fixa (cerca de 300 px, ajustável em "Tamanho do cartão": pequeno, médio, grande) que ocupam **toda a largura da tela**, sem margem de conteúdo centralizado. A ordem é por chegada, da esquerda para a direita e de cima para baixo; o mais antigo fica sempre no canto superior esquerdo. Um cartão maior que a coluna continua na coluna seguinte com a marca "continua" (como os KDS de mercado), em vez de cortar.
- **Topo:** nome da estação; contadores por etapa e por nível de tempo ("Novos 3 · Preparando 5 · Atenção 2 · Atrasados 1"); filtro por etapa (os próprios contadores funcionam como filtro, com "Todos" por padrão); botões "Recentes", "Esgotados" (atalho do cardápio, spec 03) e "Tela cheia".
- **Tela cheia:** usa a Fullscreen API; esconde o cabeçalho do app e deixa só o topo da estação. Sai pelo botão "Sair da tela cheia" ou pelo gesto do navegador. Se o navegador não suportar (iPhone), a tela explica que instalar o app (spec 01) já tira as barras do navegador.

**Alertas e aparelho** (sem mudança):

- Item novo: som e vibração (se permitidos), cabeçalho na cor "Novo" até ser tocado.
- A tela pede para ficar sempre ligada (Wake Lock API) enquanto estiver aberta; se o navegador recusar, mostra uma dica para ajustar o tempo de tela do aparelho.
- Som só toca depois de uma interação do usuário: a tela mostra "Toque para ativar alertas" na primeira abertura.

### 8.3 Eventos (painel)

- **Lista** (`/painel/eventos`): em andamento no topo, depois agendados (mais próximos primeiro) e encerrados; botão "Novo evento". Só aparece no menu do painel depois que a unidade tiver o primeiro evento ou pelo atalho "Eventos contratados" em "Mais".
- **Cadastro e edição:** contratante, data e data final, acordo (modalidade e campos da RN-04.05), tabela de preço (lista das tabelas ativas, com "Normal" e um atalho para criar tabela nova no cardápio).
- **Detalhe:** situação, acordo, tabela, botões "Iniciar evento" / "Encerrar evento" (RN-04.34) e, encerrado ou em andamento, o link para o relatório do evento (spec 07).

### 8.4 Tabela vigente

A troca fica em dois lugares: no balcão (faixa de operação, seção 8.1) e no início do painel (spec 01, seção 14.2). Na escolha, cada tabela mostra o nome e quantos produtos têm preço nela; a confirmação diz "Itens novos usarão os preços de Evento".

## 9. Critérios de aceite

- **CA-04.01** *(reescrito)* Sem nenhum caixa aberto na unidade, a API recusa abrir comanda e lançar pedido com `NO_CASH_REGISTER_OPEN`, mas aceita avançar itens e pedir a conta de comandas que já existem.
- **CA-04.02** *(reescrito)* Comandas recebem números 1, 2, 3… no dia de operação, sem repetir, mesmo com dois balcões criando ao mesmo tempo; a comanda 3 de ontem ainda aberta faz a numeração de hoje pular o 3.
- **CA-04.03** Um pedido com espeto (Cozinha) e pastel (Fritadeira) aparece em até 2 segundos em cada estação só com o seu item, e completo no balcão.
- **CA-04.04** Avançar um item na cozinha atualiza o balcão e o Balcão de entrega em até 2 segundos.
- **CA-04.05** Dois aparelhos tentando avançar o mesmo item ao mesmo tempo resultam em um único avanço; o segundo recebe o estado atualizado.
- **CA-04.06** Um pedido com produto esgotado é recusado indicando o item.
- **CA-04.07** *(reescrito)* Com a tabela "Evento" vigente, um produto com preço nessa tabela é vendido por esse preço e um produto sem preço nela, pelo preço normal; voltar para "Normal" faz os itens novos usarem o preço normal sem mudar os já enviados.
- **CA-04.08** Cancelar 1 de 3 espetos já em preparo gera uma linha cancelada de 1 marcada como perda e uma linha ativa de 2.
- **CA-04.09** *(reescrito)* Fechar o último caixa com uma comanda aberta é aceito; no dia seguinte, depois de abrir o caixa, a comanda continua no varal com o mesmo número e a data em que foi aberta.
- **CA-04.10** Em comanda paga antes, nenhum item chega à cozinha antes de o pagamento ser registrado.
- **CA-04.11** *(ajustado)* Um item fica marcado em atenção depois de `attention_after_minutes` e atrasado depois de `late_after_minutes` da estação em que está, sem chegar à etapa final.
- **CA-04.12** A tela da estação continua recebendo pedidos depois de o aparelho perder e recuperar a conexão, sem itens duplicados ou faltando.
- **CA-04.13** Avançar 2 de um item com quantidade 3 deixa 1 na etapa atual e 2 na próxima, em duas linhas ligadas por `split_from_id`, sem mudar o total da comanda.
- **CA-04.14** Com um evento em andamento, uma comanda nova fica ligada a ele e usa a tabela do evento; a API recusa trocar a tabela vigente com `EVENT_IN_PROGRESS`; depois de encerrado o evento, comandas novas não têm evento e voltam à tabela vigente da unidade.
- **CA-04.15** A API recusa iniciar um segundo evento na mesma unidade com `EVENT_ALREADY_IN_PROGRESS`.
- **CA-04.16** Uma feira que abre o caixa às 18h de 01/10 e fecha à 1h de 02/10 tem todas as comandas no dia de operação 01/10; o caixa aberto às 17h de 02/10 começa a numeração em 1 com dia de operação 02/10.
- **CA-04.17** Avançar o pedido inteiro num cartão com 3 linhas na mesma etapa move as 3 numa operação; se uma delas tiver mudado em outro aparelho, nenhuma é movida e o cartão mostra o estado atual.
- **CA-04.18** Numa tela de 1920 px de largura, a estação mostra os cartões em pelo menos 5 colunas ocupando toda a largura, o mais antigo no canto superior esquerdo; num celular de 390 px, em uma coluna.
- **CA-04.19** Ao fechar o último caixa com "Encerrar o preparo pendente" marcado, os itens em etapas não finais vão à etapa final e saem das estações, com uma linha de auditoria por item.
- **CA-04.20** Um pedido com 2 espetos e 1 pão de alho, todos da Cozinha, aparece na Cozinha como um único cartão com as duas linhas; tocar no pão de alho em Preparando o deixa riscado no cartão e o cartão continua até os espetos avançarem.
- **CA-04.21** Um pedido com espeto (Cozinha) e pastel (Fritadeira) aparece na Cozinha com o espeto e "+ 1 item em outra estação", e na Fritadeira com o pastel e "+ 1 item em outra estação".
- **CA-04.22** Um segundo pedido na comanda 12 aparece num cartão novo marcado "Adicional · pedido 2", sem alterar o cartão do primeiro pedido.
- **CA-04.23** Cancelar uma linha de um cartão na tela a mostra riscada com "Cancelado" e o motivo no mesmo cartão, com som e vibração na estação.
- **CA-04.24** Numa estação com atenção em 7 e atraso em 15 minutos, um cartão enviado há 8 minutos mostra "Atenção" em laranja com ícone, e há 16 minutos, "Atrasado" com os minutos; mudar a atenção da estação para 10 volta o cartão de 8 minutos ao normal sem recarregar a tela.

## 10. Questões abertas

Nenhuma no momento.

## 11. Decisões de 2026-10-02 (respostas do usuário)

- Troca da tabela vigente: fica com o dono e quem opera caixa (RN-04.31 confirmada).
- Tempo do cartão da estação em três níveis, normal → atenção → atrasado, com limites por estação (RN-04.23, RN-04.46; spec 03, RN-03.25; cor na spec 08).
- Comandas abertas há mais de 2 dias geram aviso no início do painel (spec 01, RN-01.28).
