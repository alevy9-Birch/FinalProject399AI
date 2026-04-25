# Expedition Rover II - The Sequel: Game Design Overview

## Vision

`Expedition Rover II - The Sequel` is a physics-forward rover game with a silly tone.  
The player deploys to generated planets, gathers ore, manages fuel and battery power, survives hostile pressure, and returns with the highest possible score.

Primary design principle: **readable gameplay first, visual polish second**.

## Core Loop

1. **Mission Briefing (Main Menu)**
   - Show generated mission conditions.
   - Key intel: alien presence, ore quantity, size, gravity, surface props, flavor review.
2. **Mission Preparation (Customization Menu)**
   - Pick chassis (varied base stats + slot locks).
   - Configure color and component upgrades.
3. **Gameplay (Planet Surface)**
   - Land and drive across procedural terrain.
   - Detect and mine ore.
   - Manage thruster fuel and battery power.
   - Use equipped weapons/tools.
   - Survive enemy waves and seek escape altitude.
4. **Score Outcome**
   - Ore collected contributes to run score.
   - On run end, return to main menu with `last` and `best` summary.

## Current Implemented Systems

- **Procedural mission generation** (seeded):
  - planet type, gravity, size, ore count, prop profile, mission flavor.
- **Planet generation**:
  - procedural terrain mesh + collision.
  - contextual props (trees/crystals/ruins/ice/etc).
- **Rover driving model**:
  - ground traction behavior, in-air torque control, planet-relative gravity.
- **Thruster model**:
  - strong burst + sustain, finite fuel, refill lock until recharged on landing.
- **Ore loop**:
  - visible ore nodes.
  - radar proximity behavior.
  - mining input (`G`) + score increment.
- **Customization/loadout**:
  - chassis base stats.
  - up to 4 component slots with lock rules per chassis.
  - upgrade modifiers applied to gameplay stats.
- **Power/battery system**:
  - battery capacity, regen, and action costs (movement/thrusters/mining/weapons).
- **Weapon system (upgrade dependent)**:
  - Gatling and Big Betsy functional firing behavior.
  - crosshair + tracer shot visuals.
- **Enemy loop**:
  - slow-ramping spawner over session time.
  - Minion groups of 3 with noisy pursuit and weak slow projectiles.
  - Turrets with one-second warning beam before high-knockback hitscan fire.
  - UFOs that hover high and fire very slow high-knockback projectiles.
- **Run-state loop**:
  - Death: roof button contact or `R` returns to main menu.
  - Win: reach configurable altitude above planet surface.
  - Run score persistence: current run, last run, best run.
- **Jetpack extraction power-up**:
  - Spawned near start.
  - Grants permanent stronger thrusters without normal fuel gating.

## UI Intent by Screen

- **Main Menu**
  - Purpose: mission understanding, not deep config.
  - Focus: mission card and launch into prep.
- **Customization**
  - Purpose: prepare rover and loadout.
  - Focus: chassis, slots, upgrades, stat feedback.
- **Gameplay HUD**
  - Purpose: operational awareness.
  - Focus: fuel, battery, score, nearest ore, radar/mining state, speed, weapon status.

## Planned Full Experience (Next Target State)

- Replace prototype enemy set with full GDD enemy taxonomy (grunts/swarm/turret/UFO variants).
- Add explicit enemy-vs-player damage model (currently knockback-centric).
- Improve combat readability (warning cues, hit VFX, sound, cleanup safety).
- Expand run progression beyond per-session best/last score.

