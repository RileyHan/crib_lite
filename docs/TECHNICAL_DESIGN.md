# Technical Design

## Platform and project

- Engine: Godot 4.x
- Language: GDScript
- Initial platform: Windows PC
- Dependencies: Godot-native features only

## Boundaries

Keep game state, card data, deck and deal logic, cribbage rules, scoring, AI,
encounters, roguelite progression, economy, and UI in separate systems. Reusable
scenes render data rather than owning gameplay rules. Signals connect major
systems where appropriate.

Use resources or centralized configuration for encounter, perk, and balance
data. Route perk interactions through a centralized event mechanism instead of
scattering perk-specific checks through scoring and UI code. Keep temporary
hand effects distinct from persistent run effects.

## Project structure

- `scenes/`: main menu, run, encounter, gameplay, shop, reward, and UI scenes.
- `scripts/`: core, gameplay, encounter, roguelite, UI, and AI systems.
- `resources/`: card, perk, opponent, boss, and encounter data.
- `assets/`: placeholder and future project-owned content.
- `tests/`: automated rules and system tests.

## Local development and version control

Open the project through `project.godot`; do not rely on an absolute machine
path. Keep the Windows working copy on a local Desktop folder outside OneDrive
or other redirected/synced storage. Ignore Godot-generated editor/import data
and machine-specific editor files. Use GitHub to synchronize source, not as the
runtime location for the primary Windows game.
