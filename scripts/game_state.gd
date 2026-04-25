extends Node

## Temporary runtime state for main menu <-> gameplay flow.
## Keep simple while test harness exists.

var selected_rover_variant: int = 0
var last_played_variant: int = 0
var selected_color_index: int = 0
var selected_chassis_index: int = 0
var selected_upgrades: PackedStringArray = PackedStringArray(["None", "None", "None", "None"])

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
			"thruster_initial_impulse_force": 290.0,
			"thruster_sustain_force": 178.0
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
			"thruster_initial_impulse_force": 305.0,
			"thruster_sustain_force": 182.0
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
			"thruster_initial_impulse_force": 340.0,
			"thruster_sustain_force": 205.0
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
	"Battery": {"thruster_fuel_capacity": 35.0},
	"Solar Panel": {"thruster_refill_rate": 8.0},
	"Radar": {"radar_range": 20.0},
	"Auto Drill": {"mining_range": 2.5},
	"Metal Detector": {"radar_flash_hz": 0.8},
	"Gatling Gun": {"mass": 1.2},
	"Big Betsy": {"mass": 2.0},
	"Thrusters": {"thruster_initial_impulse_force": 85.0, "thruster_sustain_force": 45.0},
	"Gyroscopic Sensor": {"air_torque": 18.0},
	"Rubber Tires": {"drive_force": 90.0},
	"Supercharged Engine": {"mass": 1.4, "drive_force": 130.0, "max_drive_speed": 4.0, "thruster_burn_rate": 5.0},
	"Steering Wheel": {"turn_torque": 24.0},
	"Dual Factor Authentication": {}
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
