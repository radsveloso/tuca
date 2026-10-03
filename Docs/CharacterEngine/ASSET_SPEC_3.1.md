# Character Engine 3.1: Articulated Tuca, especificação de assets

Status: **bloqueado por arte**. O motor 3.0 (TucaCore, TucaMotionTokens, springs, cursor, piscar, drag/drop, Playground) fica preservado e só precisa destes assets para articular o personagem.

## Por que os assets atuais não bastam
A única arte de produção é o Tuca do herói do master: uma pintura de 432 x 243 px com as partes fundidas.
- Cabeça e corpo são uma peça: girar a cabeça abre um buraco no pescoço (não há pixels por trás).
- A asa está pintada sobre o corpo: levantá-la revela um corpo que não existe.
- O bico é uma peça fechada: sem mandíbula inferior separada nem interior da boca.
- Pés cortados pela base reta da mureta; cauda quase toda escondida.
- Sem pálpebras e sem expressões do olho no ângulo do master.
- 243 px de altura limitam até a prévia de 256 px.
Os blueprints mostram partes, mas como miniaturas pintadas sobre quadriculado, em outros ângulos: não registram com o master.

## Regras gerais (valem para todos os arquivos)
1. **Mesmo personagem, mesma câmera e mesma luz do herói do master** (vista 3/4 voltada para a direita, luz quente de trás à esquerda). Nada de reinterpretar rosto, olho, bico, penas ou proporções.
2. **Entrega preferida: um PSD (ou Krita/Procreate) em camadas** com o personagem montado na pose neutra, tela de 2048 x 1536 px, além dos PNGs exportados abaixo.
3. **Todos os PNGs na mesma tela e no mesmo registro** (2048 x 1536, personagem na mesma posição), fundo transparente real, sem quadriculado pintado, sem sombra de chão embutida, sem borda/halo.
4. **Partes completas por baixo**: cada parte precisa estar pintada também nas áreas que outra parte cobre (pescoço sob a cabeça, corpo sob a asa, interior da boca, base das penas da cauda, coxas sob os pés). É isso que permite mover sem abrir buracos.
5. **Ponto de articulação (pivô) de cada parte** informado em `rig.json` (formato no fim), em pixels da tela de 2048.
6. Nomes exatamente como na lista. Versões alternativas da mesma parte usam sufixo `_variante`.

## Partes (camadas) obrigatórias
| # | Arquivo | Conteúdo | Pivô | Observação |
|---|---|---|---|---|
| 1 | `body.png` | tronco + peito branco, sem cabeça, asas, pés e cauda | base do tronco | pescoço completo por baixo da cabeça |
| 2 | `head.png` | cabeça sem olho, sem bico | base do pescoço | crânio completo; inclui topete |
| 3 | `crest.png` | topete separado | raiz do topete | para "ajeitar as penas" e reações |
| 4 | `beak_upper.png` | mandíbula superior | articulação com a cabeça | |
| 5 | `beak_lower.png` | mandíbula inferior | mesma articulação | |
| 6 | `mouth_inside.png` | interior da boca | articulação do bico | aparece quando o bico abre |
| 7 | `eye_white.png` | esclera + aro do olho | centro do olho | |
| 8 | `eye_iris.png` | íris + pupila + brilho | centro da íris | igual ao master |
| 9 | `eyelid_upper.png` | pálpebra superior (pele/penas ao redor do olho) | canto do olho | cobre o olho inteiro quando fechada |
| 10 | `eyelid_lower.png` | pálpebra inferior | canto do olho | para o "olho sorrindo" e semicerrado |
| 11 | `brow.png` | sobrancelha/arco de penas acima do olho | centro | dá preocupação, irritação e curiosidade |
| 12 | `wing_near_folded.png` | asa do lado da câmera, fechada | ombro | |
| 13 | `wing_near_open.png` | a mesma asa aberta (comemorar) | ombro | |
| 14 | `wing_near_reach.png` | a mesma asa estendida para a frente, "mão" de penas aberta | ombro | pegar o arquivo |
| 15 | `wing_near_hold.png` | a mesma asa dobrada segurando algo junto ao peito | ombro | segurar e examinar o arquivo |
| 16 | `wing_far.png` | asa do lado oposto (aparece atrás do corpo) | ombro | |
| 17 | `tail.png` | cauda completa com as pontas laranja/vermelhas | base da cauda | |
| 18 | `foot_near.png` / `foot_far.png` | pés com garras e coxa | quadril | passos, batidinha de espera |

