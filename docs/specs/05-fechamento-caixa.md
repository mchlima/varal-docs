# 05 — Fechamento e caixa

## 1. Objetivo

Fechar a conta das comandas com desconto e uma ou mais formas de pagamento, e controlar o dinheiro de cada caixa da unidade, da abertura com fundo de troco até a conferência no fechamento. Abrir o caixa é o que começa o dia e libera vender; fechar o caixa é o que o termina.

> **Mudança de 2026-10-02 (redesenho pós-teste):** o caixa deixou de ser criado dentro de um turno. Ele é **cadastrado uma vez na unidade** ("Caixa 1", "Balcão") e é **aberto e fechado** quantas vezes for preciso; cada abertura até o fechamento é uma **abertura de caixa** (`cash_register_sessions`). Regras removidas mantêm o número, marcadas como removidas.

## 2. Escopo

**Dentro**

- Desconto na comanda.
- Pagamentos em Pix, dinheiro, cartão de crédito e cartão de débito, apenas registrados, com troco no dinheiro.
- Estorno de pagamento.
- Caixas da unidade: cadastro, abertura, sangria, suprimento, fechamento com conferência e comandas pendentes.

**Fora**

- Processamento de pagamento, QR Pix, integração com maquininha.
- Divisão da conta entre pessoas.
- Taxa de serviço.
- Cadastro de formas de pagamento com taxas e prazos (conciliação).
- Reabrir uma abertura de caixa já fechada.

## 3. Desconto

- **RN-05.01** Uma comanda em `open` ou `closing` pode ter um desconto, em valor (centavos) ou percentual (1 a 100), com motivo obrigatório. Aplicar de novo substitui o anterior; remover também é registrado.
- **RN-05.02** Qualquer colaborador com acesso ao balcão pode dar desconto (registrado na auditoria).
- **RN-05.03** O desconto percentual é calculado sobre o subtotal no momento do cálculo, arredondado para baixo em centavos; o total nunca fica negativo.

## 4. Pagamento

- **RN-05.04** Formas: `pix`, `cash`, `credit_card`, `debit_card`.
- **RN-05.05** *(ajustada em 2026-10-02)* Recebe pagamento qualquer colaborador com acesso ao balcão da unidade. Todo pagamento entra num caixa **aberto** da unidade da comanda e fica ligado à abertura em andamento desse caixa. Com um único caixa aberto, a escolha é automática; com mais de um, o colaborador escolhe (o app lembra a última escolha do aparelho). Com mais de um caixa aberto e nenhum escolhido, a API responde `CASH_REGISTER_REQUIRED` com a lista dos caixas abertos. Pagamentos simultâneos na mesma comanda são processados em fila: a soma nunca passa do total.
- **RN-05.06** *(ajustada em 2026-10-02)* Sem caixa aberto na unidade, pagamentos são recusados com `NO_CASH_REGISTER_OPEN`.
- **RN-05.07** Em comanda aberta, pagamentos só são aceitos em `closing`. Saldo = total − soma dos pagamentos não estornados.
- **RN-05.08** Para `pix` e cartões, o valor não pode passar do saldo.
- **RN-05.09** Para `cash`, informa-se o valor entregue pelo cliente; o valor aplicado é o menor entre o entregue e o saldo, e o troco é a diferença. Troco é exibido em destaque.
- **RN-05.10** Quando o saldo chega a zero, a comanda passa a `paid` automaticamente e sai do varal.
- **RN-05.11** Comanda com total zero (tudo cancelado) não recebe pagamento; ela é cancelada (spec 04).
- **RN-05.12** Paga antes: a API recebe pedido e pagamentos numa única operação (`POST /units/{id}/tabs/pay-first`). Se a soma dos pagamentos não cobrir o total, nada é gravado. Com sucesso, a comanda nasce `paid` e o pedido é enviado.

### 4.1 Estorno

- **RN-05.13** *(ajustada em 2026-10-02)* Um pagamento pode ser estornado, com motivo, enquanto a abertura de caixa em que ele entrou estiver em andamento. Estorna quem tem acesso ao balcão (é ele quem conduz a RN-05.14). Depois do fechamento daquele caixa, o estorno é recusado com `CASH_REGISTER_CLOSED`.
- **RN-05.14** Estornar pagamento de comanda `paid` volta a comanda para `closing`. Na comanda paga antes, é assim que se cancela um item depois do pagamento: estorna, cancela o item e recebe de novo (ou cancela a comanda). Cancelar item de comanda paga responde `TAB_PAID` com os pagamentos a estornar; cancelar comanda com pagamento ativo responde `TAB_HAS_PAYMENTS`. Desconto ou cancelamento que deixe o total abaixo do já pago é recusado.
- **RN-05.15** O estorno não apaga o pagamento: marca `reversed_at`, quem e o motivo. O valor sai do esperado da abertura de caixa.

