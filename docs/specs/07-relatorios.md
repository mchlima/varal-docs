# 07 — Relatórios

## 1. Objetivo

Responder ao dono, ao fim de cada dia e ao longo do tempo: quanto vendeu, do quê, como recebeu, quanto ficou no fiado, o que se perdeu, se cada caixa bateu e, nos eventos, se o consumido ficou dentro do combinado.

> **Mudança de 2026-10-02 (redesenho pós-teste):** o relatório do turno saiu. Os relatórios passam a ser **por dia ou período**, **por caixa** (abertura de caixa) e **por evento**. As regras de valores continuam as mesmas, agora contadas pelo dia de operação (spec 04, RN-04.29 e RN-04.30).

## 2. Escopo

**Dentro**

- Relatório do dia ou do período, por unidade ou de todas as unidades.
- Relatório do caixa: uma abertura de caixa, do fundo de troco à conferência.
- Relatório do evento contratado, com a comparação entre o combinado e o consumido.
- Histórico de dias, de caixas e de eventos, com totais do período.
- Valores parciais enquanto o dia, o caixa ou o evento estiver em andamento.

**Fora**

- Exportação em CSV ou PDF.
- Gráficos de tendência e comparação entre unidades.
- Custo de produtos e margem.

## 3. Regras de cálculo

Todas as datas são dias de operação (`business_date`, spec 04, RN-04.29), não a hora do relógio: uma venda à 0h30 de uma feira que começou às 18h conta no dia em que a feira começou.

- **RN-07.01** *(reescrita em 2026-10-02)* Venda do período = soma do total (após desconto) das comandas concluídas no período, isto é, que passaram a `paid` ou `on_credit` num dia de operação do período (`closed_business_date`, spec 04, RN-04.38); comandas `settled` contam pelo dia em que foram penduradas. Comandas `canceled` e as ainda em `open` ou `closing` ficam fora. Uma comanda aberta ontem e paga hoje é venda de hoje.
- **RN-07.02** *(reescrita em 2026-10-02)* Recebido no período = soma dos pagamentos não estornados das aberturas de caixa com dia de operação no período, separando vendas e quitações de fiado (`is_credit_settlement`).
- **RN-07.03** *(reescrita em 2026-10-02)* Pendurado no período = soma dos saldos das comandas penduradas no período, no valor do momento em que foram penduradas.
- **RN-07.04** *(ajustada em 2026-10-02)* Quantidades por produto contam itens não cancelados das comandas que contam na venda; perdas contam itens cancelados com `wasted = true` pelo dia de operação do cancelamento, de qualquer comanda.
- **RN-07.05** Todos os valores usam o preço gravado no item (spec 04, RN-04.18), não o preço atual do cardápio nem o atual da tabela.
- **RN-07.06** *(reescrita em 2026-10-02)* Um relatório é parcial quando inclui o dia de operação atual de uma unidade com caixa aberto, quando é de uma abertura de caixa em andamento ou de um evento em andamento. Ele mostra a faixa "Em andamento — valores parciais".
- **RN-07.08** Diferença de caixa do período = soma das diferenças gravadas no fechamento das aberturas com dia de operação no período. Aberturas ainda em andamento não têm diferença.
- **RN-07.09** O relatório do caixa trata só de dinheiro que passou por aquela abertura: fundo, pagamentos (vendas e quitações, por forma), estornos, sangrias, suprimentos, esperado, informado, diferença e as comandas pendentes no fechamento (spec 05, RN-05.28). Ele não tem "venda", porque uma comanda pode ser paga em mais de um caixa.
- **RN-07.10** O relatório do evento considera as comandas ligadas ao evento (`event_id`), de qualquer dia: venda (como na RN-07.01, sem filtro de data), recebido dessas comandas em qualquer caixa, pendurado, por produto, perdas e a comparação com o acordo.

## 4. Relatório do dia ou do período

Um dia é um período de um dia só. Com mais de uma unidade, o relatório pode ser de uma unidade ou de todas.

| Seção | Conteúdo |
| --- | --- |
| Resumo | Unidade (ou "Todas"), período, venda, recebido (vendas e quitações), pendurado, número de comandas concluídas, ticket médio, descontos, perdas, diferença de caixa; quando parcial, comandas em aberto agora (quantidade e valor) |
| Por produto | Produto, quantidade, valor; ordenado por valor; inclui modificadores com acréscimo; quando houve venda com tabela de preço, a quantidade e o valor vendidos em cada tabela |
| Por forma de pagamento | Pix, dinheiro, crédito, débito: valor de vendas e de quitações de fiado, separados |
| Por colaborador | Comandas abertas, pedidos lançados, valor recebido, cancelamentos e descontos feitos |
| Caixas | Uma linha por abertura do período: caixa, dia, responsável, abertura e fechamento, recebido, diferença, pendentes no fechamento; tocar abre o relatório do caixa |
| Fiado | Comandas penduradas no período (cliente e valor) e quitações recebidas no período |
| Cancelamentos e perdas | Itens cancelados com motivo, quem cancelou e se foi perda; comandas canceladas |
| Eventos | Eventos com comandas no período, com a venda deles; tocar abre o relatório do evento. A seção só aparece se houver evento |

