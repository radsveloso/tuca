# Renderer replacement contract

## Keep
The current TucaCore/state-resolution work is useful and should remain.

## Replace
The current procedural mascot renderer in `Sources/Tuca/TucaMascot.swift` must no longer define the mascot's identity with Canvas primitives such as body/head/beak/eye paths.

## Target
Create a `TucaMascotView` whose visual source is an official asset/layer composition, while state and micro-motion are driven by TucaCore.

## Rendering hierarchy
1. Official mascot artwork
2. optional layered facial/eye elements only when derived from the same artwork
3. SVG status overlays
4. SwiftUI transforms: offset, scale, rotation, opacity
5. state-specific effects

## Micro-motion
Idle: 1–2% breathing scale.
Blink: use an approved/layered eyelid solution; never redraw the eye style.
Cursor: subtle clamped eye/head offset.
Thinking: slight head tilt + restrained float.
Reading/writing: prop/overlay and posture, without replacing the character.
Running: controlled motion blur/translation.
Attention: badge + short bounce/pulse.
Success: short upward reaction + spark overlay.
Error: small recoil + error treatment.
Sleeping: lowered pose if an exact asset exists; otherwise use restrained opacity/head transform + ZZZ overlay.

Respect Reduce Motion.

## Critical rule
If an exact state asset does not exist, do NOT generate a visually different toucan inside Swift. Prefer reusing the exact approved base with transforms/overlays until a faithful state asset is supplied.