## 5. Caixa

### 5.1 Caixas da unidade (cadastro)

- **RN-05.17** *(reescrita em 2026-10-02)* Um caixa é um cadastro da unidade: nome (1 a 40 caracteres, único na unidade, ex.: "Caixa 1", "Balcão"), ordem e ativo. Uma unidade pode ter um ou mais caixas e tem sempre pelo menos um ativo (`LAST_ACTIVE_CASH_REGISTER`). Unidade nova nasce com o caixa "Caixa 1" (spec 03, RN-03.03).
- **RN-05.27** O dono cria, renomeia, ordena e desativa caixas. Caixa aberto não pode ser desativado (`CASH_REGISTER_OPEN`). Caixas nunca são apagados, porque as aberturas passadas apontam para eles.

### 5.2 Abrir caixa

- **RN-05.16** Abrem, movimentam e fecham caixa: o dono e colaboradores com `can_operate_cash` na unidade.
- **RN-05.23** Abrir caixa: escolhe-se um caixa ativo da unidade e informa-se o fundo de troco em dinheiro (maior ou igual a zero; o app sugere o fundo da abertura anterior desse caixa). A API cria uma **abertura de caixa** (`cash_register_sessions`) com quem abriu como responsável. Um caixa tem no máximo uma abertura em andamento (`CASH_REGISTER_ALREADY_OPEN`); caixas diferentes da unidade podem estar abertos ao mesmo tempo.
- **RN-05.24** Não é possível abrir caixa se a organização estiver `suspended` ou `canceled` (`ORGANIZATION_SUSPENDED`, spec 02), nem se a unidade estiver inativa (`UNIT_INACTIVE`).
- **RN-05.25** A abertura grava o dia de operação da unidade (spec 04, RN-04.29). Abrir o primeiro caixa num dia novo é o que muda o dia de operação e reinicia a numeração das comandas.
- **RN-05.26** Uma abertura não tem prazo: um caixa esquecido aberto continua aberto, e o dia de operação não muda enquanto ele estiver aberto. Quando a abertura em andamento for de uma data anterior a hoje, o início do painel e a tela de caixas mostram "Caixa 1 aberto desde ontem, 17:02" e sugerem fechar (spec 01, seção 14.2).

### 5.3 Movimentos

- **RN-05.18** Sangria (`withdrawal`) e suprimento (`deposit`): valor maior que zero e motivo obrigatório. A sangria não pode passar do dinheiro esperado na gaveta.
- **RN-05.19** Dinheiro esperado de uma abertura = fundo de troco + pagamentos em dinheiro (valor aplicado, não estornados) + suprimentos − sangrias.
- **RN-05.22** Quitações de fiado entram no caixa aberto em que foram recebidas (spec 06) e aparecem separadas na conferência.

### 5.4 Fechar caixa

- **RN-05.20** *(ajustada em 2026-10-02)* Fechar caixa: quem fecha informa, por forma de pagamento, o valor conferido (dinheiro contado na gaveta; Pix conferido no extrato; crédito e débito pela maquininha). O sistema calcula a diferença de cada forma (informado − esperado). O fechamento exige o valor conferido das quatro formas; havendo diferença em qualquer uma, a observação é obrigatória (`CLOSING_NOTE_REQUIRED`, com a prévia das diferenças).
- **RN-05.28** Comandas em `open` ou `closing` **não impedem** o fechamento (spec 04, RN-04.07). A tela de fechamento lista essas comandas como pendentes (número, nome, total, desde quando) e explica que elas continuam abertas para o próximo dia ou para outro caixa aberto. A abertura guarda, no fechamento, a quantidade e o valor total das comandas pendentes naquele momento, para o relatório do caixa (spec 07).
- **RN-05.29** Quando o caixa a fechar é o último aberto da unidade, a confirmação mostra também: os itens ainda em preparo, com a opção "Encerrar o preparo pendente" marcada (spec 04, RN-04.08), e, se houver evento em andamento, a opção "Encerrar também o evento {contratante}" (desmarcada; spec 04, RN-04.35).
- **RN-05.21** *(ajustada em 2026-10-02)* Uma abertura fechada não recebe pagamentos nem movimentos e não pode ser reaberta no MVP. Para voltar a vender, abre-se o caixa de novo (nova abertura, com novo fundo de troco).

