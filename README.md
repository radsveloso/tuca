# Tuca

Um tucano que mora no notch do seu Mac e acompanha seus agentes de IA.

- **Sessões ao vivo do Claude Code** no notch: o que ele lê, edita e roda, e quando precisa de você.
- **Chat com Claude, Copilot, Gemini, ChatGPT e Grok usando o login de cada CLI oficial.** Sem API key: o Tuca chama `claude`, `copilot`, `gemini`, `codex` e `grok` instalados no seu Mac, e cada um usa a sua assinatura.
- **Arraste arquivos para o notch** (imagens, PDFs, planilhas, código): o Tuca abre no chat e anexa à próxima pergunta. Claude, Gemini e ChatGPT leem imagens e PDFs direto; para Copilot, Grok e M365 o texto do PDF é extraído no próprio Mac.
- Invisível quando não há nada acontecendo. Passe o mouse no notch para abrir.

## Mascote (Tuca oficial)

O Tuca é a arte oficial aprovada (`Docs/MascotKit/00_MASTER/TUCA_MASTER_APPROVED.png`), não um desenho em código. `Resources/TucaMascotAssets/tuca_base.png` é o Tuca do master com fundo transparente (RGB idêntico ao master; procedência em `provenance.json`). O `TucaMascotView` (`Sources/Tuca/TucaMascot.swift`) compõe essa arte com transformações SwiftUI e os overlays SVG oficiais; estados sem arte própria reutilizam o mesmo Tuca. O estado vem do `TucaCore`, que deriva tudo das sessões, do chat e do notch.

Prioridade: precisa de você > erro > executando > escrevendo > lendo > pensando > trabalhando > concluído > atento > aguardando > tranquilo > dormindo.

Verificações: `swift run TucaCoreChecks`. Galeria visual (128, 64, 32 e 24 pt): `.build/release/Tuca --snapshot <pasta>`.

## Compilar e instalar

Requisitos: macOS 14+, Command Line Tools (Swift 6).

```sh
./build.sh --install
```

Depois, no ícone de pássaro na barra de menus: **Instalar hooks do Claude Code…**
O Tuca faz backup do `~/.claude/settings.json`, mantém seus hooks atuais e só adiciona os dele.

## CLIs suportadas

| Provedor | CLI | Login |
|---|---|---|
| Claude | `npm i -g @anthropic-ai/claude-code` | `claude` (assinatura Pro/Max) |
| Copilot | `npm i -g @github/copilot` | `copilot` (conta GitHub com Copilot) |
| Gemini | `npm i -g @google/gemini-cli` | `gemini` (conta Google) |
| ChatGPT | `npm i -g @openai/codex` | `codex login` (assinatura ChatGPT) |
| Grok | `curl -fsSL https://x.ai/cli/install.sh \| bash` | `grok login` (SuperGrok ou X Premium+) |
| Microsoft 365 Copilot | `npm i -g @microsoft/workiq` | conta de trabalho com licença M365 Copilot e consentimento do admin |

## Privacidade

Sem telemetria, sem servidor. Os hooks falam com o app por um socket Unix local (0600, só o seu usuário).
O Tuca nunca lê nem guarda tokens: quem autentica é a própria CLI.