## 5. Relatório do caixa

| Seção | Conteúdo |
| --- | --- |
| Resumo | Caixa, unidade, dia de operação, quem abriu e quando, quem fechou e quando (ou "Aberto"), fundo de troco, recebido, diferença total |
| Por forma | Esperado, informado e diferença de cada forma; vendas e quitações separadas; observação do fechamento |
| Movimentos | Sangrias e suprimentos com valor, motivo, quem e quando |
| Pagamentos | Lista dos pagamentos (comanda, forma, valor, troco, quem recebeu, hora), com os estornos marcados |
| Pendentes no fechamento | Quantidade e valor das comandas que seguiram abertas (RN-05.28) |

## 6. Relatório do evento

| Seção | Conteúdo |
| --- | --- |
| Resumo | Contratante, datas, situação, tabela de preço, venda, recebido, pendurado, número de comandas |
| Acordo | Modalidade, valor e quantidade combinados, limites, observação; consumo em quantidade e valor; diferença entre a quantidade combinada e a consumida (negativa se passou do combinado; vazia sem quantidade combinada) |
| Por produto | Como no relatório do dia |
| Comandas | Comandas do evento com situação, total e pagamentos; as penduradas com o saldo atual |
| Cancelamentos e perdas | Como no relatório do dia |

## 7. Histórico

- Três abas, cada uma com filtros de unidade e período (atalhos: hoje, 7 dias, 30 dias, mês atual) e os totais do período no topo (venda, recebido, pendurado, perdas, descontos, diferença de caixa):
  - **Dias:** uma linha por unidade e dia de operação, mais recente primeiro: data, unidade, venda, recebido, pendurado, comandas, diferença de caixa. Tocar abre o relatório do dia.
  - **Caixas:** uma linha por abertura: caixa, unidade, dia, responsável, recebido, diferença. Tocar abre o relatório do caixa.
  - **Eventos:** uma linha por evento: contratante, data, situação, venda, consumo contra o combinado. Tocar abre o relatório do evento. A aba só aparece se a organização tiver eventos.
- Há também "Ver relatório do período", que abre o relatório da seção 4 com o filtro atual.

## 8. Acesso

- **RN-07.07** *(confirmada em 2026-10-02)* Relatórios ficam no painel do dono, inclusive o relatório do caixa. Colaboradores não veem relatórios no MVP; quem fecha um caixa vê só o resumo do próprio fechamento (contagem, esperado e diferença por forma, pendentes), na tela de fechamento (spec 05, seção 8).
- O admin da plataforma vê os mesmos relatórios apenas durante um "entrar como" (spec 02).

## 9. Modelo de dados

Sem tabelas novas: relatórios são consultas sobre comandas, itens, pagamentos, aberturas de caixa e eventos, pelos dias de operação gravados (spec 04, RN-04.30). Índices: `tabs (organization_id, unit_id, closed_business_date)`, `cash_register_sessions (organization_id, unit_id, business_date)`, `payments (organization_id, cash_register_session_id)`, `order_items (organization_id, unit_id, canceled_business_date)` e `tabs (organization_id, event_id)`. Se as consultas ficarem lentas, criar visões materializadas por unidade e dia.

## 10. API

| Método e rota | Descrição |
| --- | --- |
| `GET /api/v1/reports/summary?unitId=&from=&to=` | Relatório do dia ou período (seção 4); sem `unitId`, todas as unidades |
| `GET /api/v1/reports/days?unitId=&from=&to=&limit=&cursor=` | Histórico por dia com totais do período (seção 7), paginado por cursor |
| `GET /api/v1/reports/cash-sessions?unitId=&cashRegisterId=&from=&to=&limit=&cursor=` | Histórico de aberturas de caixa com totais |
| `GET /api/v1/cash-register-sessions/{id}/report` | Relatório do caixa (seção 5) |
| `GET /api/v1/reports/events?unitId=&from=&to=&status=&limit=&cursor=` | Histórico de eventos |
| `GET /api/v1/events/{id}/report` | Relatório do evento (seção 6) |

Saem: `GET /shifts/{id}/report` e `GET /reports/shifts`.

## 11. Telas

