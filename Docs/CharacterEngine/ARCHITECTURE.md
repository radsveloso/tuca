# Tuca Character Engine 3.0

## Decisão: Core Animation

| Opção | Fidelidade à arte aprovada | Interatividade | Desempenho | Manutenção |
|---|---|---|---|---|
| Rive | Ideal, mas exige arte em camadas e um rig criado no editor Rive; nenhum dos dois existe hoje | Excelente | Ótimo | Runtime binário extra |
| SpriteKit | Boa | Boa | Ótimo | Motor de jogo pesado para um personagem de notch |
| SwiftUI/Canvas | Canvas redesenha bitmaps na CPU a cada quadro; o Tuca procedural já foi rejeitado | Boa | Médio | Simples |
| **Core Animation** | **Usa os pixels do master como camadas** | **Total (mouse, clique, arraste)** | **Composição na GPU, na taxa da tela** | **Hierarquia igual ao rig** |

Quando existir arte em camadas completa (ver `MISSING_ASSETS.md`), a evolução natural é um rig Rive. O motor de estados e os tokens de movimento continuam valendo.

## Estrutura

- `Sources/TucaCharacter/TucaMotionTokens.swift`: todos os tempos, amplitudes e molas.
- `Sources/TucaCharacter/TucaCharacterArt.swift`: carrega as camadas de `Resources/TucaCharacterArt`.
- `Sources/TucaCharacter/TucaCharacterView.swift`: rig e motor (molas físicas, estados, interações, Reduzir movimento).
- `Sources/TucaPlayground/`: o Character Playground e o modo `--render` de verificação.

Hierarquia: `rig` → rastros → `character` (apoio nos pés) → `body` + `eyeGroup` (`socket` → `iris` → `rim`) → overlays.

## Estado → movimento

| Estado | Movimento |
|---|---|
| Tranquilo | respiração 1,8%, piscadas irregulares (2,2 a 6 s, 20% duplas), olhadelas, mudanças de postura, olhar percebe o cursor quando ele se move |
| Atento | íris segue o cursor; cabeça e corpo acompanham de leve |
| Pensando | olhar para cima e para o lado, cabeça inclinada para trás, flutuação lenta, pontinhos de pensamento |
| Trabalhando | olhar alternando entre tarefa e frente, balanço curto, olhos concentrados |
| Lendo | olhos varrem linhas da esquerda para a direita e descem linha a linha; cabeça baixa; documento |
| Escrevendo | bicadas rítmicas em rajadas, olhar alterna entre documento e usuário; documento |
| Executando | inclinação à frente, ciclo de saltos com squash, rastro e linhas de velocidade |
| Aguardando | encara o usuário, dá duas batidinhas de expectativa a cada 2 s, olha de lado e volta |
| Precisa de você | surge de baixo com mola, encara o usuário, pula a cada 1,6 s, balança, selo "!" |
| Concluído | antecipação, pulo com squash and stretch, olhos abertos, brilhos que se espalham, depois assenta |
| Erro | recuo físico, sacudida curta que some, olhos semicerrados de preocupação, cabeça caída, suspiros |
| Dormindo | olho fechado, respiração mais lenta e funda, cabeça caída, zzz subindo |

Interações: piscar; seguir o cursor; hover (inclina para o cursor); clique (pulo e squash); cliques repetidos (3 ou mais em 1,2 s: irritado, olhos semicerrados, cabeça balançando, depois se recupera); arraste (percebe, segue o arquivo, arregala e quica); receber arquivo (o arquivo voa até o bico e ele engole); acordar (qualquer atividade acorda: olho abre arregalado, pulo, olha em volta).

Reduzir movimento: sem respiração, pulos, sacudidas, rastros nem olhar seguindo o cursor; as posturas e os overlays de cada estado continuam, sem animação.
