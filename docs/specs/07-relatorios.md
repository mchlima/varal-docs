# 07 — Relatórios

## 1. Objetivo

Responder ao dono, ao fim de cada turno e ao longo do tempo: quanto vendeu, do quê, como recebeu, quanto ficou no fiado, o que se perdeu e se o caixa bateu.

## 2. Escopo

**Dentro**

- Relatório do turno, disponível em tempo real com o turno aberto e definitivo depois do fechamento.
- Histórico de turnos por unidade e período, com totais.

**Fora**

- Exportação em CSV ou PDF.
- Gráficos de tendência e comparação entre unidades.
- Custo de produtos e margem.

## 3. Regras de cálculo

- **RN-07.01** Venda do turno = soma do total (após desconto) das comandas do turno em `paid`, `on_credit` ou `settled`. Comandas `canceled` ficam fora.
- **RN-07.02** Recebido no turno = soma dos pagamentos não estornados cujo `shift_id` é o turno, separando vendas do turno e quitações de fiado de outros turnos.
- **RN-07.03** Pendurado no turno = soma dos saldos das comandas do turno que foram penduradas, no valor do momento em que foram penduradas.
- **RN-07.04** Quantidades por produto contam itens não cancelados; perdas contam itens cancelados com `wasted = true`.
- **RN-07.05** Todos os valores usam o preço gravado no item (spec 04, RN-04.18), não o preço atual do cardápio.
- **RN-07.06** Relatório de turno aberto mostra a faixa "Turno em andamento — valores parciais".

## 4. Relatório do turno

| Seção | Conteúdo |
| --- | --- |
| Resumo | Unidade, tipo do turno, abertura e fechamento (quem e quando), venda do turno, número de comandas, ticket médio, total de descontos |
| Por produto | Produto, quantidade, valor; ordenado por valor; inclui modificadores com acréscimo |
| Por forma de pagamento | Pix, dinheiro, crédito, débito: valor de vendas do turno e de quitações de fiado, separados |
| Por colaborador | Comandas abertas, pedidos lançados, valor recebido, cancelamentos e descontos feitos |
| Caixas | Para cada caixa: responsável, fundo, sangrias, suprimentos, esperado, informado e diferença por forma, observação |
| Fiado | Comandas penduradas no turno (cliente e valor) e quitações recebidas no turno |
| Cancelamentos e perdas | Itens cancelados com motivo, quem cancelou e se foi perda; comandas canceladas |
| Acordo (turno contratado) | Contratante, modalidade, valor e quantidade combinados, limites; consumo registrado em quantidade e valor; diferença entre quantidade combinada e consumida |

## 5. Histórico

- Lista de turnos da unidade (ou de todas) num período, mais recentes primeiro, com: data, unidade, tipo, venda, recebido, pendurado, diferença de caixa.
- Totais do período no topo: venda, recebido, pendurado, perdas, descontos.
- Filtros: unidade, período (atalhos: hoje, 7 dias, 30 dias, mês atual), tipo do turno.
- A partir do histórico, abre-se o relatório de cada turno.

## 6. Acesso

- **RN-07.07** Relatórios ficam no painel do dono. Colaboradores não veem relatórios no MVP.
- O admin da plataforma vê os mesmos relatórios apenas durante um "entrar como" (spec 02).

## 7. Modelo de dados

Sem tabelas novas: relatórios são consultas sobre turnos, comandas, itens, pagamentos e caixas. Se as consultas ficarem lentas, criar visões materializadas por turno, atualizadas no fechamento.

## 8. API

| Método e rota | Descrição |
| --- | --- |
| `GET /api/v1/shifts/{id}/report` | Relatório completo do turno (seção 4) |
| `GET /api/v1/reports/shifts?unitId=&from=&to=&type=&limit=&cursor=` | Histórico com totais (seção 5), paginado por cursor |

## 9. Telas

