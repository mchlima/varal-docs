# 05 — Fechamento e caixa

## 1. Objetivo

Fechar a conta das comandas com desconto e uma ou mais formas de pagamento, e controlar o dinheiro de cada caixa do turno, da abertura com fundo de troco até a conferência no fechamento.

## 2. Escopo

**Dentro**

- Desconto na comanda.
- Pagamentos em Pix, dinheiro, cartão de crédito e cartão de débito, apenas registrados, com troco no dinheiro.
- Estorno de pagamento.
- Caixas do turno: abertura, sangria, suprimento, fechamento com conferência.

**Fora**

- Processamento de pagamento, QR Pix, integração com maquininha.
- Divisão da conta entre pessoas.
- Taxa de serviço.
- Cadastro de formas de pagamento com taxas e prazos (conciliação).

## 3. Desconto

- **RN-05.01** Uma comanda em `open` ou `closing` pode ter um desconto, em valor (centavos) ou percentual (1 a 100), com motivo obrigatório. Aplicar de novo substitui o anterior; remover também é registrado.
- **RN-05.02** Qualquer colaborador com acesso ao balcão pode dar desconto (registrado na auditoria).
- **RN-05.03** O desconto percentual é calculado sobre o subtotal no momento do cálculo, arredondado para baixo em centavos; o total nunca fica negativo.

## 4. Pagamento

- **RN-05.04** Formas: `pix`, `cash`, `credit_card`, `debit_card`.
- **RN-05.05** Recebe pagamento qualquer colaborador com acesso ao balcão da unidade. Todo pagamento entra num caixa aberto do turno; com um único caixa aberto, a escolha é automática; com mais de um, o colaborador escolhe (o app lembra a última escolha do aparelho). Com mais de um caixa aberto e nenhum escolhido, a API responde `CASH_REGISTER_REQUIRED` com a lista dos caixas. Pagamentos simultâneos na mesma comanda são processados em fila: a soma nunca passa do total.
- **RN-05.06** Sem caixa aberto no turno, pagamentos são recusados com `NO_CASH_REGISTER_OPEN`.
- **RN-05.07** Em comanda aberta, pagamentos só são aceitos em `closing`. Saldo = total − soma dos pagamentos não estornados.
- **RN-05.08** Para `pix` e cartões, o valor não pode passar do saldo.
- **RN-05.09** Para `cash`, informa-se o valor entregue pelo cliente; o valor aplicado é o menor entre o entregue e o saldo, e o troco é a diferença. Troco é exibido em destaque.
- **RN-05.10** Quando o saldo chega a zero, a comanda passa a `paid` automaticamente e sai do varal.
- **RN-05.11** Comanda com total zero (tudo cancelado) não recebe pagamento; ela é cancelada (spec 04).
- **RN-05.12** Paga antes: a API recebe pedido e pagamentos numa única operação (`POST /shifts/{id}/tabs/pay-first`). Se a soma dos pagamentos não cobrir o total, nada é gravado. Com sucesso, a comanda nasce `paid` e o pedido é enviado.

### 4.1 Estorno

- **RN-05.13** Um pagamento pode ser estornado, com motivo, enquanto o turno estiver aberto e o caixa do pagamento estiver aberto. Estorna quem tem acesso ao balcão (é ele quem conduz a RN-05.14).
- **RN-05.14** Estornar pagamento de comanda `paid` volta a comanda para `closing`. Na comanda paga antes, é assim que se cancela um item depois do pagamento: estorna, cancela o item e recebe de novo (ou cancela a comanda). Cancelar item de comanda paga responde `TAB_PAID` com os pagamentos a estornar; cancelar comanda com pagamento ativo responde `TAB_HAS_PAYMENTS`. Desconto ou cancelamento que deixe o total abaixo do já pago é recusado.
- **RN-05.15** O estorno não apaga o pagamento: marca `reversed_at`, quem e o motivo. O valor sai do esperado do caixa.

## 5. Caixa

- **RN-05.16** Abrem, movimentam e fecham caixa: o dono e colaboradores com `can_operate_cash` na unidade.
- **RN-05.17** Um turno pode ter vários caixas abertos ao mesmo tempo. Cada caixa tem nome (padrão "Caixa 1", "Caixa 2"…), responsável (quem abriu) e fundo de troco em dinheiro (maior ou igual a zero).
- **RN-05.18** Sangria (`withdrawal`) e suprimento (`deposit`): valor maior que zero e motivo obrigatório. A sangria não pode passar do dinheiro esperado na gaveta.
- **RN-05.19** Dinheiro esperado = fundo de troco + pagamentos em dinheiro (valor aplicado, não estornados) + suprimentos − sangrias.
- **RN-05.20** Fechar caixa: o responsável pelo fechamento informa, por forma de pagamento, o valor conferido (dinheiro contado na gaveta; Pix conferido no extrato; crédito e débito pela maquininha). O sistema calcula a diferença de cada forma (informado − esperado). Havendo qualquer diferença diferente de zero, uma observação é obrigatória. O fechamento exige o valor conferido das quatro formas; havendo diferença em qualquer uma, a observação é obrigatória (`CLOSING_NOTE_REQUIRED`, com a prévia das diferenças). O nome do caixa é único no turno.
- **RN-05.21** Caixa fechado não recebe pagamentos nem movimentos e não pode ser reaberto no MVP.
- **RN-05.22** Quitações de fiado entram no caixa em que foram recebidas (spec 06) e aparecem separadas na conferência.

