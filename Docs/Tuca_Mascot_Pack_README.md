# Tuca Mascot Pack — Approved Baseline

This package is the visual source of truth for the Tuca mascot.

## Important
The PNG state files are **reference assets extracted from the approved character sheet**, not a claim of final production sprite animation. Use them to preserve identity and state semantics. For production, prefer a consistent layered/vector/Canvas implementation or a coherent sprite/animation pipeline rather than independently redrawing each state.

## Integration target
Repository: `radsveloso/tuca`

Existing component: `Sources/Tuca/TucaMascot.swift`

The existing mascot may be refactored, but the approved identity must be preserved.

## Required states
idle, watching, thinking, working, reading, writing, running, waiting,
needs_attention, success, error, sleeping.

## Required interactions
blink, cursor look, follow motion, click reaction, receive file, drag & drop.

## Behavioral mapping
- Session appears -> watching -> working/thinking
- Read/search -> reading
- Edit/Write -> writing
- Bash/build/test/command -> running
- Permission/clarification -> needs_attention
- Successful completion -> success -> idle
- Failure -> error
- Long inactivity -> sleeping
- Drag enters notch -> watching/attention -> receive_file on drop

## Motion principles
- Subtle breathing in idle.
- Natural blink with randomized interval.
- Eye/head tracking should be clamped and subtle.
- State transitions should use spring/ease interpolation; avoid hard cuts.
- Attention may pulse, but do not create constant distracting motion.
- Success is brief and celebratory.
- Error communicates clearly without aggressive shaking.
- Reduced Motion must be respected.

## Size behavior
- 24–32 px: silhouette + eye + beak must remain recognizable.
- ~64 px: simplified details.
- 96–128+ px: full detail.
- Never depend on tiny text or micro-details to communicate state.

## Accessibility
Respect macOS Reduce Motion. State must not be conveyed by color alone. Provide accessibility labels for meaningful status.

## Installation
Copy `Resources/TucaMascot` into the repository resources, then implement the state machine described in `Docs/CLAUDE_INSTALL.md`.