| Tela | Conteúdo |
| --- | --- |
| Relatório do turno | Seções da tabela 4, com o resumo no topo e as demais recolhíveis; legível no celular |
| Histórico | Totais do período e lista de turnos com filtros |

## 10. Critérios de aceite

- **CA-07.01** Num turno com uma comanda paga de R$ 80,00, uma pendurada de R$ 100,00 e uma cancelada, a venda do turno é R$ 180,00, o recebido é R$ 80,00 e o pendurado é R$ 100,00.
- **CA-07.02** Uma quitação de fiado recebida hoje, de comanda de ontem, aparece no recebido de hoje como quitação e não entra na venda de hoje.
- **CA-07.03** O relatório de um turno contratado com quantidade combinada de 500 e 462 itens consumidos mostra diferença de 38.
- **CA-07.04** A diferença de caixa informada no fechamento aparece no relatório e no histórico.
- **CA-07.05** Mudar o preço de um produto depois do turno não altera o relatório desse turno.
- **CA-07.06** Um colaborador recebe 403 ao pedir um relatório.

## 11. Decisões da implementação (fase 7)

- **Datas:** `from` e `to` são dias em America/Sao_Paulo (`AAAA-MM-DD`, `to` inclusive); um turno entra no período pelo dia da abertura. Sem datas, os últimos 30 dias até hoje; o período vai de 1 a 366 dias. Os atalhos (hoje, 7 dias, 30 dias, mês atual) são do app.
- **Histórico:** sem `unitId`, traz todas as unidades da organização. Inclui turnos abertos (valores parciais). Ordenado pela abertura, mais recente primeiro, paginado por cursor (`limit` até 100); os totais do topo são do período inteiro, não só da página. Cada linha traz também número de comandas, perdas e descontos.
- **Pendurado (RN-07.03):** total da comanda menos os pagamentos feitos antes de pendurar (que não podem mais ser estornados, spec 06). Conta comandas hoje em `on_credit` ou já `settled`; o relatório mostra também o saldo atual de cada uma.
- **Recebido (RN-07.02):** pagamentos não estornados com `shift_id` do turno, separados em vendas do turno e quitações de fiado, no total e por forma de pagamento.
- **Perdas (RN-07.04):** itens cancelados com `wasted` de qualquer comanda do turno, inclusive das canceladas, em valor e unidades.
- **Por produto:** só itens não cancelados das comandas que contam na venda, agrupados pela cópia do vendido (produto e nome gravado); o valor é antes do desconto da comanda (o desconto aparece no resumo). Modificadores com acréscimo aparecem dentro do produto, com quantidade e valor.
- **Por colaborador:** inclui o dono. Comandas abertas, pedidos lançados, recebido (pagamentos não estornados do turno), unidades de itens canceladas, comandas canceladas e descontos em vigor (quem deu o último desconto, pela auditoria).
- **Caixas:** os mesmos dados de `GET /shifts/{id}/cash-registers` (esperado, informado e diferença por forma, sangrias, suprimentos, observação), com o responsável e a diferença total. A diferença de caixa do turno é a soma das diferenças gravadas no fechamento de cada caixa.
- **Acordo:** consumo = unidades não canceladas e valor (igual à venda) das comandas que contam na venda; diferença = quantidade combinada − consumida (negativa se passou do combinado; vazia sem quantidade combinada).
- **Turno aberto (RN-07.06):** a resposta traz `partial: true`; o app mostra a faixa.
- **Acesso (RN-07.07):** só o dono (e o admin em "entrar como", que age como o dono); colaborador recebe 403, mesmo operando caixa. Turno ou unidade de outra organização: 404.
- **Desempenho:** os totais saem de uma única consulta agregada por turno, a mesma no relatório e no histórico; índices em `payments (organization_id, shift_id)` e `shifts (organization_id, opened_at)`. Sem visões materializadas por enquanto.

## 12. Questões abertas

- Exportação (CSV, PDF) e envio do relatório por e-mail ficaram fora do MVP; avaliar após o piloto, lembrando o limite de 10.000 e-mails por mês.
