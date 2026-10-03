# CLAUDE INSTALL — Tuca Mascot 2.0

You are integrating the approved Tuca mascot into `radsveloso/tuca`.

## Non-negotiable
1. Do not redesign Tuca.
2. Do not replace CLI/OAuth authentication architecture.
3. Do not break SessionStore, HookServer, ChatEngine, drag/drop, or notch behavior.
4. Establish a clean build baseline before edits.
5. The images in this package are visual/state references. Do not treat mismatched crops as final animation frames.
6. Prefer one coherent rendering system so Tuca does not visually morph between states.

## Phase A — inspect
Read at minimum:
- Sources/Tuca/TucaMascot.swift
- Sources/Tuca/SessionStore.swift
- Sources/Tuca/HookServer.swift
- Sources/Tuca/NotchController.swift
- Sources/Tuca/Views.swift
- Sources/Tuca/ChatEngine.swift
- Package.swift

Run the existing build before editing and record the result.

## Phase B — model
Introduce a mascot state model that supports:
`idle, watching, thinking, working, reading, writing, running, waiting,
needsAttention, success, error, sleeping`

Also model transient interactions:
`blink, cursorLook, clickReaction, dragHover, receivingFile`.

Do not duplicate the application's session truth. Derive mascot presentation from existing session/chat/hook state.

Use explicit priority:
needsAttention > error > running > writing > reading > thinking > working >
success > watching > idle > sleeping.

## Phase C — event mapping
Map Claude hook/tool events semantically:
- Read/search/inspect -> reading
- Edit/Write/Create -> writing
- Bash/command/build/test -> running
- permission/clarification/user input -> needsAttention
- generic processing -> working/thinking
- successful stop/completion -> success, then idle
- failed command/provider -> error

When the exact event cannot be determined, fall back safely to working.
Never invent capabilities that HookServer does not actually receive.

ChatEngine:
- sending/waiting for first response -> thinking
- streaming response -> working
- failure -> error
- completion -> success briefly

Drag/drop:
- target entered -> dragHover
- drop accepted -> receivingFile
- return to previous meaningful state.

## Phase D — rendering
Preserve the approved design:
- oversized expressive blue eye
- iconic orange/yellow beak with dark tip
- dark navy/black body
- white face/chest
- restrained warm accent feathers

The character should feel premium, intelligent, warm, and alive — not childish.

Implement smooth micro-motion:
- breathing
- blinking
- subtle eye/head tracking
- state-specific pose changes
- smooth transitions
- subtle success reaction
- clear attention reaction
- restrained error reaction

Respect Reduce Motion.

If the existing SwiftUI Canvas/vector mascot can be evolved coherently, prefer that.
If a new layered rendering architecture is cleaner, implement it modularly.
Do not build the production character by switching among unrelated raster crops.

## Phase E — notch
Verify at:
- collapsed notch size
- compact/activity state
- expanded state

At 24–32 px, prioritize silhouette, eye, and beak.
Avoid visual noise.

## Phase F — tests
Add deterministic tests for state resolution and priority where practical.
Run build/tests after changes.
Verify no regression in:
- notch expand/collapse
- hover
- active session
- attention
- chat running
- completion sound/state
- drag/drop
- provider switching

## Deliverable
Implement the mascot integration completely. Report:
- files changed
- state/event mapping
- rendering approach
- tests/build results
- any hook events that cannot yet be mapped reliably

Do not begin Coucou parity, multi-AI orchestration, remote nodes, BI agents, or the broader UI redesign in this task. This task is only Tuca Mascot 2.0.
