# Camadas do rig do Tuca (Character Engine 3.0)

Todas derivadas do master aprovado (SHA-256 em `rig.json`), sem redesenho:

| Arquivo | Origem |
|---|---|
| `full.png` | o Tuca do master com fundo transparente (RGB idêntico ao master) |
| `body.png` | igual ao `full.png`, exceto dentro do olho: ali a pele foi preenchida por interpolação harmônica das bordas reais. Só aparece quando o olho fecha. Nenhum pixel fora do olho foi alterado. |
| `eye_socket.png` | o olho do master (aro + esclera) com a íris removida e preenchida a partir das bordas |
| `eye_iris.png` | íris, pupila e brilho do master, copiados sem alteração |
| `eye_rim.png` | o aro escuro do master, copiado sem alteração, por cima da íris |
| `attention.png`, `file.png`, `spark.png`, `zzz.png` | os SVG oficiais do kit, rasterizados a 192 px |

Faltam camadas de arte para: pálpebras, cabeça separada do corpo, bico em duas partes (abrir/fechar), asas, pés e cauda. Ver `Docs/CharacterEngine/MISSING_ASSETS.md`.
