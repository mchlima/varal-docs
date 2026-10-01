# 06 — Fiado

## 1. Objetivo

Permitir que a barraca feche uma comanda sem receber na hora, em nome de um cliente identificado, e receba depois, em qualquer turno, mantendo a lista do que está a receber.

## 2. Escopo

**Dentro**

- Cadastro de clientes por unidade.
- Pendurar comanda.
- Lista de valores a receber.
- Quitação total ou em partes, em qualquer turno da unidade.
- Uso no turno contratado em que o contratante paga o consumo no final.

**Fora**

- Limite de crédito por cliente.
- Cobrança automática ou lembrete por mensagem.
- Cliente compartilhado entre unidades.

## 3. Clientes

- **RN-06.01** O cliente pertence a uma unidade. Só o nome é obrigatório (até 60 caracteres). Dados de identificação, todos opcionais, servem para diferenciar clientes de mesmo nome:
  - telefone (formato brasileiro com DDD);
  - CPF (validado pelos dígitos verificadores);
  - referência (até 60 caracteres, ex.: "apto 42, bloco B", "setor financeiro", "barraca do lado");
  - observação (até 140 caracteres, ex.: "filho da dona Maria").
- **RN-06.02** Telefone e CPF, quando informados, são únicos dentro da unidade. Ao pendurar, o balcão busca por nome, telefone, CPF ou referência e oferece o cadastro rápido se não encontrar. Na lista de resultados, cada cliente aparece com os dados de identificação que tiver, para não confundir homônimos; ao cadastrar um nome que já existe sem nenhum dado de identificação, o balcão avisa e sugere preencher a referência.
- **RN-06.03** Cliente com valor a receber não pode ser excluído. Cliente sem pendências pode ser excluído a pedido (LGPD): nome e dados de identificação são apagados e o nome vira "Cliente removido", mantendo as comandas para o histórico.

## 4. Pendurar

- **RN-06.04** Só comandas em `closing` podem ser penduradas, por qualquer colaborador com acesso ao balcão.
- **RN-06.05** Pendurar exige um cliente da unidade. A comanda guarda o `customer_id` e passa a `on_credit`.
- **RN-06.06** Pagamentos já feitos antes de pendurar continuam valendo; o valor pendurado é o saldo (total − pagamentos).
- **RN-06.07** Comanda pendurada não aceita mais pedidos, descontos nem cancelamentos de item.
- **RN-06.08** No turno contratado com modalidade `consumption_billed`, a comanda do contratante é pendurada em um cliente com o nome do contratante. Nesse caso a comanda pode ser pendurada sem escolher cliente: a API usa um cliente com o nome do contratante e referência "Contratante de turno", criado uma vez e reaproveitado. Fora desse caso, pendurar exige cliente (`CUSTOMER_REQUIRED`).

## 5. Quitação

- **RN-06.09** Quitar exige um turno aberto e um caixa aberto na unidade da comanda; o pagamento entra nesse caixa e é marcado como quitação de fiado (`is_credit_settlement`).
- **RN-06.10** A quitação pode ser parcial: cada pagamento reduz o saldo. Quando o saldo chega a zero, a comanda passa a `settled`.
- **RN-06.11** As formas de pagamento e o troco seguem a spec 05.
- **RN-06.12** Estornar uma quitação segue a spec 05; se a comanda estava `settled`, volta a `on_credit`.
- Quitam: o dono e qualquer colaborador com acesso ao balcão.

## 6. Modelo de dados

Toda tabela tem `organization_id`.

**customers**: `unit_id`, `name`, `phone` (só dígitos, opcional), `cpf` (só dígitos, opcional), `reference` (opcional), `note` (opcional), `anonymized_at`. Únicos parciais `(unit_id, phone)` e `(unit_id, cpf)`, entre os não anonimizados com o campo preenchido.

**tabs** (spec 04): `customer_id`, `credit_at` (quando foi pendurada), `settled_at`.

O saldo a receber de uma comanda é `total − soma dos pagamentos não estornados`, calculado (não guardado).

## 7. API

| Método e rota | Descrição |
| --- | --- |
| `GET /api/v1/units/{id}/customers?q=` | Busca por nome, telefone, CPF ou referência |
| `GET /api/v1/customers/{id}` | Cliente com as comandas, o saldo e o histórico de quitações |
| `POST /api/v1/units/{id}/customers` | Cadastro |
| `PATCH /api/v1/customers/{id}` | Edição |
| `DELETE /api/v1/customers/{id}` | Remoção a pedido (anonimiza; RN-06.03) |
| `POST /api/v1/tabs/{id}/put-on-credit` | Pendura (`customerId`) |
| `GET /api/v1/units/{id}/receivables` | Comandas `on_credit` com cliente, data, saldo; totais por cliente |
| `POST /api/v1/tabs/{id}/payments` | Mesmo endpoint da spec 05; aceito em `on_credit` como quitação |

Eventos (sala `unit`): `tab.updated` ao pendurar e a cada quitação.

## 8. Telas

| Tela | Conteúdo e ações |
| --- | --- |
| Pendurar (no Receber do balcão) | Busca de cliente; cadastro rápido com nome e, opcionalmente, telefone, CPF, referência e observação; confirmação mostrando o valor pendurado |
| Aba Fiado (varal do balcão) | Comandas penduradas da unidade, mais antigas primeiro, com cliente, data e saldo; tocar abre a tela de receber |
| Fiado (painel do dono) | Total a receber; lista por cliente com comandas, datas e saldos; histórico de quitações; edição e remoção de cliente |

## 9. Critérios de aceite

- **CA-06.01** Uma comanda em `closing` de R$ 120,00 com R$ 20,00 já pagos, pendurada em um cliente, aparece no fiado com saldo de R$ 100,00.
- **CA-06.02** A API recusa pendurar comanda em `open`.
- **CA-06.03** Uma quitação de R$ 60,00 feita no turno seguinte entra no caixa desse turno, deixa saldo de R$ 40,00 e a comanda continua `on_credit`; uma segunda de R$ 40,00 deixa a comanda `settled`.
- **CA-06.04** Cliente de uma unidade não aparece na busca de outra unidade da mesma organização.
- **CA-06.05** A API recusa excluir cliente com saldo a receber; sem saldo, o cliente é anonimizado e as comandas continuam no histórico.
- **CA-06.06** Um cliente pode ser cadastrado só com o nome; dois clientes com o mesmo nome aparecem na busca com seus dados de identificação, e telefone ou CPF repetido na mesma unidade é recusado.

## 10. Questões abertas

Nenhuma no momento.

## Decisões da implementação (fase 6)

- Pendurar só em `closing` e com saldo maior que zero; a comanda conta nas métricas no momento em que é pendurada.
- Quitar exige um turno e um caixa abertos na unidade (não precisa ser o turno da comanda; sem turno, `NO_SHIFT_OPEN`). A quitação pode ser parcial; com saldo zero a comanda vai a `settled`. Estornar uma quitação volta a comanda a `on_credit`; pagamentos feitos antes de pendurar não podem ser estornados.
- O aviso de nome repetido (RN-06.02) é feito pelo app, que busca o nome antes de cadastrar.
- A auditoria registra só quais dados de identificação o cliente tem, nunca os valores (o log não pode ser apagado).
- Os eventos e a comanda resumida mostram nome e referência do cliente, nunca telefone ou CPF.