## Expressões e poses que não saem só de girar partes
| # | Arquivo | Uso |
|---|---|---|
| 19 | `head_up.png` | cabeça olhando para cima (pensando) |
| 20 | `head_down.png` | cabeça baixa, olhando para o colo (lendo, escrevendo) |
| 21 | `head_toward_viewer.png` | cabeça virada para a câmera (atenção, encarar o usuário após cliques) |
| 22 | `head_away.png` | cabeça virada para fora do notch (curiosidade no idle) |
| 23 | `eye_happy.png` | olho sorrindo (sucesso) |
| 24 | `eye_worried.png` | olho preocupado (erro) |
| 25 | `eye_annoyed.png` | olho semicerrado irritado (cliques repetidos) |
| 26 | `eye_closed_sleep.png` | olho fechado relaxado (dormindo) |
| 27 | `body_sleep.png` | corpo encolhido, cabeça apoiada (dormindo) |
| 28 | `body_lean_forward.png` | corpo inclinado à frente (executando, antecipação do arquivo) |

## Props no estilo do master (mesma luz e acabamento)
| # | Arquivo | Uso |
|---|---|---|
| 29 | `prop_book.png` | lendo |
| 30 | `prop_laptop.png` | trabalhando/escrevendo |
| 31 | `prop_paper.png` (frente e verso) | arquivo pego, examinado e lido |
| 32 | `prop_hourglass.png` | aguardando |

## O que cada estado vai usar (sem texto)
| Estado | Leitura visual pretendida | Partes |
|---|---|---|
| Idle | respira, pisca, olha em volta, ajeita o topete, espia para fora do notch | 1-12, 22 |
| Thinking | cabeça para cima, olhar no alto, asa no queixo | 19, 9-11, 15 |
| Reading | cabeça baixa, livro nas asas, olhos varrendo | 20, 15, 29 |
| Writing/Working | debruçado no notebook, asa digitando | 20, 14, 30, 28 |
| Waiting | encara o usuário, batidinha do pé, ampulheta | 21, 18, 32 |
| Needs attention | vira para o usuário, asa acenando | 21, 13 |
| Success | asas abertas, bico aberto, olho sorrindo, pulo | 13, 4-6, 23 |
| Error | recua, olho preocupado, asa no peito, topete murcho | 24, 15, 3 |
| Sleeping | corpo encolhido, olho fechado, cabeça apoiada | 26, 27 |

**File drop:** percebe (olhos 8) → cabeça segue (2/21) → corpo antecipa (28) → asa estende (14) → pega (14 → 15 com 31) → traz para si e examina (20 + 31) → passa para lendo/trabalhando.
**Click:** corpo encolhe e o topete arrepia (3); cliques repetidos: encara o usuário (21) e fica irritado (25, 11); clique perto do bico: tenta abocanhar o cursor (4-6).

## Formato do `rig.json`
```json
{
  "canvas": [2048, 1536],
  "parts": [
    { "name": "body", "file": "body.png", "pivot": [880, 1180], "z": 10 },
    { "name": "head", "file": "head.png", "pivot": [930, 760], "z": 20, "parent": "body" },
    { "name": "beak_upper", "file": "beak_upper.png", "pivot": [1120, 640], "z": 30, "parent": "head" }
  ]
}
```
(valores ilustrativos; o ilustrador define os pivôs reais)

## Critério de aceite da arte
- Montadas na pose neutra, as camadas reproduzem o herói do master sem diferença visível.
- Nenhuma camada tem quadriculado, halo ou fundo.
- Mover cada parte no limite do seu pivô não revela buracos.

## Prioridade se a produção for em fases
1. Partes 1-10 e 12-17 (rig básico: cabeça, bico, olhos com pálpebras, asas, cauda).
2. 14, 15 e 31 (o file drop completo).
3. 19-27 (expressões e poses de estado).
4. Props 29, 30 e 32 e o pé (18).
