# Improvement Suggestions

This list prioritizes practical improvements based on current prototype behavior.

## High Priority (Gameplay Reliability)

1. **Guaranteed Nearby Ore Spawn**
   - Ensure at least one ore cluster spawns within a short traversal radius from initial landing.
   - Prevent dead starts where radar never enters range.

2. **Power Economy Tuning**
   - Separate power costs by state (ground drive vs airborne stabilization vs thruster sustain).
   - Add clear low-power thresholds and feedback cues.

3. **Weapon Hit Feedback**
   - Add impact flashes/particles at hit points.
   - Add audio + cooldown feedback for both guns.

4. **Mining Readability**
   - Add short collection VFX/sound and floating ore gain text.
   - Add simple mining cooldown indicator to HUD.

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

## Long-Term / Final Polish

1. Add high-quality art pass for rover/planet props.
2. Add soundscape and reactive audio layers.
3. Add enemy VFX/animations and cinematic mission intro/exit transitions.
4. Add save/progression framework for runs and unlocks.

