extends Node

## Temporary runtime state for main menu <-> gameplay flow.
## Keep simple while test harness exists.

var selected_rover_variant: int = 0
var last_played_variant: int = 0
var selected_color_index: int = 0
var selected_chassis_index: int = 0
var selected_upgrades: PackedStringArray = PackedStringArray(["None", "None", "None", "None"])
var run_score: int = 0
var last_run_score: int = 0
var best_run_score: int = 0

const VARIANT_NAMES: PackedStringArray = [
	"Default Rover"
]

const COLOR_NAMES: PackedStringArray = [
	"Lunar White",
	"Signal Orange",
	"Oxide Red",
	"Research Blue",
	"Olive Utility",
	"Graphite Gray"
]

const COLOR_VALUES: Array[Color] = [
	Color(0.92, 0.93, 0.95, 1.0),
	Color(0.93, 0.56, 0.2, 1.0),
	Color(0.73, 0.27, 0.24, 1.0),
	Color(0.44, 0.66, 0.9, 1.0),
	Color(0.56, 0.64, 0.46, 1.0),
	Color(0.55, 0.58, 0.64, 1.0)
]

const CHASSIS_NAMES: PackedStringArray = [
	"Scout Chassis",
	"Expedition Chassis",
	"Juggernaut Chassis"
]

const CHASSIS_DATA: Array[Dictionary] = [
	{
		"name": "Scout Chassis",
		"unlocked_slots": 4,
		"base_stats": {
			"mass": 7.0,
			"drive_force": 820.0,
			"max_drive_speed": 31.0,
			"turn_torque": 108.0,
			"air_torque": 58.0,
			"thruster_fuel_capacity": 95.0,
			"thruster_initial_impulse_force": 480.0,
			"thruster_sustain_force": 320.0,
			"thruster_initial_burst_cost": 24.0,
			"thruster_burn_rate": 44.0,
			"battery_max_power": 115.0,
			"power_regen_rate": 4.5,
			"drive_power_drain": 3.0,
			"thruster_power_drain_mult": 1.25,
			"mining_power_cost": 6.0,
			"weapon_power_cost": 4.0
		}
	},
	{
		"name": "Expedition Chassis",
		"unlocked_slots": 3,
		"base_stats": {
			"mass": 8.8,
			"drive_force": 760.0,
			"max_drive_speed": 28.0,
			"turn_torque": 95.0,
			"air_torque": 52.0,
			"thruster_fuel_capacity": 110.0,
			"thruster_initial_impulse_force": 510.0,
			"thruster_sustain_force": 340.0,
			"thruster_initial_burst_cost": 28.0,
			"thruster_burn_rate": 48.0,
			"battery_max_power": 130.0,
			"power_regen_rate": 4.0,
			"drive_power_drain": 3.4,
			"thruster_power_drain_mult": 1.35,
			"mining_power_cost": 6.0,
			"weapon_power_cost": 4.8
		}
	},
	{
		"name": "Juggernaut Chassis",
		"unlocked_slots": 2,
		"base_stats": {
			"mass": 12.0,
			"drive_force": 690.0,
			"max_drive_speed": 24.0,
			"turn_torque": 82.0,
			"air_torque": 44.0,
			"thruster_fuel_capacity": 145.0,
			"thruster_initial_impulse_force": 560.0,
			"thruster_sustain_force": 370.0,
			"thruster_initial_burst_cost": 30.0,
			"thruster_burn_rate": 52.0,
			"battery_max_power": 145.0,
			"power_regen_rate": 3.4,
			"drive_power_drain": 3.9,
			"thruster_power_drain_mult": 1.45,
			"mining_power_cost": 7.0,
			"weapon_power_cost": 5.5
		}
	}
]

const UPGRADE_NAMES: PackedStringArray = [
	"None",
	"Lead Brick",
	"Battery",
	"Solar Panel",
	"Radar",
	"Auto Drill",
	"Metal Detector",
	"Gatling Gun",
	"Big Betsy",
	"Thrusters",
	"Gyroscopic Sensor",
	"Rubber Tires",
	"Supercharged Engine",
	"Steering Wheel",
	"Dual Factor Authentication"
]

