# Improvement Suggestions

This list prioritizes practical improvements based on current prototype behavior.

## High Priority (Gameplay Reliability)

1. **Fix Enemy Projectile Spawn Lifecycle Error**
   - Latest tests show `!is_inside_tree()` errors in `enemy_actor.gd` during projectile fire.
   - Guard against firing after actor/tree teardown and centralize safe projectile spawn path.

2. **Fix Exit-Time Leak Warnings**
   - Godot reports leaked MultiMesh/instance dependencies on shutdown.
   - Audit runtime-created visuals (enemy/projectile/warning visuals/starfield) and free ownership lifecycle.

3. **Enemy Pacing and Knockback Balance**
   - Tune spawn cadence, max concurrent enemies, and knockback force by enemy type.
   - Prevent soft-lock pinball states on small/high-gravity planets.

4. **Jetpack + Win-Altitude Tuning**
   - Ensure power-up location is always reachable early in mission.
   - Tune altitude win threshold per planet-size class for consistent mission length.

## Medium Priority (System Design)

1. **Modular Rover Subsystems**
   - Split rover logic into focused components:
     - movement
     - power
     - weapons
     - radar/mining
     - hud feed
   - Reduces regression risk and speeds balancing.

2. **Data-Driven Upgrade Definitions**
   - Move upgrade config from script constants into a dedicated data file.
   - Enables faster iteration and easier balancing.

3. **Mission Difficulty Curves**
   - Create tiers or weighted bands for mission generation.
   - Ensure briefing values reflect intended challenge progression.

4. **Enemy Data Tables**
   - Move enemy stats/behavior constants to data dictionaries/resources.
   - Makes balancing wave composition and per-type tuning faster.

## Medium Priority (UX)

1. **Menu Card Design Consistency**
   - Convert mission and customization sections into reusable card styles.
   - Keep one visual language across all menu screens.

2. **Gameplay HUD Grouping**
   - Cluster HUD by purpose:
     - resource (fuel/power)
     - objective (score/ore)
     - combat (weapon/crosshair)
   - Improves scan speed during action.

3. **Input Hints by Equipped Capability**
   - Show context hints only when relevant:
     - weapon fire hint when weapon equipped
     - mining hint near ore
     - thruster lock warning when grounded recharge lock is active
    - extraction hint once jetpack is collected

## Long-Term / Final Polish

1. Add high-quality art pass for rover/planet props.
2. Add soundscape and reactive audio layers.
3. Add enemy VFX/animations and cinematic mission intro/exit transitions.
4. Add save/progression framework for runs and unlocks.

