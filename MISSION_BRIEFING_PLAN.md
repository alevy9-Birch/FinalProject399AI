# Mission Briefing + Planet Generation Plan

This document defines the first implementation plan for mission briefing data and real-time planet generation for **Expedition Rover II - The Sequel**.

## Goals

- Keep mission data deterministic so menu briefing always matches gameplay.
- Support multiple planet archetypes with distinct feel.
- Expose clean enum-based fields for UI and gameplay systems.
- Keep scope practical: briefing first, then wiring into generation/spawning.

## Mission Data Model

Use one mission seed to generate all briefing and gameplay parameters.

- `mission_seed: int`
- `planet_type: PlanetType`
- `alien_presence: AlienPresence`
- `ore_quantity: OreQuantity`
- `planet_size_class: PlanetSizeClass`
- `gravity_class: GravityClass`
- `yelp_flavor: YelpFlavor`
- `yelp_score: float` (1.0 to 5.0)
- `yelp_tagline: String`

Derived gameplay values (generated from enums + seed):

- `planet_radius: float`
- `gravity_multiplier: float`
- `terrain_profile: TerrainProfile`
- `ore_node_count: int`
- `ore_yield_range: Vector2i`
- `alien_spawn_budget: int`
- `alien_spawn_interval: float`
- `alien_type_weights: Dictionary`

## Enum Definitions

### `PlanetType`

- `ASTEROID_RUBBLE`
- `CRATERED_MOON`
- `METALLIC_CORE`
- `VOLCANIC_SHARD`
- `ICE_DUSTBALL`

#### Planet Type Behavior

- `ASTEROID_RUBBLE`: small radius, low gravity, jagged terrain, medium-high ore, medium aliens.
- `CRATERED_MOON`: medium radius, medium gravity, smoother craters, balanced ore/aliens.
- `METALLIC_CORE`: medium-small radius, high gravity, hard rough terrain, high ore, high alien pressure.
- `VOLCANIC_SHARD`: medium radius, medium-high gravity, steep ridges, medium ore, high turret/UFO bias.
- `ICE_DUSTBALL`: large radius, low-medium gravity, smoother rolling terrain, lower ore density, safer alien profile.

### `AlienPresence`

- `NONE`
- `LOW`
- `MODERATE`
- `HEAVY`
- `OVERWHELMING`

#### Alien Presence Function

Controls enemy population pressure:

- Spawn interval
- Max concurrent enemies
- Enemy type bias (grunt/swarm/turret/UFO)
- Projectile intensity multiplier

### `OreQuantity`

- `SCARCE`
- `PATCHY`
- `STANDARD`
- `RICH`
- `BONANZA`

#### Ore Quantity Function

Controls resource economy:

- Ore node count
- Average ore yield per node
- Optional scan ping frequency (future detector behavior)

### `PlanetSizeClass`

- `TINY`
- `SMALL`
- `MEDIUM`
- `LARGE`
- `HUGE`

#### Planet Size Function

Controls traversal and world scale:

- Planet radius
- Mission traversal expectation (distance/time)
- Broad terrain feature scale

### `GravityClass`

- `MICRO_G`
- `LOW_G`
- `EARTHLIKE`
- `HEAVY_G`
- `CRUSHING`

#### Gravity Function

Controls handling and movement feel:

- Gravity multiplier for custom planet gravity
- Jump arc and airtime
- Landing impact severity
- Effective thruster lift

### `YelpFlavor`

- `SCENIC_BUT_DEADLY`
- `DUSTY_SERVICEABLE`
- `ORE_PARADISE`
- `HOSTILE_WORKSITE`
- `DO_NOT_RECOMMEND`

#### Yelp Function

Primarily flavor text for mission briefing. Optionally apply tiny balancing nudges (for example +/- 5% to one non-critical variable) to make tags feel connected.

## Generation Pipeline

1. Initialize RNG with `mission_seed`.
2. Roll `planet_type` from weighted distribution.
3. Roll `planet_size_class` and `gravity_class` with type constraints.
4. Roll `ore_quantity` and `alien_presence` with type bias.
5. Derive numeric values for terrain, ore, gravity, and alien systems.
6. Compute Yelp score/tagline from risk-reward profile.
7. Save result as `MissionData` and expose to menu + gameplay.

## Suggested Constraint Rules

- High `PlanetSizeClass` slightly increases chance of lower `GravityClass`.
- `METALLIC_CORE` tends toward `HEAVY_G` and `RICH`.
- `ICE_DUSTBALL` tends toward `LOW_G` and `PATCHY`/`STANDARD`.
- `VOLCANIC_SHARD` tends toward `HEAVY` alien presence.
- `ASTEROID_RUBBLE` avoids `CRUSHING` gravity.

## Mission Briefing UI Fields (Display Contract)

Mission briefing should display:

- Planet Name (generated from seed; to add)
- Alien Presence (enum -> readable text)
- Ore Quantity (enum -> readable text)
- Planet Size (enum -> readable text)
- Planet Gravity (enum -> readable text + numeric `g`)
- Planet Yelp Review (star score + humorous tagline)

## Wiring Plan (Next Steps)

1. Add autoload `MissionGenerator.gd`.
2. Define enums and `MissionData` dictionary schema.
3. Generate mission on main menu open.
4. Bind `MainMenu` labels to generated `MissionData`.
5. On deployment, pass `MissionData` to gameplay scene systems:
  - Planet terrain/radius/gravity
  - Ore spawner
  - Alien spawner

## Initial Scope Guardrails

- Do not implement full alien combat in this phase.
- Keep ore interaction simple until detection/mining loop is stable.
- Keep mission generation deterministic and debuggable (log seed + rolled enums).
- Prioritize rover feel and readable UI over content volume.