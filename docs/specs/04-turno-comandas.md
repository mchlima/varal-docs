# 04 — Turno e comandas

## 1. Objetivo

Operar uma barraca durante um período de trabalho: abrir o turno, registrar comandas e pedidos no balcão, fazer cada item chegar à estação certa em tempo real e acompanhar o preparo até a entrega.

## 2. Escopo

**Dentro**

- Turno: abertura, fechamento, tipo, acordo do turno contratado, tabela de preços do turno.
- Comandas "paga antes" e "comanda aberta", com número e nome do cliente.
- Pedidos e itens com modificadores e observação.
- Fluxo dos itens pelas etapas, cancelamento e perda.
- Telas de balcão e de estação, com tempo real, alertas e tela sempre ligada.

**Fora** (outras specs)

- Fechamento de conta, desconto, pagamento e caixa: spec 05.
- Pendurar no fiado: spec 06.
- Relatório do turno: spec 07.

## 3. Turno

- **RN-04.01** Uma unidade tem no máximo um turno aberto por vez.
- **RN-04.02** Abrem e fecham turno: o dono e colaboradores com `can_operate_cash` na unidade.
- **RN-04.03** Não é possível abrir turno se a organização estiver `suspended` ou `canceled` (spec 02), nem se a unidade estiver inativa.
- **RN-04.04** Tipos: `direct_sale` (venda direta) e `contracted` (turno contratado). O tipo é escolhido na abertura e não muda depois.
- **RN-04.05** Turno contratado exige um acordo com: nome do contratante, modalidade, valor combinado (centavos, opcional), limites (texto livre, opcional, ex.: "500 espetos" ou "das 18h às 23h"), quantidade combinada (inteiro, opcional, usada na comparação do relatório) e observação. Modalidades: `fixed_fee` (valor fixo), `per_quantity` (por quantidade), `consumption_billed` (contratante paga o consumo no final), `other`. No MVP o acordo é informativo: nada é calculado a partir dele além da comparação do relatório (spec 07).
- **RN-04.06** Tabela de preços do turno: opcional, definida na abertura e editável enquanto o turno estiver aberto. Para cada produto listado, vale o preço do turno; para os demais, o preço do cardápio. Acréscimos de modificadores não mudam.
- **RN-04.07** Fechar turno exige: nenhuma comanda em `open` ou `closing` e todos os caixas do turno fechados (spec 05). A API devolve a lista do que está pendente quando recusar.
- **RN-04.08** Turno fechado não aceita nenhuma alteração. Itens que ainda estiverem em etapas não finais no fechamento são levados à etapa final automaticamente, com registro na auditoria.

## 4. Comanda

- **RN-04.09** Toda comanda pertence a um turno aberto e tem um número sequencial por turno, começando em 1, atribuído pela API.
- **RN-04.10** Nome do cliente é obrigatório, de 1 a 40 caracteres. O balcão mostra sempre "número + nome" (ex.: "12 · Dona Marta").
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
| `open` ou `closing` | `canceled` | Todos os itens cancelados e nenhum pagamento registrado |

- **RN-04.13** Em `closing`, novos pedidos são recusados até reabrir.
- **RN-04.14** Valores da comanda: subtotal = soma dos itens não cancelados (preço unitário + acréscimos dos modificadores, vezes a quantidade); total = subtotal − desconto (spec 05).
- **RN-04.15** Num turno contratado com modalidade `consumption_billed`, o consumo do contratante é lançado em comandas abertas normais, normalmente uma com o nome do contratante; no fechamento ela é pendurada (spec 06).

## 5. Pedido e itens

- **RN-04.16** Um pedido tem de 1 a 50 itens. Cada item: produto, quantidade de 1 a 99, modificadores escolhidos, observação opcional (até 140 caracteres).
- **RN-04.17** O pedido é recusado se algum produto estiver inativo ou esgotado, ou se faltar escolha em grupo obrigatório. A resposta aponta quais itens.
- **RN-04.18** No envio, cada item grava uma cópia do que foi vendido: nome do produto, preço unitário vigente (do turno ou do cardápio), nome e acréscimo de cada modificador, estação de preparo resolvida (spec 03, RN-03.08). Mudanças posteriores no cardápio não alteram itens já enviados.
- **RN-04.19** Todo item entra na primeira etapa do fluxo da unidade. A estação em que ele aparece é calculada pela etapa (spec 03, seção 4.2).
- Situações do pedido: `sent` enquanto houver item em etapa não final; `completed` quando todos os itens estiverem na etapa final ou cancelados.

### 5.1 Etapas

