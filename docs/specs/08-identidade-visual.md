# 08 — Identidade visual

## 1. Objetivo

Definir as regras visuais do `varal-panel-web` e do `varal-admin-web` para que as telas sejam fáceis de ver ao sol, simples, modernas, sem cara de gerada por IA, e com ações claras e fáceis de operar com uma mão.

Referência visual das opções avaliadas: [Cores do Varal](https://claude.ai/artifact/Mg6NLUCqsFW3r9c4ZhTin6).

## 2. Princípios

1. **Sol primeiro.** Tema claro, contraste alto, nada de cinza claro sobre branco para informação importante.
2. **Uma ação principal por tela.** Ela é o único botão preenchido com a cor primária; o resto é contorno ou texto.
3. **Status nunca só por cor.** Sempre texto e ícone junto.
4. **Grande onde se toca.** Alvos de toque de pelo menos 48 px; botões principais com pelo menos 52 px de altura.
5. **Números em destaque.** Número da comanda, quantidade e valores em fonte maior e com algarismos de largura fixa.
6. **Sem enfeite.** Sem degradês, sombras pesadas, ilustrações genéricas ou emojis como ícones.

## 3. Cores

Tokens mantidos nos dois apps como variáveis CSS, com esta tabela como fonte. Uma mudança de token é feita na spec e nos dois apps.

| Token | Valor | Uso |
| --- | --- | --- |
| `--color-primary` | `#BE185D` | Framboesa: ação principal, item novo, seleção forte |
| `--color-primary-ink` | `#FFFFFF` | Texto sobre a primária (contraste 6,0:1) |
| `--color-primary-soft` | `#FCE7F3` | Fundo de aba ativa, linha selecionada |
| `--color-primary-deep` | `#831843` | Texto e links na cor da marca, texto sobre `primary-soft` |
| `--color-bg` | `#F3F4F2` | Fundo das telas |
| `--color-surface` | `#FFFFFF` | Cartões e painéis |
| `--color-surface-muted` | `#F6F7F5` | Cartões dentro de listas |
| `--color-text` | `#111315` | Texto principal |
| `--color-text-muted` | `#5A6067` | Texto secundário (mínimo 4,5:1 sobre `surface`) |
| `--color-border` | `#D9DCD8` | Divisórias e bordas decorativas (cartões, separadores) |
| `--color-border-strong` | `#7A8085` | Borda de componentes que precisam ser vistos: campos, botões de contorno, caixas de seleção (3:1 ou mais sobre `bg`, `surface` e `surface-muted`) |
| `--color-focus` | `#111315` | Anel de foco do teclado |

Os neutros têm leve tom esverdeado-acinzentado para não parecerem cinza padrão.

## 4. Cores de status

| Status | Fundo | Texto | Ícone | Regra |
| --- | --- | --- | --- | --- |
| Novo | `#BE185D` | `#FFFFFF` | ponto cheio | Usa a primária |
| Preparando | `#FDE68A` | `#713F12` | relógio | |
| Pronto | `#BBF7D0` | `#14532D` | confirmação | |
| Atenção | `#FDBA74` | `#7C2D12` | ampulheta | Tempo do cartão da estação entre o limite de atenção e o de atraso (spec 04, RN-04.46). Laranja mais saturado que o amarelo de "Preparando" e sem o tom rosado do "Atrasado"; contraste do texto 5,6:1 (AA). Tokens `--color-status-attention-bg` e `--color-status-attention-ink` |
| Atrasado | `#FECACA` | `#7F1D1D` | exclamação | Nunca vermelho sólido, para não se confundir com a primária |
| Cancelado | `#E2E8F0` | `#334155` | — | Texto riscado |

As etapas personalizadas de cada unidade (spec 03) usam a cor do status equivalente: a primeira etapa é "Novo", as intermediárias "Preparando", a anterior à final "Pronto", a final "Entregue" (cinza neutro).

Erro de formulário usa `#B91C1C` em texto sobre fundo branco, com ícone e mensagem.

## 5. Tipografia **(proposta, a validar)**

| Papel | Fonte | Uso |
| --- | --- | --- |
| Texto | Atkinson Hyperlegible (400, 700) | Interface em geral; desenhada para máxima legibilidade |
| Destaque | Bricolage Grotesque (600, 800) | Títulos, número da comanda, totais |

- Fontes servidas pelo próprio app (arquivos no build), sem depender de serviço externo, para funcionar com conexão ruim.
- Escala: 13, 15, 17, 20, 24, 32 px. Texto corrente 17 px no celular.
- Números com `font-variant-numeric: tabular-nums`.

## 6. Componentes

| Componente | Regras |
| --- | --- |
| Botão principal | Fundo primário, texto branco 17 px negrito, altura mínima 52 px, cantos de 10 px, largura total no celular |
| Botão secundário | Contorno de 2 px na primária, texto `primary-deep`, altura mínima 44 px |
| Botão de confirmação de valor | Mostra valor e forma: "Confirmar R$ 46,00 no Pix" |
| Ação destrutiva | Texto vermelho escuro em menu secundário, sempre com confirmação na própria tela (nada de diálogo do navegador) |
| Cartão de comanda | Número grande à esquerda, nome e resumo ao centro, total à direita; borda esquerda primária quando selecionado |
| Cartão de pedido (estação) | Um cartão por pedido, nunca por item (spec 04, RN-04.40). Cabeçalho com número da comanda em 24 px, nome, "Adicional" quando for, e tempo decorrido em algarismos de largura fixa; o fundo do cabeçalho usa a cor de status ("Novo" até ser tocado; depois o nível de tempo: neutro, "Atenção" ou "Atrasado"), sempre com o texto do nível e o ícone, nunca só a cor, porque laranja, amarelo e vermelho claros se confundem no sol. Linhas com quantidade e produto em 20 px negrito, modificadores logo abaixo e observação em bloco com fundo `primary-soft`, texto `primary-deep` e ícone; chip da etapa em cada linha; linha feita riscada com ícone de confirmação; linha cancelada riscada com o chip "Cancelado". Botão de avanço do pedido no estilo secundário (contorno), ocupando a largura do cartão, com pelo menos 56 px: com vários cartões na tela, nenhum deles usa o botão preenchido com a primária (CA-08.02) |
| Chip de status | Cantos de 6 px, texto em maiúsculas com espaçamento leve, ícone de 14 px |
| Faixa de operação (balcão) | Caixa aberto, tabela de preço efetiva e evento em andamento (spec 04, seção 8.1). Tabela diferente de "Normal" e evento usam fundo `primary-soft` e texto `primary-deep`, com ícone; tabela "Normal" em texto neutro |
| Faixa de aviso | Topo da tela, largura total: sem conexão, relatório com valores parciais, organização suspensa, "entrar como" (esta última em cor própria, escura, para nunca passar despercebida) |

Cantos arredondados variam por função (6, 10, 12 px), não um único raio para tudo.

## 7. Layout

- Celular primeiro: largura de referência 360–430 px, com uma coluna.
- Tablet, TV e computador: as estações ocupam **toda a largura da tela**, com colunas de cartões de largura fixa (cerca de 300 px) e tantas colunas quantas couberem (spec 04, seção 8.2); balcão mostra varal e comanda lado a lado. As demais telas de operação continuam com largura máxima de leitura.
- Painel do dono e admin: navegação lateral a partir de 1024 px; abaixo disso, menu inferior.
- Ação principal fixa no rodapé nas telas de operação (balcão, receber), alcançável com o polegar. Na estação, a ação principal fica em cada cartão.
- Início do painel: a ação principal do momento (spec 01, RN-01.24) é o único botão preenchido, no topo, em largura total no celular; o resto da página é secundário.

## 8. Acessibilidade

- Contraste mínimo AA (4,5:1) em todo texto; 3:1 em bordas de componentes.
- Foco de teclado visível em todos os elementos interativos.
- Respeitar `prefers-reduced-motion`.
- Alertas sonoros sempre acompanhados de sinal visual e vibração.

## 9. Logo

Versão provisória (2026-10-01), até haver um logo definitivo. Os arquivos ficam em [`docs/brand/`](../brand/).

- **Símbolo:** uma comanda (papel com a borda de baixo picotada) presa por um pregador num fio levemente curvo. É o varal de comandas que dá nome ao produto.
- **Nome:** "varal" em minúsculas, desenhado em traço contínuo com pontas redondas, da mesma espessura do fio. Não depende de fonte instalada.
- **Cores:** comanda em Framboesa `#BE185D`, fio, pregador e nome em Framboesa profundo `#831843`. A versão de uma cor (`logo-mono.svg`) usa `currentColor`, para ficar preta, branca ou na cor do texto.
- **Ícone e favicon:** quadrado de cantos arredondados em Framboesa com o símbolo em branco; legível em 16 px.

| Arquivo | Uso |
| --- | --- |
| `logo.svg` | Logo horizontal colorido (login, cabeçalhos, e-mails) |
| `logo-mono.svg` | Logo em uma cor (`currentColor`) |
| `logo-symbol.svg` | Só o símbolo, colorido, fundo transparente |
| `favicon.svg` | Favicon dos dois apps |
| `apple-touch-icon.png` | Ícone do iOS (180 px, sangrado) |
| `icon-192.png`, `icon-512.png` | Ícones do manifesto do PWA (`purpose: any`) |
| `icon-maskable.svg`, `icon-maskable-512.png` | Ícone do manifesto com `purpose: maskable` (símbolo dentro da zona segura de 80%) |

- **RN-08.01** Os apps `varal-panel-web` e `varal-admin-web` copiam os arquivos de `docs/brand/` para o próprio `public/`; não redesenham o logo. Mudança no logo é feita aqui e copiada para os dois.

## 10. Critérios de aceite

- **CA-08.01** Todos os pares de cor de texto e fundo usados passam AA, verificado por teste automatizado nos tokens.
- **CA-08.02** Nenhuma tela de operação tem mais de um botão preenchido com a primária.
- **CA-08.03** Todos os status aparecem com texto e ícone.
- **CA-08.04** Os alvos de toque das telas de balcão e estação medem pelo menos 48 × 48 px.
- **CA-08.05** O botão "Painel" e o "Trocar de estação" das telas de operação (spec 01, RN-01.25) medem pelo menos 48 × 48 px e têm texto, não só ícone.
- **CA-08.06** O par de cor de "Atenção" passa AA no teste automatizado dos tokens, e o cabeçalho em atenção mostra o texto "Atenção" e o ícone de ampulheta.

## 11. Questões abertas

- Tipografia: validar Atkinson Hyperlegible e Bricolage Grotesque.
- Modo escuro para feiras à noite: fora do MVP **(proposta)**; os tokens já permitem adicionar depois.
- Logo definitivo: o atual é provisório.
