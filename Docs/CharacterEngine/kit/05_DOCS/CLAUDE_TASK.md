# CLAUDE TASK — TUCA CHARACTER ENGINE 3.0

Repository: `radsveloso/tuca`

## Objective
Make Tuca feel alive. Do not redesign the rest of the application yet.

## Visual source of truth
`00_MASTER/TUCA_APPROVED_MASTER.png`

The exact identity in this master is mandatory. The two blueprint sheets describe how the SAME character should be rigged, posed and animated.

IMPORTANT: blueprint panels/reference crops are specifications. Do not blindly crop them into production sprites if borders/background/lighting make them unsuitable.

## Preserve
Keep the useful TucaCore state machine, hook mapping and session logic already implemented.

## Replace
The current result where a static mascot is accompanied by status text is not accepted.
The old generic procedural Canvas toucan is also not accepted.

## First deliverable: Character Playground
Before notch integration, create a development playground inside the project where every state and interaction can be triggered manually.

Required states:
idle, watching, thinking, working, reading, writing, running, waiting,
needsAttention, success, error, sleeping.

Required interactions:
blink, cursor tracking, hover, click, repeated-click reaction, drag hover,
receive file, wake up.

Controls must also preview 24/32/48/64/96/128/256 px and Reduce Motion.

## Life requirements
IDLE: breathing, irregular blinking, subtle posture/head movement, eye awareness.
WATCHING: track cursor with eye and restrained head follow.
THINKING: upward gaze/head tilt/contemplative movement.
READING: eyes scan left-right; document/book prop may move.
WRITING: active posture, wing/typing movement, gaze alternation.
RUNNING: forward energy with restrained motion trail/body cycle.
WAITING: distinct from idle; visible expectation.
NEEDS ATTENTION: emerge/face user/wing gesture; optional ! overlay.
SUCCESS: short celebration, wings/spark; then settle.
ERROR: physical recoil/concern; not just a red tint.
SLEEPING: closed eyes, slower breathing, ZZZ; wake on activity.
DRAG: perceive cursor/file, follow it, react on target enter, receive on drop.
CLICK: physical reaction. Repeated clicks may escalate briefly, then recover.

Text labels are diagnostic only. The character itself must communicate state.

## Architecture evaluation
Before coding the final engine, compare:
1. Rive
2. SpriteKit/Core Animation
3. SwiftUI/Canvas

Choose based on fidelity to approved art, interactivity, performance and maintainability—not convenience.

If exact animation requires art layers not actually available in this kit, DO NOT fabricate a different toucan. Build the playground/engine around available faithful art and produce an explicit missing-assets list:
head, eye, pupil, eyelids, beak parts, wings, body, feet, tail, etc.

## Motion system
Centralize motion tokens. Avoid random scattered `.animation` modifiers.
Use natural spring/easing.
Target fluid cursor/eye motion.
Respect macOS Reduce Motion.

## Acceptance tests
- 30 seconds idle must not look like a static PNG.
- Cursor movement must visibly be perceived.
- Thinking -> Reading -> Writing -> Success must be physically distinguishable without relying on text.
- Dragging a file must trigger physical reaction.
- Sleeping -> activity must visibly wake Tuca.
- Character identity must remain visually faithful to the approved master.

## Scope guard
DO NOT implement Coucou parity, multi-AI, Terminal/VS Code, remote nodes, BI agents or overall UI redesign now.

## Stop point
Do not integrate into the production notch until the playground is shown and the user explicitly says:
`Character Engine aprovado.`

## Final report for this phase
Provide:
- architecture decision and rationale;
- files changed;
- state -> motion mapping;
- interactions implemented;
- missing art assets, if any;
- build/test results;
- screenshots or recording of playground states.
