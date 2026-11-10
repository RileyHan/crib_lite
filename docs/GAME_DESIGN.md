# Game Design

## Premise

Skunked is a cribbage roguelite. Traditional cribbage remains the core ruleset; run upgrades and perks create build variety without replacing the underlying game.

## Run shape

A run has ten configurable stages. Each stage presents two regular encounter options and a mandatory boss. The player must complete at least two encounters per stage and may take on all three for additional rewards. A shop follows each stage.

## Encounters

An encounter defines its opponent, scoring target, hand limit, reward, difficulty, and retry cost. The baseline is four hands. First to reach the target score wins, checked at the end of each hand; if both cross it in the same hand, whoever crossed first while scoring wins. If nobody reaches it by the hand limit, play continues in sudden death (configurable) until someone does, otherwise the player loses.

## Progression

A run begins with zero currency and one free choice from a curated starter-perk selection. Perks can affect scoring, cards, encounters, economy, or cribbage rules. Perk effects should be communicated through centralized events and have explicit trigger conditions and durations.

## Prototype scope

Implemented (milestones 1-9 plus UI tweaks): traditional cribbage rules, opponent AI, encounters, run progression, a playable round demo, and perks. A run opens with a free pick of one of three random starter perks (six starters exist; 13 perks total across common/uncommon/rare). Perks last for the run, an encounter, or a single hand, and can add bonus points (on pegging plays, scored hand/crib items, or hand start), lower the target, add hands, raise rewards, or discount retries. Perks only affect the player. After each stage's boss a shop offers three random perks you don't own (rarity-weighted; prices scale with rarity and stage). You can buy with currency, pay a rising fee to reroll the offers, or sell a run perk for half its current price. Points are banked the moment they are scored (pegging included), and an encounter ends immediately when someone reaches the target, even mid-pegging. Early stages are easier: the player starts encounters with a head start that fades each stage, and the Easy opponent makes more mistakes. Multiplier perks (Momentum: pegging runs, Run Rhythm: hand/crib runs) hold one permanent score multiplier that grows by +1 per matching run (cap x5); the triggering score uses the old multiplier and growth applies to later scoring. The shop UI and the integrated run UI are future work.

Round presentation rules:
- Three and four of a kind score as a single item (6 and 12 points) rather than separate pairs.
- The nondealer cuts from the dealer's deck, spread in a line; the player clicks a card and the opponent picks at random.
- The crib is a single pile beside the dealer's cards and is revealed at the show.
- Each player has a pegging and game score counter; Go, 31, last card and His Heels show a brief on-screen banner, and the pile stays visible before the count resets.
- A full-height scrolling game log on the left records the whole encounter, hand by hand.
