# Specs do Varal

Especificações do MVP do Varal: um sistema de pedidos e caixa para barracas de feirinha, em que cada colaborador usa o próprio celular como estação de trabalho (balcão, cozinha, entrega).

Fonte das decisões: documento [Varal — Escopo do MVP](https://claude.ai/code/artifact/57311d5e-1f4b-4c92-a53e-2574eade0a3a). Quando uma spec e o documento divergirem, a spec mais recente vale e o documento deve ser atualizado.

## Índice

| # | Spec | Conteúdo |
| --- | --- | --- |
| 01 | [Fundação](01-fundacao.md) | Repositórios, contratos via OpenAPI, infraestrutura, convenções, multi-tenant, autenticação, auditoria, e-mail, tempo real, modo offline |
| 02 | [Admin da plataforma](02-admin-plataforma.md) | RBAC do admin, organizações, assinatura, comunicados, métricas, entrar como |
| 03 | [Configuração da unidade](03-configuracao-unidade.md) | Unidades, estações, etapas, cardápio, modificadores, colaboradores e permissões |
| 04 | [Turno e comandas](04-turno-comandas.md) | Turno, acordo, preços do turno, comandas, pedidos, itens, telas de balcão e estação |
| 05 | [Fechamento e caixa](05-fechamento-caixa.md) | Fechamento de comanda, descontos, pagamentos, caixas, sangria, suprimento, conferência |
| 06 | [Fiado](06-fiado.md) | Clientes, pendurar comanda, quitação |
| 07 | [Relatórios](07-relatorios.md) | Relatório do turno e histórico |
| 08 | [Identidade visual](08-identidade-visual.md) | Cores, status, tipografia, regras de interface |

Ordem sugerida de implementação: 01 → 03 → 04 → 05 → 06 → 07, com 02 em paralelo a partir de 03, e 08 aplicada desde a primeira tela.

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
| Turno | `Shift` | Período de trabalho de uma unidade, com abertura e fechamento |
| Venda direta | `direct_sale` | Tipo de turno habitual |
| Turno contratado | `contracted` | Tipo de turno para atender um evento com acordo |
| Acordo | `Agreement` | Condições comerciais de um turno contratado |
| Preço do turno | `ShiftPrice` | Preço de um produto válido só naquele turno |
| Comanda | `Tab` | A conta de um cliente dentro de um turno |
| Paga antes | `pay_first` | Modo de comanda paga no ato do pedido |
| Comanda aberta | `open_tab` | Modo de comanda que acumula pedidos e é paga no final |
| Pedido | `Order` | Uma rodada de itens enviada às estações |
| Item | `OrderItem` | Um produto pedido, com quantidade e modificadores |
| Caixa | `CashRegister` | Gaveta de recebimentos de um turno |
| Fundo de troco | `opening_float` | Dinheiro inicial do caixa |
| Sangria | `withdrawal` | Retirada de dinheiro do caixa |
| Suprimento | `deposit` | Reforço de dinheiro no caixa |
| Pagamento | `Payment` | Valor recebido em uma forma de pagamento |
| Fiado / Pendurada | `on_credit` | Comanda fechada sem pagamento, a receber |
| Quitada | `settled` | Comanda pendurada que foi paga depois |
| Cliente | `Customer` | Pessoa identificada para o fiado |
| Comunicado | `Announcement` | Aviso do admin da plataforma para os donos |
| Entrar como | `Impersonation` | Acesso do admin à conta de um dono, para suporte |
| Auditoria | `AuditLog` | Registro de quem fez o quê, quando e em qual aparelho |