- **RN-04.20** Avançar um item move para a próxima etapa do fluxo. Pode avançar quem tem acesso à estação em que o item está.
- **RN-04.21** No balcão (`counter`), o colaborador também pode avançar itens que estejam na última etapa antes da final (no template: Pronto → Entregue), para registrar a entrega direto na comanda.
- **RN-04.22** Voltar um item para a etapa anterior é permitido para quem pode avançá-lo, com registro na auditoria. Não se volta da etapa final.
- **RN-04.23** O item guarda quando entrou na etapa atual. Ele é considerado atrasado quando passou mais de `late_after_minutes` (configuração da unidade) desde o envio do pedido sem chegar à etapa final.
- **RN-04.24** O item avança com toda a sua quantidade. Para separar (ex.: 2 de 3 espetos prontos), não há divisão no MVP; a cozinha avança quando todos estiverem prontos.

### 5.2 Cancelamento de item

- **RN-04.25** Qualquer colaborador com acesso ao balcão ou à estação do item pode cancelar, com motivo obrigatório (até 140 caracteres).
- **RN-04.26** Pode-se cancelar parte da quantidade: o item é dividido em uma linha cancelada com a quantidade cancelada e uma linha ativa com o restante.
- **RN-04.27** Item cancelado depois de sair da primeira etapa é marcado como perda (`wasted = true`), para o relatório.
- **RN-04.28** Não se cancela item de comanda `paid`, `on_credit`, `settled` ou `canceled`. Na comanda paga antes, o cancelamento depois do pagamento é tratado como estorno (spec 05).
- Item na etapa final (entregue) pode ser cancelado enquanto a comanda estiver `open` ou `closing` (ex.: devolução), também contando como perda.

## 6. Modelo de dados

Toda tabela tem `organization_id`.

**shifts**: `unit_id`, `type` (`direct_sale`, `contracted`), `status` (`open`, `closed`), `opened_by_type`, `opened_by_id`, `opened_at`, `closed_by_type`, `closed_by_id`, `closed_at`, `next_tab_number int`. Índice único parcial: um `open` por `unit_id`.

**shift_agreements**: `shift_id` (único), `contractor_name`, `modality`, `agreed_amount_cents`, `agreed_quantity`, `limits`, `notes`.

**shift_prices**: `shift_id`, `product_id`, `price_cents`. Único por par.

**tabs**: `shift_id`, `unit_id`, `number int`, `customer_name`, `mode` (`pay_first`, `open_tab`), `status`, `discount_type` (`amount`, `percent`, nulo), `discount_value int`, `discount_reason`, `customer_id` (spec 06), `opened_by_type`, `opened_by_id`, `closed_at`, `version int`. Único `(shift_id, number)`.

**orders**: `tab_id`, `shift_id`, `number_in_tab int`, `status` (`sent`, `completed`), `created_by_type`, `created_by_id`, `sent_at`, `completed_at`.

**order_items**: `order_id`, `tab_id`, `product_id`, `product_name`, `unit_price_cents`, `quantity`, `note`, `prep_station_id`, `stage_id`, `stage_entered_at`, `canceled_at`, `canceled_by_type`, `canceled_by_id`, `cancel_reason`, `wasted bool`, `split_from_id` (opcional), `version int`.

**order_item_modifiers**: `order_item_id`, `modifier_id`, `group_name`, `modifier_name`, `price_delta_cents`.

O "valor de um item" é `(unit_price_cents + soma de price_delta_cents) × quantity`.

## 7. API

| Método e rota | Descrição |
| --- | --- |
| `POST /api/v1/units/{id}/shifts` | Abre turno (tipo, acordo, preços) |
| `GET /api/v1/units/{id}/shifts/current` | Turno aberto da unidade, com acordo e preços |
| `PUT /api/v1/shifts/{id}/prices` | Atualiza a tabela de preços do turno |
| `POST /api/v1/shifts/{id}/close` | Fecha turno (RN-04.07) |
| `GET /api/v1/shifts/{id}/tabs?status=open,closing` | Varal: comandas do turno com totais e resumo dos itens |
| `POST /api/v1/shifts/{id}/tabs` | Abre comanda aberta (`customerName`) |
| `POST /api/v1/shifts/{id}/tabs/pay-first` | Cria comanda paga antes com pedido e pagamentos em uma operação (spec 05) |
| `GET /api/v1/tabs/{id}` | Comanda com pedidos, itens, pagamentos e totais |
| `POST /api/v1/tabs/{id}/orders` | Novo pedido na comanda aberta |
| `POST /api/v1/tabs/{id}/request-bill` | `open` → `closing` |
| `POST /api/v1/tabs/{id}/reopen` | `closing` → `open` |
| `POST /api/v1/tabs/{id}/cancel` | Cancela comanda (RN-04.12) |
| `GET /api/v1/stations/{id}/queue` | Itens na fila da estação, mais antigos primeiro |
| `POST /api/v1/order-items/{id}/advance` | Próxima etapa |
| `POST /api/v1/order-items/{id}/back` | Etapa anterior |
| `POST /api/v1/order-items/{id}/cancel` | Cancela (`quantity`, `reason`) |

