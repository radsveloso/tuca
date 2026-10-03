# Tuca

Um tucano que mora no notch do seu Mac e acompanha seus agentes de IA.

- **Sessões ao vivo do Claude Code** no notch: o que ele lê, edita e roda, e quando precisa de você.
- **Chat com Claude, Copilot, Gemini, ChatGPT e Grok usando o login de cada CLI oficial.** Sem API key: o Tuca chama `claude`, `copilot`, `gemini`, `codex` e `grok` instalados no seu Mac, e cada um usa a sua assinatura.
- **Arraste arquivos para o notch** (imagens, PDFs, planilhas, código): o Tuca abre no chat e anexa à próxima pergunta. Claude, Gemini e ChatGPT leem imagens e PDFs direto; para Copilot, Grok e M365 o texto do PDF é extraído no próprio Mac.
- Invisível quando não há nada acontecendo. Passe o mouse no notch para abrir.

## Mascote (Character Engine 3.0)

O Tuca do notch é um rig em Core Animation (`Sources/TucaCharacter`) montado com camadas extraídas do master aprovado (`Resources/TucaCharacterArt`): corpo, olho, íris e aro. Ele respira, pisca, segue o cursor com o olhar e reage a cliques, arraste de arquivos e a cada estado. O estado vem do `TucaCore` (sessões do Claude Code, chat e notch); tempos e amplitudes ficam em `TucaMotionTokens.swift`. Respeita o Reduzir movimento do macOS.

- Playground para testar o personagem: `./build-playground.sh --open`
- Gravações de verificação: `.build/release/TucaPlayground --render <pasta>`
- Arquitetura e arte que falta: `Docs/CharacterEngine/`

Prioridade dos estados: precisa de você > erro > executando > escrevendo > lendo > pensando > trabalhando > concluído > atento > aguardando > tranquilo > dormindo.

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
