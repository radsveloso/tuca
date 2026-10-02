# Tuca

Um tucano que mora no notch do seu Mac e acompanha seus agentes de IA.

- **Sessões ao vivo do Claude Code** no notch: o que ele lê, edita e roda, e quando precisa de você.
- **Chat com Claude, Copilot, Gemini e ChatGPT usando o login de cada CLI oficial.** Sem API key: o Tuca chama `claude`, `copilot`, `gemini` e `codex` instalados no seu Mac, e cada um usa a sua assinatura.
- Invisível quando não há nada acontecendo. Passe o mouse no notch para abrir.

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

## Privacidade

Sem telemetria, sem servidor. Os hooks falam com o app por um socket Unix local (0600, só o seu usuário).
O Tuca nunca lê nem guarda tokens: quem autentica é a própria CLI.
