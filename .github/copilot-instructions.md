# Copilot instructions

- Work incrementally, one development milestone at a time. Explain intended
  changes before implementing them, and wait for approval before starting the
  next milestone.
- Preserve existing functionality and unrelated code. Prefer complete,
  functional Godot 4.x GDScript over pseudocode.
- Keep game state, card data, deck logic, cribbage rules, scoring, AI,
  encounters, progression, economy, and UI appropriately separated. Keep
  gameplay independent of UI and use signals where useful.
- Use reusable scenes and data-driven resources/configuration for cards, perks,
  opponents, encounters, and balance values. Avoid monolithic scripts, scattered
  perk conditionals, unnecessary dependencies, and hardcoded balance values in
  scene scripts.
- Use Godot-native placeholder visuals until custom art is requested. Do not
  assume paid assets have been purchased.
- Test gameplay rules and verify the project opens and runs after each
  milestone. Fix failing tests before proceeding; do not report untested
  features as complete.
- Keep project files and assets inside the project directory. Avoid
  machine-specific absolute paths in project scripts.
- Do not move the project to another directory without permission. On the
  primary Windows machine, the working copy should be on the local Desktop and
  outside OneDrive, Documents, Downloads, virtual, or redirected storage.
- Do not implement the whole game in one pass or create final art unless
  specifically requested.
