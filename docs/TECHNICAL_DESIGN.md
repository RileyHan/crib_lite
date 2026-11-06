# Technical Design

## Engine and platform

- Godot 4.x with GDScript.
- Windows PC is the initial runtime target.
- Use built-in Godot features and placeholder visuals; no paid assets or third-party runtime dependencies are required.

## Ownership boundaries

Keep run state, card data, deck operations, cribbage rules, scoring, AI, encounters, roguelite progression, economy, and UI in separate systems. Gameplay logic must not depend on scene presentation. Reusable card visuals should consume card data rather than own the rules or state.

## Data and events

Centralize balance values and represent configurable perks, opponents, and encounters as resources. Route perk triggers through a shared event mechanism rather than scattering perk-specific checks through scoring and UI code. Keep temporary hand effects distinct from run-persistent changes.

## Validation

Add focused automated tests as each rules subsystem is introduced. Test scoring, pegging, deck ownership/shuffling, encounter outcomes and retries, and perk triggers before expanding the corresponding milestone.

## Current implementation

Milestones 1-7 are implemented: card and deck systems, cribbage rounds (deal, discard, crib, cut, scoring, pegging), data-driven opponent AI profiles, encounters (targets, hand limits, sudden death, retries), and run progression (`RunConfig` / `RunState`: ten stages, two regular options plus a boss per stage, currency rewards, retry costs, placeholder shop phase). The run map demo auto-plays encounters until the full run loop UI exists. `Scoring.pairs` emits one event for three/four of a kind, `CribbageRound.cut(rng, cut_index)` lets the UI pick the cut card (via `CardDeck.draw_at`), and `Pegging` events carry an `owner_id`. The round demo (`scripts/ui/round_demo.gd`) has a `pace` multiplier for delays and banners; tests set it to 0. Perks, the real shop and economy, and the integrated run UI are not implemented yet. Tests live in `tests/` and run headless with `godot --headless -s tests/<name>.gd`.