const UPGRADE_MODIFIERS: Dictionary = {
	"None": {},
	"Lead Brick": {"mass": 2.8, "air_torque": -8.0},
	"Battery": {"thruster_fuel_capacity": 35.0, "thruster_burn_rate": -4.0, "battery_max_power": 40.0},
	"Solar Panel": {"thruster_refill_rate": 8.0, "power_regen_rate": 2.2},
	"Radar": {"radar_range": 20.0},
	"Auto Drill": {"mining_range": 2.5},
	"Metal Detector": {"radar_flash_hz": 2.5},
	"Gatling Gun": {"mass": 1.2, "weapon_power_cost": 1.6},
	"Big Betsy": {"mass": 2.0, "weapon_power_cost": 3.2},
	"Thrusters": {"thruster_initial_impulse_force": 120.0, "thruster_sustain_force": 70.0, "thruster_burn_rate": 10.0},
	"Gyroscopic Sensor": {"air_torque": 18.0},
	"Rubber Tires": {"drive_force": 90.0},
	"Supercharged Engine": {"mass": 1.4, "drive_force": 130.0, "max_drive_speed": 4.0, "thruster_burn_rate": 5.0},
	"Steering Wheel": {"turn_torque": 24.0},
	"Dual Factor Authentication": {}
}

const UPGRADE_DESCRIPTIONS: Dictionary = {
	"None": "No component equipped in this slot.",
	"Lead Brick": "Adds heavy ballast. Improves stability but reduces air control.",
	"Battery": "Adds extra battery storage and slightly improves fuel economy.",
	"Solar Panel": "Regenerates power faster and improves refuel pacing.",
	"Radar": "Increases ore detection range.",
	"Auto Drill": "Automatically mines ore while in mining range.",
	"Metal Detector": "Boosts radar pulse frequency and highlights mining window.",
	"Gatling Gun": "Rapid-fire weapon with low per-shot power cost.",
	"Big Betsy": "Heavy cannon with slower cadence and high impact.",
	"Thrusters": "Improves thrust force but increases consumption pressure.",
	"Gyroscopic Sensor": "Stronger in-air correction and tilt control.",
	"Rubber Tires": "Improves traction and drive response.",
	"Supercharged Engine": "Higher speed and drive force at higher energy usage.",
	"Steering Wheel": "Sharper turning response.",
	"Dual Factor Authentication": "Safety module for later self-destruct systems."
}


func get_selected_chassis() -> Dictionary:
	var idx: int = clampi(selected_chassis_index, 0, CHASSIS_DATA.size() - 1)
	return CHASSIS_DATA[idx]


func get_unlocked_slot_count() -> int:
	var chassis: Dictionary = get_selected_chassis()
	return clampi(int(chassis.get("unlocked_slots", 4)), 0, 4)


func set_upgrade_in_slot(slot_idx: int, upgrade_name: String) -> void:
	if slot_idx < 0 or slot_idx >= selected_upgrades.size():
		return
	selected_upgrades[slot_idx] = upgrade_name


func get_final_rover_stats() -> Dictionary:
	var chassis: Dictionary = get_selected_chassis()
	var base_stats: Dictionary = (chassis.get("base_stats", {}) as Dictionary).duplicate(true)
	var unlocked_slots: int = get_unlocked_slot_count()
	for i in range(min(unlocked_slots, selected_upgrades.size())):
		var upgrade_name: String = selected_upgrades[i]
		var mod: Dictionary = UPGRADE_MODIFIERS.get(upgrade_name, {})
		for key in mod.keys():
			base_stats[key] = float(base_stats.get(key, 0.0)) + float(mod[key])
	return base_stats


func has_upgrade(upgrade_name: String) -> bool:
	var unlocked_slots: int = get_unlocked_slot_count()
	for i in range(min(unlocked_slots, selected_upgrades.size())):
		if selected_upgrades[i] == upgrade_name:
			return true
	return false


func get_upgrade_description(upgrade_name: String) -> String:
	return str(UPGRADE_DESCRIPTIONS.get(upgrade_name, "No description available."))


func start_new_run() -> void:
	run_score = 0


func add_score(amount: int) -> void:
	run_score += maxi(0, amount)


func finish_run(player_won: bool) -> void:
	last_run_score = run_score
	best_run_score = maxi(best_run_score, run_score)
	if not player_won:
		run_score = 0
