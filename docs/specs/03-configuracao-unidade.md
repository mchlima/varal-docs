# 03 — Configuração da unidade

## 1. Objetivo

Permitir que o dono deixe cada barraca pronta para operar: unidades, estações, fluxo de etapas, cardápio com modificadores e colaboradores com suas permissões.

## 2. Escopo

**Dentro**

- Unidades da organização.
- Estações e fluxo de etapas configuráveis, com template padrão.
- Roteamento de produtos para a estação de preparo.
- Cardápio: categorias, produtos, grupos de modificadores, modificadores, esgotado.
- Colaboradores: cadastro, permissões por unidade, redefinição de senha, link e QR de acesso.

**Fora**

- Copiar cardápio entre unidades.
- Fotos de produtos.
- Controle de estoque.
- Mais de um fluxo de etapas por unidade.

## 3. Unidades

- **RN-03.01** A organização tem pelo menos uma unidade. O dono cria, renomeia, ativa e desativa unidades.
- **RN-03.02** Uma unidade com turno aberto não pode ser desativada (`SHIFT_OPEN`). A última unidade ativa da organização também não (`LAST_ACTIVE_UNIT`).
- **RN-03.03** Uma unidade nova nasce com o template padrão de estações e fluxo (seção 4.4) e com o cardápio vazio.
- Configuração por unidade: `late_after_minutes` (padrão 15, de 1 a 240, alterável pelo dono), tempo a partir do qual um item na estação aparece como atrasado. O padrão de 15 minutos foi confirmado com o piloto.

## 4. Estações e fluxo

### 4.1 Estações

Uma estação é a tela que um colaborador abre no aparelho. Tipos:

| Tipo | Comportamento |
| --- | --- |
| `counter` (balcão de pedidos) | Abre comandas, lança pedidos, fecha contas, recebe pagamentos. Vê o varal de comandas |
| `queue` (fila) | Mostra os itens que estão nas etapas ligadas a ela e permite avançá-los |

- **RN-03.04** Cada unidade tem pelo menos uma estação `counter` e uma estação `queue`.
- Campos: nome (único na unidade), tipo, ordem de exibição, ativa.
- Estações nunca são apagadas, só desativadas. Uma estação usada pelo fluxo, por categoria ou por produto não pode ser desativada nem virar `counter` (`STATION_IN_USE`).

### 4.2 Fluxo de etapas

O fluxo é a sequência de etapas pela qual todo item passa, do pedido à entrega. Cada unidade tem um fluxo.

Cada etapa define em qual estação o item aparece enquanto estiver nela:

| Destino da etapa | Significado |
| --- | --- |
| `product_station` | A estação de preparo do produto (definida no roteamento, seção 4.3) |
| `fixed_station` | Uma estação escolhida, igual para todos os produtos |
| `none` | Etapa final: o item sai de todas as filas |

- **RN-03.05** O fluxo tem de 2 a 8 etapas. A última é sempre a única com destino `none` e é marcada como final.
- **RN-03.06** Toda etapa não final aponta para uma estação do tipo `queue`.
- **RN-03.07** Com turno aberto na unidade, o fluxo e as estações não podem ser alterados. A interface explica o motivo e sugere fechar o turno.
- O fluxo é salvo inteiro de uma vez, conferindo a `version` da unidade. Etapas que saem do fluxo são arquivadas (`archived_at`), não apagadas, porque itens de turnos passados apontam para elas. Erros de validação voltam juntos em `INVALID_WORKFLOW`.

### 4.3 Roteamento

- Cada categoria tem uma estação de preparo padrão; cada produto pode sobrepor a da categoria.
- **RN-03.08** A estação de preparo de um item é: a do produto, se definida; senão, a da categoria. Ela precisa ser do tipo `queue`.
- O roteamento é resolvido no momento do pedido e gravado no item (spec 04); mudar o roteamento depois não move itens já pedidos.

### 4.4 Template padrão

| Estação | Tipo |
| --- | --- |
| Balcão | `counter` |
| Cozinha | `queue` |
| Balcão de entrega | `queue` |

| Ordem | Etapa | Destino | Estação |
| --- | --- | --- | --- |
| 1 | Recebido | `product_station` | (a do produto; padrão Cozinha) |
| 2 | Preparando | `product_station` | (a do produto; padrão Cozinha) |
| 3 | Pronto | `fixed_station` | Balcão de entrega |
| 4 | Entregue | `none` | — (final) |

