# Assets de produção do Tuca

Derivados do master aprovado `Docs/MascotKit/00_MASTER/TUCA_MASTER_APPROVED.png` (SHA-256 em `provenance.json`).

- `tuca_base.png`: o Tuca do herói da prancha, com fundo transparente. O RGB é copiado do master sem nenhuma alteração; só o canal alpha foi adicionado (segmentação ISNet). Resolução nativa 432 x 243.
- `tuca_base_small.png`: a mesma imagem reduzida com Lanczos (96 px de altura) para o notch, sem aumento.
- `attention_badge.png`, `file_badge.png`, `sleep_zzz.png`, `success_spark.png`: overlays rasterizados a 192 px a partir dos SVG oficiais em `Docs/MascotKit/02_ASSETS/SVG`.

Não redesenhe, vetorize ou gere variações do personagem. Estados sem arte própria usam este mesmo Tuca com transformações e overlays.
