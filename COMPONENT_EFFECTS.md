# Component Effects Reference

This document lists the exact runtime effects of each rover component currently defined in `scripts/game_state.gd`.

## How Component Stats Are Applied

- Components are additive modifiers applied on top of the selected chassis base stats.
- Final rover stats are calculated from:
  - selected chassis base values
  - equipped components in unlocked slots
- Locked slots do not contribute effects.
- If the same component is equipped in multiple unlocked slots, its modifiers stack additively.
- Positive values increase a stat; negative values reduce a stat.

## Affected Stat Keys (Quick Definitions)

- `mass`: Rover body mass.
- `drive_force`: Ground acceleration force.
- `max_drive_speed`: Top forward driving speed target.
- `turn_torque`: Ground turning strength.
- `air_torque`: In-air rotation authority.
- `thruster_fuel_capacity`: Max thruster fuel pool.
- `thruster_initial_impulse_force`: Burst force at thruster press start.
- `thruster_sustain_force`: Continuous upward thruster force.
- `thruster_initial_burst_cost`: Fuel spent on initial burst.
- `thruster_burn_rate`: Fuel burn while holding thruster.
- `thruster_recharge_rate_mult`: Multiplier applied to grounded idle thruster recharge speed.
- `radar_range`: Ore detection range (further scaled by rover radar multiplier logic).
- `mining_range`: Distance where mining can occur.
- `battery_max_power`: Maximum battery reserve.
- `power_regen_rate`: Battery regeneration rate.
- `drive_power_drain`: Power consumed while driving.
- `thruster_power_drain_mult`: Power multiplier during thruster use.
- `mining_power_cost`: Battery cost per mining action.
- `weapon_power_cost`: Battery cost per weapon shot/action.

## Default Stat Values (Baseline Before Components)

Component effects are applied on top of the selected chassis base stats, so defaults vary by chassis for most keys.

### Chassis-Dependent Defaults

These values come from `CHASSIS_DATA.base_stats` in `scripts/game_state.gd`.

| Stat Key | Scout Chassis | Expedition Chassis | Juggernaut Chassis |
|---|---:|---:|---:|
| `mass` | 7.0 | 9.4 | 13.4 |
| `drive_force` | 820.0 | 810.0 | 770.0 |
| `max_drive_speed` | 31.0 | 30.0 | 27.0 |
| `turn_torque` | 108.0 | 100.0 | 90.0 |
| `air_torque` | 58.0 | 55.0 | 50.0 |
| `thruster_fuel_capacity` | 95.0 | 120.0 | 160.0 |
| `thruster_initial_impulse_force` | 480.0 | 545.0 | 630.0 |
| `thruster_sustain_force` | 320.0 | 360.0 | 415.0 |
| `thruster_initial_burst_cost` | 24.0 | 30.0 | 34.0 |
| `thruster_burn_rate` | 44.0 | 50.0 | 55.0 |
| `battery_max_power` | 115.0 | 140.0 | 160.0 |
| `power_regen_rate` | 4.5 | 4.3 | 3.8 |
| `drive_power_drain` | 3.0 | 3.6 | 4.4 |
| `thruster_power_drain_mult` | 1.25 | 1.45 | 1.6 |
| `mining_power_cost` | 6.0 | 6.0 | 7.0 |
| `weapon_power_cost` | 0.0 | 0.0 | 0.0 |

### Global Defaults (Not Set Per Chassis)

These defaults come from rover runtime exports in `scripts/rover_controller.gd` and are then modified by components:

| Stat Key | Default Value | Notes |
|---|---:|---|
| `radar_range` | 50.0 | Later multiplied by global radar multiplier in rover logic. |
| `mining_range` | 7.5 | Used for direct and auto-drill collection range checks. |
| `radar_flash_hz` | 7.5 | Radar pulse rate. |
| `thruster_recharge_rate_mult` | 1.0 | Multiplies grounded idle recharge (`25%/s * mult`). |

---

## Component-by-Component Effects

### None

- **Exact modifiers:** none
- **Net effect:** No stat changes.

### Lead Brick

- **Exact modifiers:**
  - `mass`: `+2.8`
  - `air_torque`: `-8.0`
- **Practical impact:**
  - Heavier rover with reduced in-air correction.
  - Improves planted feel but makes aerial recovery and flips harder.

