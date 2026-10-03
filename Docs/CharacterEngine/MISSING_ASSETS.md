# Arte que falta para o rig completo

O kit não traz camadas de produção: as "partes do personagem" dos blueprints são miniaturas pintadas sobre fundo quadriculado, com ângulos diferentes do master. Usá-las faria o Tuca mudar de rosto. O motor usa só o que dá para extrair fielmente do master.

## Derivado do master (em uso)
- Corpo inteiro (`full.png`, `body.png`)
- Olho: aro + esclera (`eye_socket.png`), íris + pupila + brilho (`eye_iris.png`), aro (`eye_rim.png`)

## Precisa vir da arte (mesmo personagem, mesma pose e luz do master, PNG transparente, mínimo 1024 px de altura)
1. **Pálpebras superior e inferior** do olho do master. Hoje o olho fecha achatando o próprio olho sobre uma pele interpolada; funciona, mas uma pálpebra desenhada fica mais natural.
2. **Cabeça separada do corpo**, com o pescoço completo por baixo. Permite virar a cabeça sem inclinar o corpo inteiro.
3. **Bico em duas partes** (superior e inferior, com o interior da boca). Permite abrir o bico (comemorar, engolir o arquivo, falar).
4. **Asas** (esquerda dobrada e aberta). Permite o gesto de asa no "precisa de você" e a comemoração do sucesso.
5. **Pés** e **cauda** separados. Permite passos no "executando" e o balanço da cauda.
6. **Props no estilo do master**: livro, notebook e ampulheta (hoje o documento usa o SVG oficial `file.svg`).
7. **Expressões** do olho no mesmo ângulo do master: feliz, preocupado, irritado, surpreso.

Com essas camadas, o rig pode migrar para Rive mantendo os mesmos estados e tokens.
