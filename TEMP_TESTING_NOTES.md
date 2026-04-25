Temporary test harness notes (remove once no longer needed):

- Menu flow (temporary):
  - Main Menu -> Customization Menu -> Gameplay.
  - Gameplay `R` returns to Main Menu.

- In-game controls:
  - `R` (`reset_vehicle`): return to `MainMenu` from gameplay.
  - `T` (`end_test`): prints `__END_TEST_REQUEST__` and exits game.
- Debug overlay:
  - `scripts/debug_overlay.gd` reads `res://debug_status.txt` every 0.25s.
  - Monitoring agents can update `debug_status.txt` to show live messages in-game.
- Test logging:
  - `TestLogger` autoload emits `__LOG__` heartbeat + event lines.
  - Gameplay emits periodic `rover_telemetry` (speed, fuel, grounded, variant).
  - Menus emit variant/color selection and scene transition events.
- Expected monitor behavior:
  - Launch game with console output enabled.
  - Poll logs frequently (1-2s) and watch for runtime `ERROR` lines, `__END_TEST_REQUEST__`, and `__LOG__` events.
  - If test fails, close the game process immediately.
  - After test ends, report:
    1) outcome summary,
    2) actions observed from logs,
    3) likely issues + next-step ideas,
    then ask for player feedback.
