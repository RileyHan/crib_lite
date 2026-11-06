# Game Design

## Premise

Skunked is a cribbage roguelite. Traditional cribbage remains the core ruleset; run upgrades and perks create build variety without replacing the underlying game.

## Run shape

A run has ten configurable stages. Each stage presents two regular encounter options and a mandatory boss. The player must complete at least two encounters per stage and may take on all three for additional rewards. A shop follows each stage.

## Encounters

An encounter defines its opponent, scoring target, hand limit, reward, difficulty, and retry cost. The baseline is four hands. To win, the player must meet the target and finish ahead of the opponent. Ties use a configurable sudden-death hand by default.

## Progression

A run begins with zero currency and one free choice from a curated starter-perk selection. Perks can affect scoring, cards, encounters, economy, or cribbage rules. Perk effects should be communicated through centralized events and have explicit trigger conditions and durations.

## Prototype scope

Implemented (milestones 1-7 plus UI tweaks): traditional cribbage rules, opponent AI, encounters, run progression, and a playable round demo. Perks, the real shop and economy, and the integrated run UI are future work.

Round presentation rules:
- Three and four of a kind score as a single item (6 and 12 points) rather than separate pairs.
- The nondealer cuts from the dealer's deck, spread in a line; the player clicks a card and the opponent picks at random.
- The crib is a single pile beside the dealer's cards and is revealed at the show.
- Each player has a pegging and game score counter; Go, 31, last card and His Heels show a brief on-screen banner, and the pile stays visible before the count resets.
- A full-height scrolling game log on the left records the whole encounter, hand by hand.