| Forma | Esperado | Informado no fechamento |
| --- | --- | --- |
| Dinheiro | RN-05.19 | Contado na gaveta |
| Pix | Soma dos Pix da abertura | Conferido no extrato |
| Crédito | Soma dos créditos da abertura | Total da maquininha |
| Débito | Soma dos débitos da abertura | Total da maquininha |

## 6. Modelo de dados

Toda tabela tem `organization_id`.

**cash_registers** (cadastro do caixa): `unit_id`, `name`, `sort_order`, `active`. Único `(unit_id, lower(name))`.

**cash_register_sessions** (abertura de caixa): `cash_register_id`, `unit_id`, `business_date date` (RN-05.25), `status` (`open`, `closed`), `opening_float_cents`, `opened_by_type`, `opened_by_id`, `opened_at`, `closed_by_type`, `closed_by_id`, `closed_at`, `closing_note`, `pending_tabs_count int` e `pending_tabs_total_cents int` (gravados no fechamento, RN-05.28), `version int`. Índice único parcial: um `open` por `cash_register_id`. Índices `(unit_id, status)` e `(unit_id, business_date)`.

**cash_movements**: `cash_register_session_id`, `type` (`withdrawal`, `deposit`), `amount_cents`, `reason`, `created_by_type`, `created_by_id`.

**cash_register_counts**: `cash_register_session_id`, `method`, `expected_cents`, `informed_cents`, `difference_cents`. Único `(cash_register_session_id, method)`; gravado no fechamento.

**payments**: `tab_id`, `cash_register_session_id` (a abertura em que o dinheiro entrou), `method`, `amount_cents` (aplicado), `tendered_cents` (só dinheiro), `change_cents` (só dinheiro), `is_credit_settlement bool` (spec 06), `received_by_type`, `received_by_id`, `reversed_at`, `reversed_by_type`, `reversed_by_id`, `reversal_reason`.

Observação: o dia em que um pagamento entrou é o `business_date` da abertura dele, que pode ser diferente do dia da comanda (comanda que passou de um dia para o outro, quitação de fiado).

Migração (plano de desenvolvimento, fase 7.5): a tabela `cash_registers` atual (um caixa por turno) vira `cash_register_sessions`; os nomes distintos de cada unidade viram os caixas cadastrados; `payments.shift_id` sai.

## 7. API

| Método e rota | Descrição |
| --- | --- |
| `PUT /api/v1/tabs/{id}/discount` | Aplica ou substitui desconto (`type`, `value`, `reason`) |
| `DELETE /api/v1/tabs/{id}/discount` | Remove desconto (com `reason`) |
| `POST /api/v1/tabs/{id}/payments` | Registra pagamento (`method`, `amountCents` ou `tenderedCents`, `cashRegisterId` opcional) |
| `POST /api/v1/payments/{id}/reverse` | Estorna (`reason`) |
| `GET /api/v1/units/{id}/cash-registers` | Caixas da unidade, cada um com a abertura em andamento (responsável, desde, esperado por forma) ou a última fechada. Para quem opera caixa e para o balcão (escolha do caixa no Receber) |
| `POST /api/v1/units/{id}/cash-registers`, `PATCH /api/v1/cash-registers/{id}` | Cadastro do caixa (dono): nome, ordem, ativo |
| `POST /api/v1/cash-registers/{id}/open` | Abre o caixa (`openingFloatCents`, `startEventId` opcional para iniciar junto o evento de hoje, spec 04, RN-04.35); devolve a abertura |
| `GET /api/v1/cash-register-sessions/{id}` | Detalhe da abertura: movimentos, pagamentos, esperado por forma |
| `POST /api/v1/cash-register-sessions/{id}/movements` | Sangria ou suprimento |
| `GET /api/v1/cash-register-sessions/{id}/close-preview` | Prévia do fechamento: esperado por forma, comandas pendentes e, se for o último caixa aberto, itens em preparo e evento em andamento |
| `POST /api/v1/cash-register-sessions/{id}/close` | Fecha com valores informados, observação, `finishPendingItems` (padrão `true`, só no último caixa) e `finishEvent` (padrão `false`) |

Saem: `POST/GET /shifts/{id}/cash-registers`, `POST /cash-registers/{id}/movements` e `POST /cash-registers/{id}/close` (passam para a abertura).

Eventos (sala `unit`): `tab.updated` a cada desconto, pagamento ou estorno; `cash_register.opened`, `cash_register.updated`, `cash_register.closed` (payload: caixa com a abertura); `unit.operation_updated` ao abrir e fechar caixa (spec 04).

