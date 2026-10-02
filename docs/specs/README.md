# Specs do Varal

Especificações do MVP do Varal: um sistema de pedidos e caixa para barracas de feirinha, em que cada colaborador usa o próprio celular como estação de trabalho (balcão, cozinha, entrega).

Fonte das decisões: documento [Varal — Escopo do MVP](https://claude.ai/code/artifact/57311d5e-1f4b-4c92-a53e-2574eade0a3a). Quando uma spec e o documento divergirem, a spec mais recente vale e o documento deve ser atualizado.

## Índice

| # | Spec | Conteúdo |
| --- | --- | --- |
| 01 | [Fundação](01-fundacao.md) | Repositórios, contratos via OpenAPI, infraestrutura, convenções, multi-tenant, autenticação, auditoria, e-mail, tempo real, modo offline |
| 02 | [Admin da plataforma](02-admin-plataforma.md) | RBAC do admin, organizações, assinatura, comunicados, métricas, entrar como |
| 03 | [Configuração da unidade](03-configuracao-unidade.md) | Unidades, estações, etapas, cardápio, modificadores, tabelas de preço, colaboradores e permissões |
| 04 | [Operação e comandas](04-operacao-comandas.md) | Dia de operação, tabela vigente, eventos contratados, comandas, pedidos, itens, telas de balcão e estação (KDS) |
| 05 | [Fechamento e caixa](05-fechamento-caixa.md) | Fechamento de comanda, descontos, pagamentos, caixas da unidade, abrir e fechar caixa, sangria, suprimento, conferência |
| 06 | [Fiado](06-fiado.md) | Clientes, pendurar comanda, quitação |
| 07 | [Relatórios](07-relatorios.md) | Relatório do dia ou período, do caixa e do evento; histórico |
| 08 | [Identidade visual](08-identidade-visual.md) | Cores, status, tipografia, regras de interface |

Ordem sugerida de implementação: 01 → 03 → 04 → 05 → 06 → 07, com 02 em paralelo a partir de 03, e 08 aplicada desde a primeira tela. O [plano de desenvolvimento](../plano-de-desenvolvimento.md) detalha fases, versões e escolhas técnicas.

## Formato de cada spec

1. **Objetivo**: o que o módulo entrega.
2. **Escopo**: o que entra e o que fica fora.
3. **Regras de negócio**: numeradas por módulo (ex.: `RN-04.07`), para serem citadas em código, testes e PRs.
4. **Modelo de dados**: tabelas, colunas e restrições.
5. **API**: endpoints REST e eventos em tempo real.
6. **Telas**: o que cada tela mostra e permite.
7. **Critérios de aceite**: numerados (ex.: `CA-04.03`), verificáveis por teste.
8. **Questões abertas**: o que ainda precisa de decisão.

Itens marcados como **(proposta)** são escolhas técnicas feitas na escrita da spec e ainda não confirmadas.

Regras e critérios nunca são renumerados. Quando uma regra deixa de valer, ela fica no lugar marcada como *(removida em AAAA-MM-DD)*; quando muda, como *(reescrita)* ou *(ajustada)*. Assim as citações em código, testes e PRs continuam rastreáveis.

## O dia a dia na barraca

Redesenho de 2026-10-02, depois do primeiro teste real (o turno confundia):

1. **Abrir o caixa** (informa o fundo de troco). É o que começa o dia e libera vender (spec 05).
2. **Vender no balcão**: comandas abertas ou pagas antes, com os preços da **tabela vigente** ("Normal" ou uma tabela salva, como "Evento"), trocada com um toque (spec 04).
3. **Preparar nas estações**: cada pedido é um cartão na tela da cozinha, avançado por item ou inteiro (spec 04, seção 8.2).
4. **Receber**: o pagamento entra no caixa aberto (spec 05); quem não paga na hora vai para o fiado (spec 06).
5. **Fechar o caixa** (contagem por forma e diferença). Comandas ainda abertas não impedem: ficam pendentes e seguem para o próximo dia (spec 05).
6. **Ver os relatórios** do dia, do caixa ou do evento (spec 07).

O **evento contratado** (casamento, festa) é opcional: cadastrado com contratante, data, acordo e tabela de preço, ele liga as comandas a si enquanto está em andamento (spec 04, seção 3.3).

## Convenções

- **Idioma:** toda a codebase em inglês (código, banco de dados, rotas da API, eventos, chaves de permissão). Interface, mensagens ao usuário, **rotas do front** e documentação em português do Brasil. Os arquivos de `pages/` do Nuxt seguem a rota em português, por causa do roteamento por arquivo. Rotas do front na spec 01, seção 14.
- **Identificadores:** UUID v7 em todas as tabelas.
- **Dinheiro:** inteiros em centavos de real, colunas com sufixo `_cents`. Nunca ponto flutuante.
- **Data e hora:** `timestamptz` em UTC no banco; exibição no fuso `America/Sao_Paulo`.
- **Multi-tenant:** toda tabela de dados de cliente tem `organization_id`.
- **Exclusão:** registros operacionais (comandas, pedidos, pagamentos, movimentos de caixa) nunca são apagados; são cancelados. Cadastros (produtos, colaboradores) são desativados.

## Glossário

| Português (interface) | Inglês (código) | Definição |
| --- | --- | --- |
| Organização | `Organization` | O assinante do Varal; o tenant |
| Unidade | `Unit` | Uma barraca da organização |
| Dono | `Owner` | Usuário que administra a organização |
| Colaborador | `StaffMember` | Quem trabalha na barraca, com login próprio |
| Admin da plataforma | `PlatformAdmin` | Usuário da equipe do Varal |
| Papel | `Role` | Grupo de permissões do admin da plataforma |
| Permissão | `Permission` | Ação permitida no admin, no formato `recurso:ação` |
| Estação | `Station` | Papel assumido no aparelho: Balcão, Cozinha, Balcão de entrega |
| Etapa | `Stage` | Situação de um item no fluxo de preparo |
| Fluxo | `Workflow` | Sequência de etapas de uma unidade |
| Categoria | `Category` | Agrupamento de produtos do cardápio |
| Produto | `Product` | Item vendável |
| Grupo de modificadores | `ModifierGroup` | Conjunto de opções de um produto (ex.: Ponto da carne) |
| Modificador | `Modifier` | Uma opção (ex.: Ao ponto, Sem farofa) |
| Preço normal | `Product.price_cents` | Preço do produto no cardápio, usado quando a tabela vigente é "Normal" ou o produto não tem preço na tabela vigente |
| Tabela de preço | `PriceList` | Lista salva de preços alternativos de uma unidade (ex.: "Evento"), com preço opcional por produto |
| Tabela vigente | `current_price_list_id` | Tabela que vale para itens novos na unidade ("Normal" ou uma tabela de preço) |
| Evento | `ContractedEvent` | Atendimento contratado (casamento, festa), com contratante, data, acordo e tabela de preço |
| Acordo | `Agreement` | Condições comerciais de um evento (modalidade, valor, quantidade, limites) |
| Dia de operação | `business_date` | Data da unidade que agrupa vendas e caixas; muda ao abrir o primeiro caixa num dia novo |
| Comanda | `Tab` | A conta de um cliente na unidade; pode passar de um dia para o outro enquanto estiver aberta |
| Paga antes | `pay_first` | Modo de comanda paga no ato do pedido |
| Comanda aberta | `open_tab` | Modo de comanda que acumula pedidos e é paga no final |
| Pedido | `Order` | Uma rodada de itens enviada às estações |
| Item | `OrderItem` | Um produto pedido, com quantidade e modificadores |
| Caixa | `CashRegister` | Gaveta de recebimentos cadastrada na unidade (ex.: "Caixa 1", "Balcão") |
| Abertura de caixa | `CashRegisterSession` | Período de um caixa entre abrir e fechar, com fundo, movimentos, pagamentos e conferência |
| Fundo de troco | `opening_float` | Dinheiro inicial de uma abertura de caixa |
| Sangria | `withdrawal` | Retirada de dinheiro do caixa |
| Suprimento | `deposit` | Reforço de dinheiro no caixa |
| Pagamento | `Payment` | Valor recebido em uma forma de pagamento |
| Fiado / Pendurada | `on_credit` | Comanda fechada sem pagamento, a receber |
| Quitada | `settled` | Comanda pendurada que foi paga depois |
| Cliente | `Customer` | Pessoa identificada para o fiado |
| Comunicado | `Announcement` | Aviso do admin da plataforma para os donos |
| Entrar como | `Impersonation` | Acesso do admin à conta de um dono, para suporte |
| Auditoria | `AuditLog` | Registro de quem fez o quê, quando e em qual aparelho |

**Termos que saíram** (2026-10-02): *Turno* (`Shift`), *venda direta* (`direct_sale`), *turno contratado* (`contracted`) e *preço do turno* (`ShiftPrice`). O que o turno fazia ficou com a abertura de caixa e o dia de operação; o turno contratado virou o evento; os preços do turno viraram tabelas de preço. Os nomes antigos só aparecem na migração (plano de desenvolvimento, fase 7.5).