| Tela | Conteúdo |
| --- | --- |
| Histórico (`/painel/relatorios`) | Abas Dias, Caixas e Eventos; filtros; totais do período; "Ver relatório do período" |
| Relatório do dia ou período (`/painel/relatorios/periodo?unidade=&de=&ate=`) | Seções da tabela 4, com o resumo no topo e as demais recolhíveis; legível no celular |
| Relatório do caixa (`/painel/relatorios/caixas/{id}`) | Seções da tabela 5 |
| Relatório do evento (`/painel/relatorios/eventos/{id}`) | Seções da tabela 6 |

O início do painel (spec 01, seção 14.2) mostra o resumo de hoje (venda e recebido parciais) com o link para o relatório do dia.

## 12. Critérios de aceite

- **CA-07.01** *(reescrito)* Num dia com uma comanda paga de R$ 80,00, uma pendurada de R$ 100,00 e uma cancelada, a venda do dia é R$ 180,00, o recebido é R$ 80,00 e o pendurado é R$ 100,00.
- **CA-07.02** *(ajustado)* Uma quitação de fiado recebida hoje, de comanda de ontem, aparece no recebido de hoje como quitação e não entra na venda de hoje.
- **CA-07.03** *(reescrito)* O relatório de um evento com quantidade combinada de 500 e 462 itens consumidos mostra diferença de 38, somando comandas do evento de dois dias.
- **CA-07.04** A diferença de caixa informada no fechamento aparece no relatório do caixa, no do dia e no histórico.
- **CA-07.05** Mudar o preço de um produto ou de uma tabela depois de um dia não altera o relatório desse dia.
- **CA-07.06** Um colaborador recebe 403 ao pedir qualquer relatório, inclusive o do caixa que ele fechou.
- **CA-07.07** Uma comanda aberta no dia 01/10 e paga no dia 02/10 conta na venda de 02/10, não na de 01/10.
- **CA-07.08** Uma venda à 0h30 de 02/10, numa feira cujo caixa foi aberto às 18h de 01/10, conta no dia 01/10.
- **CA-07.09** Com dois caixas abertos no mesmo dia, o relatório de cada caixa mostra só os pagamentos dele, e o relatório do dia mostra a soma dos dois.
- **CA-07.10** O relatório de um período de 7 dias soma os 7 relatórios diários (venda, recebido, pendurado, perdas, descontos, diferença).

## 13. Decisões da implementação (fase 7, ajustadas em 2026-10-02)

- **Datas:** `from` e `to` são dias de operação (`AAAA-MM-DD`, `to` inclusive). Sem datas, os últimos 30 dias até hoje; o período vai de 1 a 366 dias. Os atalhos (hoje, 7 dias, 30 dias, mês atual) são do app.
- **Histórico:** sem `unitId`, traz todas as unidades da organização. Inclui o dia e as aberturas em andamento (valores parciais). Ordenado do mais recente, paginado por cursor (`limit` até 100); os totais do topo são do período inteiro, não só da página.
- **Pendurado (RN-07.03):** total da comanda menos os pagamentos feitos antes de pendurar (que não podem mais ser estornados, spec 06). Conta comandas hoje em `on_credit` ou já `settled`; o relatório mostra também o saldo atual de cada uma.
- **Por produto:** só itens não cancelados das comandas que contam na venda, agrupados pela cópia do vendido (produto e nome gravado); o valor é antes do desconto da comanda (o desconto aparece no resumo). Modificadores com acréscimo aparecem dentro do produto, com quantidade e valor. A quebra por tabela usa `order_items.price_list_id`.
- **Por colaborador:** inclui o dono. Comandas abertas, pedidos lançados, recebido (pagamentos não estornados do período), unidades de itens canceladas, comandas canceladas e descontos em vigor (quem deu o último desconto, pela auditoria).
- **Acordo:** consumo = unidades não canceladas e valor (igual à venda do evento) das comandas do evento que contam na venda.
- **Parcial (RN-07.06):** a resposta traz `partial: true`; o app mostra a faixa.
- **Acesso (RN-07.07):** só o dono, também no relatório do caixa (decisão do usuário em 2026-10-02) (e o admin em "entrar como", que age como o dono); colaborador recebe 403, mesmo operando caixa. Recurso de outra organização: 404.
- **Histórico migrado:** os turnos anteriores ao redesenho entram nos relatórios pelos dias e aberturas criados na migração (plano de desenvolvimento, fase 7.5). O link antigo `/painel/relatorios/turnos/{id}` redireciona para o relatório do dia daquele turno.

## 14. Questões abertas

- Exportação (CSV, PDF) e envio do relatório por e-mail ficaram fora do MVP; avaliar após o piloto, lembrando o limite de 10.000 e-mails por mês.
