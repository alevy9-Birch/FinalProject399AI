# Project Checklist

This checklist tracks implementation status for the current prototype.

## Done

- [x] Godot project setup and base scene flow.
- [x] Main menu -> customization -> gameplay navigation.
- [x] Temporary test controls:
  - [x] `R` return to main menu from gameplay.
  - [x] `T` end test (`__END_TEST_REQUEST__` + quit).
- [x] Structured test telemetry logging (`TestLogger` heartbeat + events).
- [x] Seeded mission generation and mission briefing fields.
- [x] Procedural planet mesh/collision with mission-driven parameters.
- [x] Contextual surface prop generation.
- [x] Rover movement, gravity alignment, camera behavior.
- [x] Thruster fuel system with recharge lockout.
- [x] Visible ore generation and ore mining loop.
- [x] Radar flashing/beep behavior and ore proximity checks.
- [x] Gameplay HUD core:
  - [x] fuel
  - [x] power bar
  - [x] score
  - [x] ore distance
  - [x] radar/mining status
  - [x] speed
  - [x] weapon status
- [x] Chassis system with varied base stats.
- [x] Upgrade slot system with per-chassis lock counts.
- [x] Upgrade modifiers applied to runtime rover stats.
- [x] Power/battery economy implementation.
- [x] Weapon upgrades:
  - [x] Gatling firing behavior.
  - [x] Big Betsy firing behavior.
  - [x] Crosshair + tracer visuals.
- [x] Enemy spawning over time (slow start, ramping cadence).
- [x] Enemy archetypes implemented:
  - [x] Minion groups (3).
  - [x] Turret warning + hitscan knockback shot.
  - [x] UFO high-hover slow heavy projectile.
- [x] Enemy health and player weapon damage interaction.
- [x] Enemy projectile knockback (no direct damage).
- [x] Run-state loop:
  - [x] Death (`R` or red button) returns to main menu and records run.
  - [x] Altitude-based win condition returns to main menu and records run.
- [x] Jetpack power-up spawn and pickup behavior.
- [x] Run score tracking (`run`, `last`, `best`) in global state + menu display.

## In Progress / Needs Validation

- [ ] Balance pass for power drain/regen vs movement pacing.
- [ ] Balance pass for ore density vs radar range so mining loop is consistently reachable.
- [ ] Validate upgrade interactions for edge cases (stacking, locked slots, menu transitions).
- [ ] Validate weapon feel and readability under normal gameplay pacing.
- [ ] Validate enemy pacing + knockback fairness on different planet gravity profiles.
- [ ] Validate win altitude threshold against all planet size classes.
- [ ] Validate jetpack power-up accessibility/spawn placement.
- [ ] Validate score lifecycle matches intended design on repeated win/loss cycles.

## Not Done Yet

- [ ] Convert prototype enemies into full GDD enemy roster/behaviors (including swarm and projectile variety).
- [ ] Add proper player health/death-by-combat model (currently no HP-based death loop).
- [ ] Add robust cleanup for runtime-spawned enemy visuals/projectiles to eliminate exit leak warnings.
- [ ] Replace/retire temporary test-specific controls when production UX is finalized.
- [ ] Final art/sound pass and UI polish pass (post-gameplay lock).

## Later Cleanup Tasks

- [ ] Remove temporary debug overlay pipeline if replaced.
- [ ] Remove temporary controls (`R`, `T`) when final UX is decided.
- [ ] Refactor large rover script into subsystems once gameplay stabilizes.