Toda categoria nova recebe Cozinha como estação de preparo padrão.

Exemplo de personalização: uma barraca de espeto e pastel cria a estação Fritadeira e liga a categoria Pastéis a ela; espetos continuam na Cozinha e os dois chegam ao mesmo Balcão de entrega.

## 5. Cardápio

### 5.1 Categorias e produtos

- Categoria: nome (único na unidade), ordem, estação de preparo padrão, ativa.
- Produto: categoria, nome, descrição curta opcional (até 120 caracteres), preço em centavos, estação de preparo opcional, ordem, ativo, esgotado.
- **RN-03.09** Preço de produto é maior ou igual a zero.
- **RN-03.10** Produto inativo não aparece no balcão. Produto esgotado aparece no balcão bloqueado, com a marca "Esgotado".
- **RN-03.11** Marcar e desmarcar esgotado pode ser feito pelo dono e por qualquer colaborador com acesso a uma estação da unidade, a qualquer momento, inclusive com turno aberto. A mudança chega a todos os balcões em tempo real.
- **RN-03.12** Alterar preço, nome ou modificadores com turno aberto é permitido e vale para pedidos novos; itens já pedidos guardam o preço do momento.

### 5.2 Modificadores

- Grupo de modificadores: produto, nome (ex.: "Ponto da carne"), mínimo e máximo de escolhas, ordem.
- Modificador: grupo, nome (ex.: "Ao ponto"), acréscimo de preço em centavos (pode ser zero), ordem, ativo.
- **RN-03.13** `0 ≤ mínimo ≤ máximo`, e `máximo ≥ 1`. Um grupo com mínimo ≥ 1 é obrigatório: o balcão não envia o item sem a escolha.
- Um grupo de modificadores pode ser apagado de verdade (com as opções), porque o item do pedido guarda a cópia do que foi escolhido (spec 04, RN-04.18).
- **RN-03.14** Remoção de ingrediente é modelada como modificador com acréscimo zero (ex.: grupo "Retirar", mínimo 0, máximo 5, opções "Sem cebola", "Sem farofa").
- Além dos modificadores, cada item aceita uma observação livre (até 140 caracteres) no momento do pedido.

## 6. Colaboradores

- **RN-03.15** O dono cadastra colaborador com nome, username, senha inicial e e-mail opcional. Regras de username e senha na spec 01.
- **RN-03.16** Permissões por unidade: quais estações o colaborador pode abrir e se pode operar caixa. Um colaborador sem nenhuma unidade ativa liberada não consegue entrar (login recusado com `STAFF_WITHOUT_UNIT`).
- Mudança de permissão, de unidade ou de estação de um colaborador reconecta os aparelhos dele no tempo real (`session.access_changed`); remover todas as unidades encerra as sessões (motivo `staff_access_removed`). As estações liberadas só aceitam estações ativas da mesma unidade.
- **RN-03.17** Desativar colaborador encerra as sessões dele na hora (spec 01). Colaborador desativado continua aparecendo no histórico e na auditoria.
- **RN-03.18** Redefinir senha: o dono clica em "Redefinir senha"; o sistema gera o link (spec 01) e mostra três opções: enviar por e-mail (se houver e-mail), copiar link e enviar por WhatsApp (abre `https://wa.me/?text=` com a mensagem e o link).
- **RN-03.19** O dono também pode definir uma nova senha diretamente, sem link.
- Acesso: o painel mostra o código do estabelecimento, o link `/e/{code}` com botão de copiar e o QR code desse link, em tamanho próprio para ser escaneado de outro celular.

## 7. Modelo de dados

Toda tabela abaixo tem `organization_id`.

**stations**: `unit_id`, `name`, `kind` (`counter`, `queue`), `sort_order`, `active`. Único `(unit_id, lower(name))`.

**workflow_stages**: `unit_id`, `name`, `sort_order`, `target` (`product_station`, `fixed_station`, `none`), `station_id` (obrigatório só para `fixed_station`), `is_final bool`, `archived_at`. Único `(unit_id, sort_order)` entre as não arquivadas.

**units** ganha `version` (fluxo e configuração) e `menu_version` (enviada no `menu.updated`); **products** ganha `version`.

**categories**: `unit_id`, `name`, `sort_order`, `default_station_id`, `active`.

**products**: `unit_id`, `category_id`, `name`, `description`, `price_cents int`, `station_id` (opcional), `sort_order`, `active`, `sold_out bool`.

**modifier_groups**: `product_id`, `name`, `min_choices int`, `max_choices int`, `sort_order`.

