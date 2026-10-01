# 08 — Identidade visual

## 1. Objetivo

Definir as regras visuais do app `web` e do `admin` para que as telas sejam fáceis de ver ao sol, simples, modernas, sem cara de gerada por IA, e com ações claras e fáceis de operar com uma mão.

Referência visual das opções avaliadas: [Cores do Varal](https://claude.ai/artifact/Mg6NLUCqsFW3r9c4ZhTin6).

## 2. Princípios

1. **Sol primeiro.** Tema claro, contraste alto, nada de cinza claro sobre branco para informação importante.
2. **Uma ação principal por tela.** Ela é o único botão preenchido com a cor primária; o resto é contorno ou texto.
3. **Status nunca só por cor.** Sempre texto e ícone junto.
4. **Grande onde se toca.** Alvos de toque de pelo menos 48 px; botões principais com pelo menos 52 px de altura.
5. **Números em destaque.** Número da comanda, quantidade e valores em fonte maior e com algarismos de largura fixa.
6. **Sem enfeite.** Sem degradês, sombras pesadas, ilustrações genéricas ou emojis como ícones.

## 3. Cores

Tokens em `packages/shared` (ou num pacote de UI compartilhado entre `web` e `admin`), expostos como variáveis CSS.

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
| `--color-border` | `#D9DCD8` | Bordas e divisórias |
| `--color-focus` | `#111315` | Anel de foco do teclado |

Os neutros têm leve tom esverdeado-acinzentado para não parecerem cinza padrão.

## 4. Cores de status

| Status | Fundo | Texto | Ícone | Regra |
| --- | --- | --- | --- | --- |
| Novo | `#BE185D` | `#FFFFFF` | ponto cheio | Usa a primária |
| Preparando | `#FDE68A` | `#713F12` | relógio | |
| Pronto | `#BBF7D0` | `#14532D` | confirmação | |
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
| Cartão de item (estação) | Quantidade e produto em 20 px negrito; modificadores e observação logo abaixo, observação em destaque; chip de status no topo; botão de avanço ocupando a largura |
| Chip de status | Cantos de 6 px, texto em maiúsculas com espaçamento leve, ícone de 14 px |
| Faixa de aviso | Topo da tela, largura total: sem conexão, turno em andamento, organização suspensa, "entrar como" (esta última em cor própria, escura, para nunca passar despercebida) |

Cantos arredondados variam por função (6, 10, 12 px), não um único raio para tudo.

## 7. Layout

- Celular primeiro: largura de referência 360–430 px, com uma coluna.
- Tablet: estações mostram a fila em duas ou três colunas; balcão mostra varal e comanda lado a lado.
- Painel do dono e admin: navegação lateral a partir de 1024 px; abaixo disso, menu inferior.
- Ação principal fixa no rodapé nas telas de operação (balcão, estação, receber), alcançável com o polegar.

## 8. Acessibilidade

- Contraste mínimo AA (4,5:1) em todo texto; 3:1 em bordas de componentes.
- Foco de teclado visível em todos os elementos interativos.
- Respeitar `prefers-reduced-motion`.
- Alertas sonoros sempre acompanhados de sinal visual e vibração.

## 9. Logo

Pendente. Conceito sugerido: o varal de comandas (fio, pregador, papel pendurado). O logo precisa funcionar em uma cor (Framboesa ou preto) e em tamanho de ícone de app (48 px).

## 10. Critérios de aceite

- **CA-08.01** Todos os pares de cor de texto e fundo usados passam AA, verificado por teste automatizado nos tokens.
- **CA-08.02** Nenhuma tela de operação tem mais de um botão preenchido com a primária.
- **CA-08.03** Todos os status aparecem com texto e ícone.
- **CA-08.04** Os alvos de toque das telas de balcão e estação medem pelo menos 48 × 48 px.

## 11. Questões abertas

- Tipografia: validar Atkinson Hyperlegible e Bricolage Grotesque.
- Modo escuro para feiras à noite: fora do MVP **(proposta)**; os tokens já permitem adicionar depois.
- Logo.
