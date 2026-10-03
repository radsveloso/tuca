# CLAUDE — INSTALL TUCA OFFICIAL MASCOT KIT

Repository: `radsveloso/tuca`

This task corrects the visual implementation of Tuca Mascot 2.0.

The previous implementation's state machine/event mapping is valuable. The problem is the renderer: it recreated Tuca procedurally in SwiftUI Canvas, producing a different character.

## SOURCE OF TRUTH
`00_MASTER/TUCA_MASTER_APPROVED.png`

This exact approved character defines:
- face
- silhouette
- eye
- beak
- proportions
- feather treatment
- color
- lighting/volume
- personality

Do not reinterpret it.

## BEFORE EDITING
1. Inspect current main branch.
2. Read the latest mascot commit and current:
   - Sources/Tuca/TucaMascot.swift
   - Sources/TucaCore/TucaVisualState.swift
   - Sources/Tuca/SessionStore.swift
   - Sources/Tuca/HookServer.swift
   - Sources/Tuca/ChatEngine.swift
   - Sources/Tuca/Views.swift
3. Build/test baseline.
4. Report baseline.
5. Preserve existing state/event logic unless objectively broken.

## REQUIRED CHANGE
Replace the procedural Canvas identity renderer.

Do NOT solve this by improving:
`drawBody`, `drawHead`, `drawBeak`, `drawEye`, or similar paths.

Do NOT trace/vectorize the master and claim it is identical.

Use a hybrid asset renderer:
- official raster/layer artwork for Tuca;
- SVG only for status/interaction overlays;
- SwiftUI/Core Animation for movement and transitions.

The included state crops are REFERENCE ONLY. They are not production sprites.

## IMPORTANT LIMITATION
Do not invent missing production art.

Where a faithful state-specific asset is unavailable, reuse the approved base character and express the state using transforms, motion, props and overlays. It is preferable to have the exact Tuca with a simpler animation than a different Tuca with a richer animation.

## STATE MACHINE
Keep/support:
idle
watching
thinking
working
reading
writing
running
waiting
needsAttention
success
error
sleeping

Interactions:
blink
cursorLook
clickReaction
dragHover
receivingFile

Priority:
needsAttention > error > running > writing > reading > thinking > working > success > watching > idle > sleeping

## VISUAL ACCEPTANCE
Before calling the task complete, compare the app visually against `TUCA_MASTER_APPROVED.png`.

Reject your own implementation if:
- beak shape changes materially;
- eye shape/style changes;
- head/body proportions change;
- feathered/3D premium appearance becomes flat vector art;
- the mascot resembles a generic toucan rather than the approved Tuca.

## RESPONSIVE USE
24 px: preserve recognizable eye/beak silhouette; simplify overlays.
32–64 px: compact notch.
64–128 px: richer character.
Expanded view: highest-quality asset available.

Use @2x/@3x resources as appropriate and avoid blurry scaling.

## DO NOT TOUCH
Do not begin Coucou parity.
Do not begin remote nodes.
Do not change provider authentication.
Do not redesign chat.
Do not change BI architecture.

This task is only the visual renderer correction.

## TESTS
Build and run current checks.
Validate:
- collapsed notch
- hover
- expanded notch
- active session
- needs attention
- success/error
- drag/drop
- chat activity
- Reduce Motion

## FINAL REPORT
Return:
1. files changed;
2. old renderer removed/retired;
3. exact assets used;
4. mapping from TucaCore state -> visual treatment;
5. build/test result;
6. screenshots at 24/64/128px or equivalent app states for visual review.

Do not declare success without visual comparison.
