# Game Design

## Vision

Skunked is a cribbage roguelite. Traditional cribbage remains the core game;
run-level perks and modifiers add build choices and replayability. The initial
target is Windows PC, with placeholder visuals and no required paid assets.

## Run structure

A run contains ten configurable stages. Each stage offers two regular encounters
and a mandatory boss encounter. Completing at least two encounters is required;
the optional third encounter can provide extra rewards. A shop follows each
stage.

## Encounters

An encounter defines its opponent, scoring target, hand limit, reward,
difficulty, and retry cost. The initial default is four hands. To win, the
player must meet the target and finish ahead of the opponent. Ties use a
configurable sudden-death hand, including pegging and hand and crib counting.

## Cribbage foundation

The initial rules target a standard 52-card deck per player, six-card deals,
two discards per player into a shared crib, a cut from the dealer's deck, and
traditional hand, crib, and pegging scores. The AI begins as a legal,
configurable baseline opponent.

## Progression and perks

A run starts with no currency or perks. Before the first encounter, the player
chooses one free perk from a curated starter selection. Shops offer perks using
data-driven rarity and pricing. Perks may affect scoring, cards, dealing,
encounters, the economy, or opponents.
