# Tuca Official Mascot Kit v1

This package is designed to correct the current mascot implementation without discarding the state-machine work already completed.

## Key decision
**The approved PNG is the visual master.** SVG is used for UI/status overlays, not to replace the mascot.

The approved character has raster/3D characteristics—feather texture, soft lighting, volumetric beak and eyes—that would materially change if automatically traced into SVG.

## Package
- `00_MASTER` — immutable approved source of truth.
- `01_REFERENCE` — visual/reference sheets and state crops.
- `02_ASSETS/SVG` — scalable status overlays.
- `03_SWIFT` — state-model reference.
- `04_DOCS` — renderer contract and Claude installation instructions.
- `manifest.json` — machine-readable rules.

Start with `04_DOCS/CLAUDE_INSTALL.md`.
