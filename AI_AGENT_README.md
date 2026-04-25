# AI Agent README (Project Handoff)

This file is for future agents who need to quickly continue work on this repository.

## Project Snapshot

- Engine: Godot 4.x
- Genre: physics rover mission prototype
- Core flow: `MainMenu -> CustomizationMenu -> Main gameplay`
- Current focus: feature correctness and gameplay readability over final visuals

## Key Scenes

- `scenes/MainMenu.tscn`
  - Mission briefing generation display.
- `scenes/CustomizationMenu.tscn`
  - Chassis/loadout preparation and preview.
- `scenes/Main.tscn`
  - Procedural planet gameplay + HUD.
- `scenes/Rover.tscn`
  - Rover body and gameplay controller attachment.

## Key Scripts

- `scripts/mission_generator.gd`
  - Seeded mission generation and briefing/gameplay parameters.
- `scripts/planet_terrain.gd`
  - Procedural terrain mesh/collision, props, ore spawn.
- `scripts/rover_controller.gd`
  - Main gameplay logic:
    - movement
    - thrusters
    - radar/mining
    - power system
    - weapon fire
    - HUD updates
- `scripts/game_state.gd`
  - Global runtime state:
    - selected chassis/color/upgrades
    - upgrade modifiers
    - derived final rover stats
- `scripts/test_control.gd`
  - Handles `T` test exit marker + quit.
- `scripts/test_logger.gd`
  - Emits structured `__LOG__` events.

## Test/Monitoring Workflow

There is no separate shell test script file; testing is run by launching the Godot executable with the repo path and monitoring console output.

### Launch command (Windows PowerShell)

```powershell
& "C:\Users\amlev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --path .
```

### Runtime control contract

- `T` (`end_test`) should:
  - print `__END_TEST_REQUEST__`
  - print `__LOG__ end_test_pressed`
  - quit the game
- `R` (`reset_vehicle`) currently returns gameplay to main menu (temporary test behavior)

### What to watch in logs

- Hard failures: lines containing `ERROR`
- Warnings worth tracking: repeated shader/tangent warnings
- Structured events:
  - `__LOG__ mission_generated`
  - `__LOG__ menu_*` transitions
  - `__LOG__ rover_telemetry ...`
  - `__LOG__ ore_collected` / `ore_auto_collected`
- Test end marker:
  - `__END_TEST_REQUEST__`

### Polling guidance

- Poll logs every 1-2 seconds during active test sessions.
- If test is clearly failed/hung, close process and report cause + next fix.
- After test ends, report:
  1. outcome
  2. observed player path/actions from logs
  3. issues + likely fixes

## Current Gameplay Capability Summary

- Mission generation and briefing.
- Chassis + upgrade preparation.
- Procedural planet + props + visible ore.
- Radar/mining loop with score.
- Fuel + battery power economy.
- Weapon upgrades with crosshair/tracer fire visuals.

## Known Caveats

- Some systems remain monolithic in `rover_controller.gd`.
- Enemy combat loop is not fully implemented yet.
- Balance values are in active tuning phase.
- Temporary testing scaffolding still exists and will be removed later.

## Working Guidelines for Future Agents

1. Preserve existing temporary test controls unless explicitly asked to remove.
2. Prefer implementing gameplay behavior first; visual polish after validation.
3. Keep menu intent focused:
   - Main = mission briefing
   - Customization = mission prep
   - Gameplay = operational HUD
4. After meaningful changes:
   - run lints/diagnostics,
   - run a monitored test,
   - provide a concise behavior report.

