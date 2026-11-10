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

Milestones 1-7 are implemented: card and deck systems, cribbage rounds (deal, discard, crib, cut, scoring, pegging), data-driven opponent AI profiles, encounters (first-to-target wins judged each hand via `CribbageRound.score_log`, hand limits, sudden death, retries), and run progression (`RunConfig` / `RunState`: ten stages, two regular options plus a boss per stage, currency rewards, retry costs, placeholder shop phase). The run map demo plays each encounter on the interactive round table (`round_demo.tscn` embedded with an injected `Encounter`, reporting back via `encounter_finished`). `Scoring.pairs` emits one event for three/four of a kind, `CribbageRound.cut(rng, cut_index)` lets the UI pick the cut card (via `CardDeck.draw_at`), and `Pegging` events carry an `owner_id`. The round demo (`scripts/ui/round_demo.gd`) has a `pace` multiplier for delays and banners; tests set it to 0. Milestone 8 (perks) is implemented: `PerkData` resources (`resources/perks/*.tres`) declare effect, trigger (`PEG_PLAY`, `SHOW_SCORED`, `HAND_STARTED`), duration (`RUN`/`ENCOUNTER`/`HAND`), filters and amount. `PerkManager` is the central dispatcher: `dispatch(trigger, ctx)` returns bonus `perk` events, and modifiers (`target_delta`, `hand_limit_delta`, `reward_bonus`, `retry_discount`) are queried by `Encounter`. Hook points are `Pegging.play`, `CribbageRound.deal` and its show scoring; temporary perks expire via `begin_hand`/`end_hand`/`end_encounter`. `RunConfig.perk_pool`/`starter_offer` feed the new `RunState.Phase.STARTER_PERK`, resolved with `choose_starter_perk`. Milestone 9 (shop) is implemented: ShopConfig (esources/shop/shop_default.tres, referenced by RunConfig.shop_config) holds offer count, rarity weights, per-rarity price scale, per-stage price growth, reroll cost/growth and sell ratio. Shop (scripts/shop/shop.gd) is UI-independent: offers, price_of, uy, eroll, sell, with signals offers_changed, perk_purchased, perk_sold, erolled. RunState creates it when a boss is cleared (shop_opened signal, un.shop) and drops it in leave_shop(). Scoring changes: Pegging.points_scored lets CribbageRound bank pegging points live; CribbageRound.target/carried/winner_id end the hand the moment the target is reached (show skipped). EncounterData.player_head_start (faded by RunConfig.head_start_decay) seeds the player's total. PerkData.Effect.MULTIPLIER perks (start_bonus, max_bonus, growth mount per matching trigger event) are handled by PerkManager.multiplier_event/grow_multipliers, applied in Pegging and CribbageRound._add_result. The shop UI and the integrated run UI are not implemented yet. Tests live in `tests/` and run headless with `godot --headless -s tests/<name>.gd`.

- **Chips x Mult scoring engine (stage 1):** `scripts/scoring/` holds `ScoringEngine` (static, UI-independent) plus `PegData`, `RelicData` and `ScoreEffectData` resources (`resources/pegs`, `resources/relics`). Final = floor(Chips x Mult); chips start at the cribbage points, mult at 1. Additive effects resolve before multiplicative ones, pegs before relics, and every activation is logged in `steps` for the UI. Not yet wired into rounds or encounters; see `tests/test_scoring_engine.gd`.

- **Chips x Mult integration (stage 2):** `ScoreLoadout` holds the player's pegs and relics. Pegging (every play, Go, last card) and `CribbageRound` (hand and crib) call `loadout.bonus_event` and bank the returned `chips_mult` event (extra points = final - base cribbage points, with the engine `breakdown` attached for the UI). With `RunConfig.chips_mult` on, only the player can win (reach the target), the hand limit is final (no sudden death), targets and head starts are multiplied by `score_scale`, and the run starts with `starting_pegs`. The player deals first (crib) by default. Opponent scoring stays plain cribbage points. Tests: `tests/test_chips_mult.gd`.

## Chips x Mult stage 3: upgrade shop

- `UpgradeShop` (`scripts/shop/upgrade_shop.gd`) sells pegs and relics from `RunConfig.peg_pool` / `relic_pool` into `RunState.loadout`, using each item's rarity and `base_price` via `ShopConfig`. `RunState.upgrade_shop` and the `upgrade_shop_opened` signal replace the perk shop when `chips_mult` is on.
- Old perks are retired in Chips x Mult mode (no starter pick, no perk shop); the perk systems still run when `chips_mult` is false.
- `run_demo.gd` renders the shop with buy, reroll and sell buttons.