Todas as rotas de escrita aceitam `Idempotency-Key` (spec 01). Mudanças de etapa e cancelamentos enviam a `version` conhecida do item; se outro aparelho já mudou o item, a API responde `409 ITEM_CHANGED` com o estado atual, e o app atualiza o cartão sem aplicar a ação.

### 7.1 Eventos em tempo real

| Evento | Salas | Payload |
| --- | --- | --- |
| `shift.opened`, `shift.closed` | `unit` | turno |
| `tab.created` | `unit` | comanda com totais |
| `tab.updated` | `unit` | comanda com situação, totais e `version` |
| `order.created` | `unit` e `station` de cada item | pedido com itens (cada estação recebe só os seus) |
| `order_item.stage_changed` | `unit`, `station` de origem e de destino | item com etapa nova e `version` |
| `order_item.canceled` | `unit` e `station` atual | item cancelado |
| `order.completed` | `unit` | `orderId`, `tabId` |

## 8. Telas

### 8.1 Balcão (estação `counter`)

- **Varal de comandas** (tela inicial): abas Abertas, Fechando e Fiado com contadores; cartões com número grande, nome, total, quantidade de itens e um sinal quando houver item pronto para entregar; busca por número ou nome; botão fixo "Nova comanda".
- **Nova comanda**: escolha entre "Comanda aberta" e "Paga antes" e nome do cliente.
- **Montar pedido**: categorias em abas, produtos em botões grandes com preço (esgotados bloqueados), folha de modificadores ao tocar no produto, observação, carrinho com quantidades e total; botão "Enviar pedido" (comanda aberta) ou "Cobrar e enviar" (paga antes).
- **Comanda**: pedidos com itens e a etapa de cada um, botão "Entregue" nos itens prontos, cancelar item, "Novo pedido", "Pedir conta", e em `closing` "Reabrir" e "Receber" (spec 05).

### 8.2 Estação (`queue`)

- Fila de cartões, um por item, ordenados pelo envio do pedido (mais antigo primeiro); itens do mesmo pedido aparecem juntos.
- Cada cartão: número e nome da comanda, quantidade e produto em letra grande, modificadores e observação em destaque, situação (chip com texto e ícone), tempo desde o pedido.
- Botão grande para avançar, com o nome da próxima etapa ("Começar", "Pronto"); menu secundário para voltar etapa e cancelar.
- Filtro opcional por etapa quando a estação tiver mais de uma.
- Item novo: som e vibração (se permitidos), cartão destacado com a cor primária até ser tocado.
- Item atrasado: chip "Atrasado" com os minutos.
- A tela pede para ficar sempre ligada (Wake Lock API) enquanto estiver aberta; se o navegador recusar, mostra uma dica para ajustar o tempo de tela do aparelho.
- Som só toca depois de uma interação do usuário: a tela mostra "Toque para ativar alertas" na primeira abertura.

### 8.3 Turno (dono e quem opera caixa)

- Abrir turno: tipo, acordo (se contratado), tabela de preços opcional.
- Turno aberto: resumo (comandas, valor, caixas), editar preços, fechar turno com a lista de pendências quando houver.

## 9. Critérios de aceite

- **CA-04.01** A API recusa abrir um segundo turno na mesma unidade com `SHIFT_ALREADY_OPEN`.
- **CA-04.02** Comandas recebem números 1, 2, 3… no turno, sem repetir, mesmo com dois balcões criando ao mesmo tempo.
- **CA-04.03** Um pedido com espeto (Cozinha) e pastel (Fritadeira) aparece em até 2 segundos em cada estação só com o seu item, e completo no balcão.
- **CA-04.04** Avançar um item na cozinha atualiza o balcão e o Balcão de entrega em até 2 segundos.
- **CA-04.05** Dois aparelhos tentando avançar o mesmo item ao mesmo tempo resultam em um único avanço; o segundo recebe o estado atualizado.
- **CA-04.06** Um pedido com produto esgotado é recusado indicando o item.
- **CA-04.07** Um preço definido na tabela do turno é usado nos itens desse turno; o turno seguinte volta ao preço do cardápio.
- **CA-04.08** Cancelar 1 de 3 espetos já em preparo gera uma linha cancelada de 1 marcada como perda e uma linha ativa de 2.
- **CA-04.09** A API recusa fechar o turno com comanda aberta e devolve a lista das comandas pendentes.
- **CA-04.10** Em comanda paga antes, nenhum item chega à cozinha antes de o pagamento ser registrado.
- **CA-04.11** Um item fica marcado como atrasado depois de `late_after_minutes` sem chegar à etapa final.
- **CA-04.12** A tela da estação continua recebendo pedidos depois de o aparelho perder e recuperar a conexão, sem itens duplicados ou faltando.

## 10. Questões abertas

- Divisão de quantidade ao avançar etapa (ex.: 2 de 3 prontos) ficou fora do MVP; confirmar com o piloto se faz falta.
- Tempo padrão de atraso: 15 minutos é uma sugestão; validar com o piloto.