### Battery

- **Exact modifiers:**
  - `thruster_fuel_capacity`: `+35.0`
  - `battery_max_power`: `+40.0`
- **Practical impact:**
  - Larger thruster fuel pool.
  - Larger battery buffer for sustained movement, mining, and combat.

### Solar Panel

- **Exact modifiers:**
  - `thruster_recharge_rate_mult`: `+0.4`
  - `power_regen_rate`: `+1.6`
- **Practical impact:**
  - Increases passive battery recovery.
  - Increases thruster recharge speed under the new refill rules (grounded and thruster-idle), effectively changing recharge from `25%/s` to `35%/s` with one Solar Panel.

### Radar

- **Exact modifiers:**
  - `radar_range`: `+20.0`
- **Practical impact:**
  - Extends ore detection distance before final radar multiplier application.
  - Helps maintain ore awareness while traversing larger terrain.

### Auto Drill

- **Exact modifiers:**
  - `mining_range`: `+2.5`
- **Practical impact:**
  - Expands effective pickup window around ore nodes.
  - Also unlocks auto-drill behavior capability checks in gameplay.

### Gatling Gun

- **Exact modifiers:**
  - `mass`: `+1.2`
  - `weapon_power_cost`: `+1.0`
- **Attack profile:**
  - **Damage per hit:** `4.0`
  - **Fire rate:** `8.0 shots/sec` per Gatling copy (hold-to-fire).
  - **Duplicate scaling:** Fire rate scales linearly with copies (`8.0 * copies` shots/sec).
  - **Range:** `95.0`
- **Practical impact:**
  - Enables rapid-fire weapon behavior.
  - Adds weight and raises battery cost to `1.0` per shot (base weapon cost is `0`).
  - Additional Gatling copies increase fire rate only; they do not increase per-shot cost or per-hit damage.

### Big Betsy

- **Exact modifiers:**
  - `mass`: `+2.0`
  - `weapon_power_cost`: `+4.0`
- **Attack profile:**
  - **Damage per hit:** `30.0`
  - **Fire rate:** `~1.54 shots/sec` per Big Betsy copy (cooldown `0.65s`, click-to-fire).
  - **Duplicate scaling:** Fire rate scales linearly with copies (cooldown divided by copy count).
  - **Range:** `125.0`
- **Practical impact:**
  - Enables heavy cannon behavior.
  - Heavier than Gatling loadout and costs `4.0` power per shot.
  - Additional Big Betsy copies increase fire rate only; they do not increase per-shot cost or per-hit damage.

### Thrusters

- **Exact modifiers:**
  - `thruster_initial_impulse_force`: `+120.0`
  - `thruster_sustain_force`: `+70.0`
  - `thruster_burn_rate`: `+10.0`
- **Practical impact:**
  - Much stronger launch and sustained lift.
  - Trades that power for faster fuel consumption.

### Gyroscopic Sensor

- **Exact modifiers:**
  - `air_torque`: `+18.0`
- **Practical impact:**
  - Stronger in-air orientation control.
  - Improves recovery from jumps, knockback, and uneven terrain launches.

### Rubber Tires

- **Exact modifiers:**
  - `drive_force`: `+140.0`
- **Practical impact:**
  - Better acceleration and climbing response while grounded.
  - Helpful for maintaining momentum under gravity and slope load.

### Supercharged Engine

- **Exact modifiers:**
  - `mass`: `+1.4`
  - `drive_force`: `+200.0`
  - `max_drive_speed`: `+6.0`
  - `thruster_burn_rate`: `+5.0`
  - `drive_power_drain`: `+1.0`
- **Practical impact:**
  - Major ground mobility increase (accel + top speed).
  - Increases ground and air speed, but also fuel and energy usage.

### Steering Wheel

- **Exact modifiers:**
  - `turn_torque`: `+24.0`
- **Practical impact:**
  - Faster turn-in and tighter directional response.
  - Especially noticeable during medium/high-speed steering corrections.

---

## Capability Unlock Notes

Some components do more than stat changes by toggling gameplay capabilities:

- `Gatling Gun`: enables gatling firing mode.
- `Big Betsy`: enables heavy cannon firing mode.
- `Auto Drill`: enables timed automatic ore collection when in mining range.

These checks are performed by rover runtime logic in addition to any numeric stat modifiers.

