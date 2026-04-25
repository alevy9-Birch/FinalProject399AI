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

## In Progress / Needs Validation

- [ ] Balance pass for power drain/regen vs movement pacing.
- [ ] Balance pass for ore density vs radar range so mining loop is consistently reachable.
- [ ] Validate upgrade interactions for edge cases (stacking, locked slots, menu transitions).
- [ ] Validate weapon feel and readability under normal gameplay pacing.

## Not Done Yet

- [ ] Alien enemy spawners and behavior sets (grunts/swarm/turret/UFO).
- [ ] Damage/combat resolution loop (enemy and player health/impacts).
- [ ] Mission win/lose rules aligned to full GDD (escape with jetpack condition).
- [ ] Persistent run progression/high score lifecycle.
- [ ] Final art/sound pass and UI polish pass (post-gameplay lock).
- [ ] Cleanup and removal of temporary testing scaffolding when no longer needed.

## Later Cleanup Tasks

- [ ] Remove temporary debug overlay pipeline if replaced.
- [ ] Remove temporary controls (`R`, `T`) when final UX is decided.
- [ ] Refactor large rover script into subsystems once gameplay stabilizes.