## 8. Telas

| Tela | Conteúdo e ações |
| --- | --- |
| Receber (balcão) | Total, desconto, pagamentos já feitos e saldo em destaque; botões grandes Pix, Dinheiro, Crédito, Débito; teclado numérico; em dinheiro, campo "Valor entregue" e troco em letra grande; seletor de caixa quando houver mais de um aberto; "Pendurar" (spec 06) |
| Desconto (balcão) | Valor ou percentual, motivo, prévia do novo total |
| Caixas (`/caixas`, quem opera caixa) | Um cartão por caixa da unidade. Fechado: nome, último fechamento e botão "Abrir caixa". Aberto: responsável, desde quando (com o alerta da RN-05.26), esperado por forma, "Sangria", "Suprimento" e "Fechar caixa". Com um único caixa cadastrado, a tela vai direto ao essencial: "Abrir caixa" ou o resumo do caixa aberto |
| Abrir caixa (`/caixas/{id}/abrir`) | Fundo de troco com a sugestão da última abertura; aviso da tabela vigente quando não for "Normal", com "Voltar para Normal" (spec 04, RN-04.31); oferta de iniciar o evento de hoje (RN-04.35); botão principal "Abrir caixa". Ao abrir, leva ao balcão ("Abrir balcão") ou de volta ao início, conforme de onde veio |
| Fechar caixa (`/caixas/{id}/fechar`) | Para cada forma: esperado, campo informado, diferença calculada; observação obrigatória se houver diferença; comandas pendentes que seguem abertas (RN-05.28); no último caixa, itens em preparo e evento em andamento (RN-05.29); confirmação final. Depois de fechar: resumo do próprio fechamento (contagem, esperado e diferença por forma, recebido, pendentes), visível para quem fechou; "Ver relatório do caixa" só para o dono (spec 07, RN-07.07) |
| Caixas da unidade (painel, `/painel/unidades/{id}/caixas`) | Cadastro (dono): lista com nome, situação e ordem; criar, renomear, desativar |

O botão de confirmar pagamento mostra o valor e a forma ("Confirmar R$ 46,00 no Pix") para evitar erro de toque.

## 9. Critérios de aceite

- **CA-05.01** Comanda de R$ 80,00 paga com R$ 50,00 no Pix e R$ 30,00 em dinheiro fica `paid` e sai do varal.
- **CA-05.02** Pagamento em dinheiro de R$ 46,00 com R$ 50,00 entregues registra R$ 46,00 aplicados e R$ 4,00 de troco.
- **CA-05.03** A API recusa Pix de valor maior que o saldo.
- **CA-05.04** Desconto de 10% em subtotal de R$ 92,50 resulta em total de R$ 83,25.
- **CA-05.05** Estornar um pagamento de comanda paga volta a comanda para `closing` com o saldo correspondente.
- **CA-05.06** Caixa com fundo de R$ 100,00, R$ 300,00 em dinheiro recebido, sangria de R$ 200,00 e suprimento de R$ 50,00 tem R$ 250,00 de dinheiro esperado.
- **CA-05.07** Fechar caixa com diferença sem observação é recusado; com observação, a diferença fica gravada e aparece no relatório.
- **CA-05.08** *(ajustado)* Sem caixa aberto na unidade, o balcão mostra "Abra um caixa para vender" e a API recusa o pagamento com `NO_CASH_REGISTER_OPEN`.
- **CA-05.09** Paga antes com pagamento menor que o total não grava pedido nem pagamento.
- **CA-05.10** A API recusa abrir o "Caixa 1" quando ele já está aberto (`CASH_REGISTER_ALREADY_OPEN`), mas aceita abrir o "Caixa 2" da mesma unidade ao mesmo tempo.
- **CA-05.11** Fechar o caixa com duas comandas abertas é aceito; o fechamento grava 2 pendentes com o valor total delas, e as comandas continuam `open`.
- **CA-05.12** Abrir de novo um caixa fechado cria uma abertura nova, com fundo próprio, e os pagamentos novos entram nela; a abertura anterior não muda.
- **CA-05.13** A API recusa estornar um pagamento cuja abertura de caixa já foi fechada (`CASH_REGISTER_CLOSED`).
- **CA-05.14** A API recusa desativar um caixa aberto e o último caixa ativo da unidade.

## 10. Questões abertas

- Reabrir uma abertura de caixa fechada por engano ficou fora do MVP; confirmar.
- Fundo de troco sugerido: hoje é o fundo da abertura anterior do mesmo caixa. Avaliar sugerir o dinheiro contado no último fechamento menos a sangria final.