**modifiers**: `modifier_group_id`, `name`, `price_delta_cents int`, `sort_order`, `active`.

Colaboradores e permissões: tabelas `staff_members` e `staff_unit_permissions` da spec 01.

## 8. API

Todas exigem perfil dono, exceto onde indicado.

| Método e rota | Descrição |
| --- | --- |
| `GET/POST /api/v1/units`, `PATCH /api/v1/units/{id}` | Unidades |
| `GET /api/v1/units/{id}/stations`, `POST`, `PATCH /stations/{id}` | Estações |
| `GET /api/v1/units/{id}/workflow`, `PUT /api/v1/units/{id}/workflow` | Fluxo completo, salvo de uma vez (validado pelas RN-03.05 a 03.07) |
| `GET /api/v1/units/{id}/menu` | Cardápio completo da unidade (dono e colaboradores da unidade) |
| `POST/PATCH /api/v1/categories`, `PUT /api/v1/units/{id}/categories/order` | Categorias e ordenação |
| `POST/PATCH /api/v1/products`, `PUT /api/v1/categories/{id}/products/order` | Produtos e ordenação |
| `POST /api/v1/products/{id}/sold-out`, `DELETE /api/v1/products/{id}/sold-out` | Esgotado (dono e colaboradores da unidade) |
| `POST/PATCH/DELETE /api/v1/modifier-groups`, `POST/PATCH /api/v1/modifiers` | Modificadores |
| `GET/POST /api/v1/staff`, `PATCH /api/v1/staff/{id}` | Colaboradores |
| `PUT /api/v1/staff/{id}/permissions` | Permissões por unidade |
| `POST /api/v1/staff/{id}/password-reset` | Gera link; resposta traz o link para copiar/WhatsApp |
| `PUT /api/v1/staff/{id}/password` | Dono define a senha diretamente |
| `GET /api/v1/organization/access` | Código, link e QR (SVG) |

Eventos em tempo real (sala `unit:{unitId}`):

| Evento | Quando | Payload |
| --- | --- | --- |
| `product.sold_out_changed` | Produto marcado ou desmarcado como esgotado | `productId`, `soldOut` |
| `menu.updated` | Qualquer outra alteração no cardápio | `unitId`, `version` (o app recarrega o cardápio) |
| `unit.config_updated` | Alteração na unidade, nas estações ou no fluxo | `unitId`, `version` (o app recarrega a configuração) |

## 9. Telas (painel do dono)

| Tela | Conteúdo e ações |
| --- | --- |
| Unidades | Lista, criar, renomear, ativar/desativar, tempo de atraso |
| Estações e fluxo | Lista de estações; editor do fluxo com etapas em ordem, destino de cada etapa e etapa final; aviso de bloqueio com turno aberto |
| Cardápio | Categorias em abas ou lista; produtos com preço, estação, esgotado; arrastar para ordenar; editor de produto com grupos de modificadores |
| Colaboradores | Lista com situação; cadastro; permissões por unidade (estações e caixa); redefinir senha com as três opções de envio |
| Acesso da equipe | Código, link com botão copiar, QR code grande |

No balcão e nas estações, o colaborador pode marcar produto como esgotado por um atalho no próprio cardápio.

## 10. Critérios de aceite

- **CA-03.01** Uma unidade nova tem as estações Balcão, Cozinha e Balcão de entrega e as etapas Recebido, Preparando, Pronto e Entregue, como na seção 4.4.
- **CA-03.02** A API recusa salvar um fluxo sem etapa final, com mais de uma etapa final ou com etapa não final apontando para estação `counter`.
- **CA-03.03** Com turno aberto, a API recusa alterar fluxo e estações com o erro `SHIFT_OPEN`.
- **CA-03.04** Um produto com estação própria vai para essa estação; sem ela, vai para a da categoria.
- **CA-03.05** Marcar um produto como esgotado no celular da cozinha bloqueia o produto no balcão em até 2 segundos, sem recarregar a tela.
- **CA-03.06** O balcão não permite enviar um item com grupo obrigatório sem escolha.
- **CA-03.07** Dois colaboradores com o mesmo username na mesma organização são recusados; em organizações diferentes, aceitos.
- **CA-03.08** O link de redefinição gerado pelo dono abre a tela de nova senha e funciona uma única vez.

## 11. Questões abertas

- Limite de unidades, produtos e colaboradores por organização no MVP (sugestão: sem limite no piloto).