| Forma | Esperado | Informado no fechamento |
| --- | --- | --- |
| Dinheiro | RN-05.19 | Contado na gaveta |
| Pix | Soma dos Pix do caixa | Conferido no extrato |
| Crédito | Soma dos créditos do caixa | Total da maquininha |
| Débito | Soma dos débitos do caixa | Total da maquininha |

## 6. Modelo de dados

Toda tabela tem `organization_id`.

**cash_registers**: `shift_id`, `unit_id`, `name`, `status` (`open`, `closed`), `opening_float_cents`, `opened_by_type`, `opened_by_id`, `opened_at`, `closed_by_type`, `closed_by_id`, `closed_at`, `closing_note`.

**cash_movements**: `cash_register_id`, `type` (`withdrawal`, `deposit`), `amount_cents`, `reason`, `created_by_type`, `created_by_id`.

**cash_register_counts**: `cash_register_id`, `method`, `expected_cents`, `informed_cents`, `difference_cents`. Único `(cash_register_id, method)`; gravado no fechamento.

**payments**: `tab_id`, `shift_id`, `cash_register_id`, `method`, `amount_cents` (aplicado), `tendered_cents` (só dinheiro), `change_cents` (só dinheiro), `is_credit_settlement bool` (spec 06), `received_by_type`, `received_by_id`, `reversed_at`, `reversed_by_type`, `reversed_by_id`, `reversal_reason`.

Observação: `payments.shift_id` é o turno em que o dinheiro entrou, que pode ser diferente do turno da comanda quando for quitação de fiado.

## 7. API

| Método e rota | Descrição |
| --- | --- |
| `PUT /api/v1/tabs/{id}/discount` | Aplica ou substitui desconto (`type`, `value`, `reason`) |
| `DELETE /api/v1/tabs/{id}/discount` | Remove desconto (com `reason`) |
| `POST /api/v1/tabs/{id}/payments` | Registra pagamento (`method`, `amountCents` ou `tenderedCents`, `cashRegisterId` opcional) |
| `POST /api/v1/payments/{id}/reverse` | Estorna (`reason`) |
| `POST /api/v1/shifts/{id}/cash-registers` | Abre caixa (`name` opcional, `openingFloatCents`) |
| `GET /api/v1/shifts/{id}/cash-registers` | Caixas do turno com esperado por forma |
| `POST /api/v1/cash-registers/{id}/movements` | Sangria ou suprimento |
| `GET /api/v1/cash-registers/{id}` | Detalhe: movimentos, pagamentos, esperado |
| `POST /api/v1/cash-registers/{id}/close` | Fecha com valores informados e observação |

Eventos (sala `unit`): `tab.updated` a cada desconto, pagamento ou estorno; `cash_register.opened`, `cash_register.updated`, `cash_register.closed`.

## 8. Telas

| Tela | Conteúdo e ações |
| --- | --- |
| Receber (balcão) | Total, desconto, pagamentos já feitos e saldo em destaque; botões grandes Pix, Dinheiro, Crédito, Débito; teclado numérico; em dinheiro, campo "Valor entregue" e troco em letra grande; seletor de caixa quando houver mais de um; "Pendurar" (spec 06) |
| Desconto (balcão) | Valor ou percentual, motivo, prévia do novo total |
| Caixas (quem opera caixa) | Caixas do turno com responsável e esperado por forma; abrir caixa; sangria; suprimento |
| Fechar caixa | Para cada forma: esperado, campo informado, diferença calculada; observação obrigatória se houver diferença; confirmação final |

O botão de confirmar pagamento mostra o valor e a forma ("Confirmar R$ 46,00 no Pix") para evitar erro de toque.

## 9. Critérios de aceite

- **CA-05.01** Comanda de R$ 80,00 paga com R$ 50,00 no Pix e R$ 30,00 em dinheiro fica `paid` e sai do varal.
- **CA-05.02** Pagamento em dinheiro de R$ 46,00 com R$ 50,00 entregues registra R$ 46,00 aplicados e R$ 4,00 de troco.
- **CA-05.03** A API recusa Pix de valor maior que o saldo.
- **CA-05.04** Desconto de 10% em subtotal de R$ 92,50 resulta em total de R$ 83,25.
- **CA-05.05** Estornar um pagamento de comanda paga volta a comanda para `closing` com o saldo correspondente.
- **CA-05.06** Caixa com fundo de R$ 100,00, R$ 300,00 em dinheiro recebido, sangria de R$ 200,00 e suprimento de R$ 50,00 tem R$ 250,00 de dinheiro esperado.
- **CA-05.07** Fechar caixa com diferença sem observação é recusado; com observação, a diferença fica gravada e aparece no relatório.
- **CA-05.08** Sem caixa aberto, o balcão mostra "Abra um caixa para receber" e a API recusa o pagamento.
- **CA-05.09** Paga antes com pagamento menor que o total não grava pedido nem pagamento.

## 10. Questões abertas

- Reabrir caixa fechado por engano ficou fora do MVP; confirmar.
