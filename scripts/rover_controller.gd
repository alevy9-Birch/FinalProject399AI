extends RigidBody3D

## TEMP TEST CONTROLS (remove later):
## - Press T (`end_test` action) to request end of monitored test.
## - This script prints "__END_TEST_REQUEST__" and quits immediately.
## - Monitoring agents should watch for that marker and then summarize the run.

@export var drive_force: float = 760.0
@export var reverse_force_scale: float = 0.7
@export var brake_force: float = 620.0
@export var turn_torque: float = 95.0
@export var air_torque: float = 52.0
@export var max_drive_speed: float = 28.0
@export var steer_max_degrees: float = 30.0
@export var steer_visual_speed: float = 10.0
@export var wheel_radius: float = 0.42
@export var suspension_travel: float = 0.42
@export var suspension_rest_distance: float = 1.0
@export var ground_grip: float = 12.0
@export var longitudinal_damping: float = 1.35
@export var downforce: float = 14.0
@export var landing_vertical_damp: float = 2.4
@export var suspension_visual_smooth: float = 14.0
@export var moving_turn_speed_threshold: float = 1.8
@export var thruster_initial_impulse_force: float = 520.0
@export var thruster_sustain_force: float = 340.0
@export var thruster_afterburner_force: float = 40.0
@export var thruster_fuel_capacity: float = 100.0
@export var thruster_initial_burst_cost: float = 30.0
@export var thruster_burn_rate: float = 48.0
@export var thruster_refill_rate: float = 34.0
@export var planet_path: NodePath = NodePath("../Planet")
@export var gravity_strength: float = 26.0
@export var anti_roll_force: float = 22.0
@export var radar_range: float = 55.0
@export var mining_range: float = 8.0
@export var radar_flash_hz: float = 7.5
@export var radar_beep_volume_db: float = -16.0
@export var win_altitude_above_surface: float = 180.0

@onready var _ground_rays: Array[RayCast3D] = [
	$GroundRays/FrontLeftRay,
	$GroundRays/FrontRightRay,
	$GroundRays/BackLeftRay,
	$GroundRays/BackRightRay,
	$GroundRays/MidLeftRay,
	$GroundRays/MidRightRay
]
@onready var _reset_button_ray: RayCast3D = $ResetButton/ButtonRay
@onready var _chassis_collision: CollisionShape3D = $CollisionShape3D
@onready var _front_left_pivot: Node3D = $WheelVisuals/FrontLeftWheelPivot
@onready var _front_right_pivot: Node3D = $WheelVisuals/FrontRightWheelPivot
@onready var _back_left_pivot: Node3D = $WheelVisuals/BackLeftWheelPivot
@onready var _back_right_pivot: Node3D = $WheelVisuals/BackRightWheelPivot
@onready var _mid_left_pivot: Node3D = $WheelVisuals/MidLeftWheelPivot
@onready var _mid_right_pivot: Node3D = $WheelVisuals/MidRightWheelPivot
@onready var _wheel_meshes: Array[MeshInstance3D] = [
	$WheelVisuals/FrontLeftWheelPivot/FrontLeftWheel,
	$WheelVisuals/FrontRightWheelPivot/FrontRightWheel,
	$WheelVisuals/BackLeftWheelPivot/BackLeftWheel,
	$WheelVisuals/BackRightWheelPivot/BackRightWheel,
	$WheelVisuals/MidLeftWheelPivot/MidLeftWheel,
	$WheelVisuals/MidRightWheelPivot/MidRightWheel
]
@onready var _variant_visuals: Array[Node3D] = [
	$VariantRoot/VariantA
]
@onready var _radar_buttons: Array[MeshInstance3D] = [
	$VariantRoot/VariantA/RadarButtonFront,
	$VariantRoot/VariantA/RadarButtonDish
]
@onready var _thruster_bar: ProgressBar = get_node_or_null("/root/Main/HUD/ThrusterPanel/ThrusterBar") as ProgressBar
@onready var _score_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/ScoreLabel") as Label
@onready var _ore_distance_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/OreDistanceLabel") as Label
@onready var _radar_state_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/RadarStateLabel") as Label
@onready var _mining_prompt_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/MiningPromptLabel") as Label
@onready var _ore_direction_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/OreDirectionLabel") as Label
@onready var _speed_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/SpeedLabel") as Label
@onready var _weapon_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/WeaponLabel") as Label
@onready var _weapon_stats_label: Label = get_node_or_null("/root/Main/HUD/StatusPanel/WeaponStatsLabel") as Label
@onready var _power_bar: ProgressBar = get_node_or_null("/root/Main/HUD/PowerPanel/PowerBar") as ProgressBar
@onready var _crosshair: Label = get_node_or_null("/root/Main/HUD/Crosshair") as Label

var _grounded: bool = false
var _was_grounded_last_frame: bool = false
var _thruster_fuel: float = 100.0
var _thruster_locked_until_full: bool = false
var _thruster_was_pressed: bool = false
var _spawn_transform: Transform3D
var _wheel_pivots: Array[Node3D] = []
var _base_pivot_positions: Array[Vector3] = []
var _wheel_contact: Array[bool] = []
var _suspension_smoothed: Array[float] = []
var _planet: Node3D
var _active_variant_index: int = 0
var _primary_color: Color = Color(0.92, 0.93, 0.95, 1.0)
var _telemetry_timer: float = 0.0
var _radar_button_mats: Array[StandardMaterial3D] = []
var _radar_flash_timer: float = 0.0
var _radar_flash_on: bool = false
var _radar_audio_player: AudioStreamPlayer3D
var _radar_audio_playback: AudioStreamGeneratorPlayback
var _nearest_ore: Node3D
var _nearest_ore_dist: float = INF
var _ore_collected: int = 0
var _battery_max_power: float = 100.0
var _battery_power: float = 100.0
var _power_regen_rate: float = 4.0
var _drive_power_drain: float = 3.0
var _thruster_power_drain_mult: float = 1.3
var _mining_power_cost: float = 6.0
var _weapon_power_cost: float = 4.0
var _has_gatling: bool = false
var _has_big_betsy: bool = false
var _has_auto_drill: bool = false
var _has_metal_detector: bool = false
var _fire_cooldown_timer: float = 0.0
var _fire_hold_last_frame: bool = false
var _shot_visuals_root: Node3D
var _auto_drill_timer: float = 0.0
var _ore_direction_hint_timer: float = 0.0
var _ore_direction_hint_text: String = "Ore Direction: --"
var _stuck_tilt_timer: float = 0.0
var _thruster_particles: Array[GPUParticles3D] = []
var _permanent_thrusters_active: bool = false
var _permanent_thruster_force: float = 540.0
var _run_ending: bool = false

const VARIANT_STATS: Array[Dictionary] = [
	{ # Default Rover
		"mass": 8.0, "drive_force": 760.0, "max_drive_speed": 28.0,
		"thruster_fuel_capacity": 100.0, "thruster_initial_impulse_force": 280.0, "thruster_sustain_force": 170.0
	}
]


func _ready() -> void:
	_spawn_transform = global_transform
	_wheel_pivots = [_front_left_pivot, _front_right_pivot, _back_left_pivot, _back_right_pivot, _mid_left_pivot, _mid_right_pivot]
	_apply_selected_variant()
	_apply_custom_loadout_stats()
	_apply_selected_color()
	_apply_chassis_geometry()
	_base_pivot_positions.clear()
	for pivot in _wheel_pivots:
		_base_pivot_positions.append(pivot.position)
	_wheel_contact.resize(_wheel_pivots.size())
	_suspension_smoothed.resize(_wheel_pivots.size())
	for i in range(_wheel_pivots.size()):
		_wheel_contact[i] = false
		_suspension_smoothed[i] = 0.0
	_apply_mission_gravity()
	_setup_radar_materials()
	_setup_radar_audio()
	_setup_shot_visuals()
	_setup_thruster_particles()
	_thruster_fuel = thruster_fuel_capacity
	_battery_power = _battery_max_power
	var state := get_node_or_null("/root/GameState")
	if state != null:
		_ore_collected = int(state.run_score)
	call_deferred("_ensure_spawn_above_surface")


func _physics_process(delta: float) -> void:
	if _run_ending or not is_inside_tree():
		return
	if Input.is_action_just_pressed("reset_vehicle"):
		_handle_run_end(false, "manual_reset")
		return

	_update_wheel_contacts()
	_grounded = _contact_count() > 0
	_resolve_planet()
	if _planet != null:
		_apply_planet_gravity()
		_apply_stability_torque(delta)
		_check_win_altitude()
	var forward_input: float = Input.get_axis("move_backward", "move_forward")
	var turn_input: float = Input.get_axis("move_right", "move_left")
	var boost_pressed: bool = Input.is_action_pressed("thruster")
	var forward_speed: float = linear_velocity.dot(-global_basis.z)
	var effective_turn_input: float = _get_effective_turn_input(forward_input, turn_input, forward_speed)
	_update_power_budget(delta, forward_input, boost_pressed)
	var power_ratio: float = 0.0 if _battery_max_power <= 0.0 else clampf(_battery_power / _battery_max_power, 0.0, 1.0)
	var can_drive: bool = power_ratio > 0.05
	var can_thruster: bool = power_ratio > 0.07
	var drive_input: float = forward_input if can_drive else 0.0
	var turn_for_drive: float = effective_turn_input if can_drive else 0.0

	_apply_drive(drive_input, turn_for_drive, forward_speed)
	_apply_air_control(forward_input, turn_input)
	_apply_ground_grip(delta)
	_apply_thruster(delta, boost_pressed and can_thruster)
	_update_wheel_visuals(effective_turn_input, delta)
	_update_thruster_ui()
	_check_button_orientation_reset()
	_update_thruster_refill(delta)
	_update_ore_radar(delta)
	_handle_mining_input()
	_update_auto_drill(delta)
	_update_weapon_system(delta)
	_update_gameplay_ui(forward_speed)
	_update_hint_timers(delta)
	_was_grounded_last_frame = _grounded
	_log_telemetry(delta, forward_speed)


func _apply_selected_variant() -> void:
	var selected_idx: int = 0
	var state := get_node_or_null("/root/GameState")
	if state != null:
		selected_idx = state.selected_rover_variant
	set_variant_index(selected_idx)


func set_variant_index(index: int) -> void:
	_active_variant_index = clampi(index, 0, _variant_visuals.size() - 1)
	for i in range(_variant_visuals.size()):
		_variant_visuals[i].visible = i == _active_variant_index
	_apply_variant_stats()


func _apply_variant_stats() -> void:
	var stats_idx: int = clampi(_active_variant_index, 0, VARIANT_STATS.size() - 1)
	var stats: Dictionary = VARIANT_STATS[stats_idx]
	mass = stats.get("mass", mass)
	drive_force = stats.get("drive_force", drive_force)
	max_drive_speed = stats.get("max_drive_speed", max_drive_speed)
	thruster_fuel_capacity = stats.get("thruster_fuel_capacity", thruster_fuel_capacity)
	thruster_initial_impulse_force = stats.get("thruster_initial_impulse_force", thruster_initial_impulse_force)
	thruster_sustain_force = stats.get("thruster_sustain_force", thruster_sustain_force)
	_thruster_fuel = clampf(_thruster_fuel, 0.0, thruster_fuel_capacity)


func _apply_selected_color() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		var idx: int = clampi(state.selected_color_index, 0, state.COLOR_VALUES.size() - 1)
		set_primary_color(state.COLOR_VALUES[idx])


func _apply_custom_loadout_stats() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_final_rover_stats"):
		return
	var stats: Dictionary = state.get_final_rover_stats()
	if stats.is_empty():
		return
	mass = float(stats.get("mass", mass))
	drive_force = float(stats.get("drive_force", drive_force))
	max_drive_speed = float(stats.get("max_drive_speed", max_drive_speed))
	turn_torque = float(stats.get("turn_torque", turn_torque))
	air_torque = float(stats.get("air_torque", air_torque))
	thruster_fuel_capacity = float(stats.get("thruster_fuel_capacity", thruster_fuel_capacity))
	thruster_initial_impulse_force = float(stats.get("thruster_initial_impulse_force", thruster_initial_impulse_force))
	thruster_sustain_force = float(stats.get("thruster_sustain_force", thruster_sustain_force))
	thruster_initial_burst_cost = float(stats.get("thruster_initial_burst_cost", thruster_initial_burst_cost))
	thruster_refill_rate = float(stats.get("thruster_refill_rate", thruster_refill_rate))
	thruster_burn_rate = float(stats.get("thruster_burn_rate", thruster_burn_rate))
	radar_range = float(stats.get("radar_range", radar_range))
	mining_range = float(stats.get("mining_range", mining_range))
	radar_flash_hz = float(stats.get("radar_flash_hz", radar_flash_hz))
	_battery_max_power = float(stats.get("battery_max_power", _battery_max_power))
	_power_regen_rate = float(stats.get("power_regen_rate", _power_regen_rate))
	_drive_power_drain = float(stats.get("drive_power_drain", _drive_power_drain))
	_thruster_power_drain_mult = float(stats.get("thruster_power_drain_mult", _thruster_power_drain_mult))
	_mining_power_cost = float(stats.get("mining_power_cost", _mining_power_cost))
	_weapon_power_cost = float(stats.get("weapon_power_cost", _weapon_power_cost))
	_refresh_upgrade_capabilities()


func _apply_chassis_geometry() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		_set_mid_axle_enabled(false)
		return
	var chassis_idx: int = clampi(state.selected_chassis_index, 0, state.CHASSIS_DATA.size() - 1)
	var body_scale: float = 1.0
	var half_track: float = 0.95
	var wheel_y: float = -0.82
	var front_z: float = -1.2
	var back_z: float = 1.2
	match chassis_idx:
		0: # Scout
			body_scale = 0.9
			half_track = 0.9
			front_z = -1.05
			back_z = 1.05
			_set_mid_axle_enabled(false)
		1: # Expedition
			body_scale = 1.0
			half_track = 0.95
			front_z = -1.2
			back_z = 1.2
			_set_mid_axle_enabled(false)
		2: # Juggernaut
			body_scale = 1.22
			half_track = 1.1
			front_z = -1.45
			back_z = 1.45
			_set_mid_axle_enabled(true)
	if _chassis_collision != null and _chassis_collision.shape is BoxShape3D:
		var box: BoxShape3D = (_chassis_collision.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = Vector3(2.2 * body_scale, 0.95 * (0.9 + 0.1 * body_scale), 3.2 * body_scale)
		_chassis_collision.shape = box
	_variant_visuals[0].scale = Vector3.ONE * body_scale
	_front_left_pivot.position = Vector3(-half_track, wheel_y, front_z)
	_front_right_pivot.position = Vector3(half_track, wheel_y, front_z)
	_back_left_pivot.position = Vector3(-half_track, wheel_y, back_z)
	_back_right_pivot.position = Vector3(half_track, wheel_y, back_z)
	_mid_left_pivot.position = Vector3(-half_track, wheel_y, 0.0)
	_mid_right_pivot.position = Vector3(half_track, wheel_y, 0.0)
	$GroundRays/FrontLeftRay.position = Vector3(-half_track, -0.2, front_z)
	$GroundRays/FrontRightRay.position = Vector3(half_track, -0.2, front_z)
	$GroundRays/BackLeftRay.position = Vector3(-half_track, -0.2, back_z)
	$GroundRays/BackRightRay.position = Vector3(half_track, -0.2, back_z)
	$GroundRays/MidLeftRay.position = Vector3(-half_track, -0.2, 0.0)
	$GroundRays/MidRightRay.position = Vector3(half_track, -0.2, 0.0)


func _set_mid_axle_enabled(enabled: bool) -> void:
	_mid_left_pivot.visible = enabled
	_mid_right_pivot.visible = enabled
	$GroundRays/MidLeftRay.enabled = enabled
	$GroundRays/MidRightRay.enabled = enabled


func _refresh_upgrade_capabilities() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		_has_gatling = false
		_has_big_betsy = false
		_has_auto_drill = false
		_has_metal_detector = false
		return
	_has_gatling = state.has_method("has_upgrade") and state.has_upgrade("Gatling Gun")
	_has_big_betsy = state.has_method("has_upgrade") and state.has_upgrade("Big Betsy")
	_has_auto_drill = state.has_method("has_upgrade") and state.has_upgrade("Auto Drill")
	_has_metal_detector = state.has_method("has_upgrade") and state.has_upgrade("Metal Detector")


func _setup_shot_visuals() -> void:
	_shot_visuals_root = Node3D.new()
	_shot_visuals_root.name = "ShotVisuals"
	add_child(_shot_visuals_root)


func _setup_thruster_particles() -> void:
	_thruster_particles.clear()
	var local_offsets: Array[Vector3] = [Vector3(-0.42, -0.18, 1.38), Vector3(0.42, -0.18, 1.38)]
	for off in local_offsets:
		var p := GPUParticles3D.new()
		p.amount = 36
		p.lifetime = 0.32
		p.one_shot = false
		p.explosiveness = 0.0
		p.randomness = 0.18
		p.local_coords = true
		var quad := QuadMesh.new()
		quad.size = Vector2(0.12, 0.38)
		p.draw_pass_1 = quad
		var proc := ParticleProcessMaterial.new()
		proc.direction = Vector3(0, -1, 0)
		proc.initial_velocity_min = 6.0
		proc.initial_velocity_max = 9.0
		proc.gravity = Vector3(0, -2.4, 0)
		proc.scale_min = 0.42
		proc.scale_max = 0.72
		proc.color = Color(0.38, 0.76, 1.0, 0.95)
		p.process_material = proc
		p.position = off
		p.rotation_degrees = Vector3(90, 0, 0)
		p.emitting = false
		add_child(p)
		_thruster_particles.append(p)


func _set_thruster_particles(active: bool, intensity: float) -> void:
	for p in _thruster_particles:
		var proc: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
		if proc != null:
			proc.initial_velocity_min = lerpf(2.8, 8.2, intensity)
			proc.initial_velocity_max = lerpf(4.2, 12.0, intensity)
			proc.scale_min = lerpf(0.2, 0.48, intensity)
			proc.scale_max = lerpf(0.42, 0.8, intensity)
			proc.color = Color(0.4, 0.8, 1.0, lerpf(0.42, 0.95, intensity))
		p.emitting = active


func _update_power_budget(delta: float, forward_input: float, boost_pressed: bool) -> void:
	_battery_power = minf(_battery_max_power, _battery_power + _power_regen_rate * delta)
	if absf(forward_input) > 0.05 and _contact_count() > 0:
		_consume_power(_drive_power_drain * absf(forward_input) * delta)
	if boost_pressed and not _thruster_locked_until_full and _thruster_fuel > 0.0:
		_consume_power(_thruster_power_drain_mult * thruster_burn_rate * delta * 0.18)


func _consume_power(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _battery_power < amount:
		return false
	_battery_power -= amount
	return true


func set_primary_color(color: Color) -> void:
	_primary_color = color
	_recolor_variant_meshes()


func _recolor_variant_meshes() -> void:
	for variant in _variant_visuals:
		_recolor_mesh_children(variant)


func _recolor_mesh_children(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			var mat: Material = mesh_node.material_override
			if mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat as StandardMaterial3D
				var n: String = mesh_node.name.to_lower()
				var recolorable: bool = n.contains("frame") or n.contains("brace") or n.contains("skirt") or n.contains("mast")
				if recolorable:
					var duplicate_mat: StandardMaterial3D = std_mat.duplicate() as StandardMaterial3D
					duplicate_mat.albedo_color = _primary_color
					mesh_node.material_override = duplicate_mat
		_recolor_mesh_children(child)


func _return_to_main_menu() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.last_played_variant = state.selected_rover_variant
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _handle_run_end(player_won: bool, reason: String) -> void:
	if _run_ending:
		return
	_run_ending = true
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("finish_run"):
		state.finish_run(player_won)
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("run_end", "won=%s reason=%s score=%d" % [str(player_won), reason, _ore_collected])
	set_physics_process(false)
	call_deferred("_return_to_main_menu")


func _check_win_altitude() -> void:
	if _planet == null:
		return
	var planet_radius_value: float = float(_planet.get("planet_radius")) if _planet.has_method("get") else 0.0
	var altitude: float = global_position.distance_to(_planet.global_position) - planet_radius_value
	if altitude >= win_altitude_above_surface:
		_handle_run_end(true, "escape_altitude")


func _apply_mission_gravity() -> void:
	var mission_generator := get_node_or_null("/root/MissionGenerator")
	if mission_generator == null:
		return
	var mission: Dictionary = mission_generator.get_current_mission()
	if mission.is_empty():
		return
	var gravity_mult: float = float(mission.get("gravity_multiplier", 1.0))
	gravity_strength = 26.0 * gravity_mult


func _resolve_planet() -> void:
	if _planet != null and is_instance_valid(_planet):
		return
	if not planet_path.is_empty():
		_planet = get_node_or_null(planet_path) as Node3D
	if _planet != null:
		return
	var found: Array[Node] = get_tree().get_nodes_in_group("gravity_source")
	if found.is_empty():
		_planet = null
	else:
		_planet = found[0] as Node3D


func _ensure_spawn_above_surface() -> void:
	_resolve_planet()
	if _planet == null or not _planet.has_method("get_surface_spawn_from_direction"):
		return
	var radial_dir: Vector3 = (global_position - _planet.global_position).normalized()
	if radial_dir.length_squared() < 0.0001:
		radial_dir = Vector3.UP
	var clearance: float = _estimate_spawn_clearance()
	var info: Dictionary = _planet.get_surface_spawn_from_direction(radial_dir, 340.0, clearance, [self])
	if info.is_empty():
		return
	var safe_point: Vector3 = info.get("point", global_position)
	var surface_up: Vector3 = info.get("normal", radial_dir)
	global_position = safe_point
	var forward: Vector3 = Vector3.FORWARD.slide(surface_up).normalized()
	if forward.length_squared() < 0.001:
		forward = surface_up.cross(Vector3.RIGHT).normalized()
	global_basis = Basis.looking_at(forward, surface_up, true).orthonormalized()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _estimate_spawn_clearance() -> float:
	if _chassis_collision == null or _chassis_collision.shape == null:
		return 42.0
	var s: Shape3D = _chassis_collision.shape
	if s is BoxShape3D:
		var box: BoxShape3D = s as BoxShape3D
		return maxf(24.0, maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.2)
	if s is SphereShape3D:
		return maxf(24.0, (s as SphereShape3D).radius * 2.0)
	if s is CapsuleShape3D:
		var cap: CapsuleShape3D = s as CapsuleShape3D
		return maxf(24.0, cap.height + cap.radius)
	if s is CylinderShape3D:
		var cyl: CylinderShape3D = s as CylinderShape3D
		return maxf(24.0, cyl.height + cyl.radius)
	return 42.0


func _apply_planet_gravity() -> void:
	if _planet == null:
		return
	var toward_center: Vector3 = (_planet.global_position - global_position).normalized()
	apply_central_force(toward_center * gravity_strength * mass)


func _apply_stability_torque(delta: float) -> void:
	if _planet == null:
		return
	var surface_up: Vector3 = (global_position - _planet.global_position).normalized()
	var align_axis: Vector3 = global_basis.y.cross(surface_up)
	if align_axis.length_squared() < 1e-8:
		return
	var factor: float = 1.0 if _grounded else 0.18
	apply_torque(align_axis.normalized() * anti_roll_force * factor)
	_apply_self_righting_assist(surface_up, align_axis, delta)


func _apply_self_righting_assist(surface_up: Vector3, align_axis: Vector3, delta: float) -> void:
	var up_alignment: float = global_basis.y.dot(surface_up)
	var speed: float = linear_velocity.length()
	var bad_tilt: bool = up_alignment < 0.18
	var likely_stuck: bool = bad_tilt and speed < 2.2
	if likely_stuck:
		_stuck_tilt_timer = minf(_stuck_tilt_timer + delta, 6.0)
	else:
		_stuck_tilt_timer = maxf(_stuck_tilt_timer - delta * 1.35, 0.0)
	if align_axis.length_squared() < 1e-8:
		return
	# Only assist when actually upside-down/stuck. No baseline torque when healthy.
	if _stuck_tilt_timer <= 0.02:
		return
	var assist: float = 0.45 + _stuck_tilt_timer * 0.65
	apply_torque(align_axis.normalized() * assist)


func _update_wheel_contacts() -> void:
	for i in range(_ground_rays.size()):
		var ray: RayCast3D = _ground_rays[i]
		if not ray.enabled:
			_wheel_contact[i] = false
			continue
		ray.force_raycast_update()
		_wheel_contact[i] = ray.is_colliding()


func _contact_count() -> int:
	var n: int = 0
	for c in _wheel_contact:
		if c:
			n += 1
	return n


func _apply_drive(forward_input: float, effective_turn_input: float, forward_speed: float) -> void:
	var n: int = _contact_count()
	if n == 0:
		return

	var contact_scale: float = float(n) / 4.0

	var speed_ratio: float = clampf(absf(forward_speed) / max(max_drive_speed, 0.1), 0.0, 1.0)
	var signed_force: float = forward_input * drive_force * (1.0 - 0.65 * speed_ratio)
	if forward_input < 0.0:
		signed_force *= reverse_force_scale
	# Only wheels on the ground contribute drive; total thrust scales with contact count.
	var per_wheel_drive: float = signed_force / float(n)
	_apply_force_at_touching_wheels(-global_basis.z * per_wheel_drive)

	# Brake harder when player is steering against current movement direction.
	if absf(forward_input) > 0.01 and signf(forward_input) != signf(forward_speed) and absf(forward_speed) > 0.5:
		var per_brake: float = brake_force / float(n)
		_apply_force_at_touching_wheels(global_basis.z * signf(forward_speed) * per_brake)

	# Prevent runaway top speed while preserving low-speed responsiveness.
	if absf(forward_speed) > max_drive_speed:
		var per_cap: float = (brake_force * 0.65) / float(n)
		_apply_force_at_touching_wheels(global_basis.z * signf(forward_speed) * per_cap)

	if absf(forward_speed) >= moving_turn_speed_threshold:
		var turn_speed_scale: float = clampf(absf(forward_speed) / 9.0, 0.35, 1.0)
		apply_torque(
			global_basis.y * (effective_turn_input * turn_torque * turn_speed_scale * contact_scale)
		)

	# Downforce total scales with wheels on ground; split across touching wheels only.
	var per_down: float = downforce / 4.0
	var surface_up: Vector3 = global_basis.y
	if _planet != null:
		surface_up = (global_position - _planet.global_position).normalized()
	_apply_force_at_touching_wheels(-surface_up * per_down)


func _apply_force_at_touching_wheels(force_vector: Vector3) -> void:
	for i in range(min(_wheel_contact.size(), _wheel_pivots.size())):
		if not _wheel_contact[i]:
			continue
		var rel: Vector3 = _wheel_pivots[i].global_position - global_position
		apply_force(force_vector, rel)


func _get_effective_turn_input(forward_input: float, turn_input: float, forward_speed: float) -> float:
	var direction_factor: float = 1.0
	if absf(forward_speed) >= moving_turn_speed_threshold:
		direction_factor = signf(forward_speed)
	elif absf(forward_input) > 0.01:
		direction_factor = signf(forward_input)
	return turn_input * direction_factor


func _apply_air_control(forward_input: float, turn_input: float) -> void:
	if _grounded:
		return
	# In-air pitch should match player expectation: W pitches nose down (forward), S pitches nose up.
	apply_torque(global_basis.x * (-forward_input * air_torque))
	apply_torque(global_basis.z * (turn_input * air_torque))


func _apply_ground_grip(delta: float) -> void:
	var n: int = _contact_count()
	if n == 0:
		return

	var contact_scale: float = float(n) / 4.0
	var lateral_speed: float = linear_velocity.dot(global_basis.x)
	var lateral_cancel_force: Vector3 = (
		-global_basis.x * lateral_speed * ground_grip * mass * contact_scale
	)
	var forward_speed: float = linear_velocity.dot(-global_basis.z)
	var drag_force: Vector3 = (
		global_basis.z * forward_speed * longitudinal_damping * mass * contact_scale
	)
	# Damp vertical bounce on landing (reduces jitter from grip + downforce fighting suspension).
	var vertical_speed: float = linear_velocity.dot(global_basis.y)
	var bounce_damp: Vector3 = -global_basis.y * vertical_speed * landing_vertical_damp * mass * contact_scale
	# Grounded support force now acts on center mass in addition to per-wheel forces.
	var surface_up: Vector3 = global_basis.y
	if _planet != null:
		surface_up = (global_position - _planet.global_position).normalized()
	var center_downforce: Vector3 = -surface_up * downforce * mass * contact_scale * 0.26
	apply_central_force(lateral_cancel_force + drag_force + bounce_damp + center_downforce)


func _apply_thruster(delta: float, boost_pressed: bool) -> void:
	if _permanent_thrusters_active:
		apply_central_force(global_basis.y * _permanent_thruster_force)
		_set_thruster_particles(true, 1.0)
		return
	if not boost_pressed:
		_thruster_was_pressed = false
		_set_thruster_particles(false, 0.0)
		return
	if _thruster_locked_until_full:
		# Fuel is recharging after landing; only weak afterburner allowed.
		apply_central_force(global_basis.y * thruster_afterburner_force)
		_set_thruster_particles(true, 0.35)
		return

	# Initial tap burst costs fuel once per press.
	if not _thruster_was_pressed:
		_thruster_was_pressed = true
		if _thruster_fuel > 0.0 and _consume_power(thruster_initial_burst_cost * 0.2):
			_thruster_fuel = maxf(0.0, _thruster_fuel - thruster_initial_burst_cost)
			apply_central_force(global_basis.y * thruster_initial_impulse_force)

	if _thruster_fuel > 0.0:
		var burn: float = thruster_burn_rate * delta
		_thruster_fuel = maxf(0.0, _thruster_fuel - burn)
		apply_central_force(global_basis.y * thruster_sustain_force)
		_set_thruster_particles(true, 1.0)
	else:
		apply_central_force(global_basis.y * thruster_afterburner_force)
		_set_thruster_particles(true, 0.35)


func _update_thruster_ui() -> void:
	if _thruster_bar == null:
		_thruster_bar = get_node_or_null("/root/Main/HUD/ThrusterPanel/ThrusterBar") as ProgressBar
		if _thruster_bar == null:
			return
	if _permanent_thrusters_active:
		_thruster_bar.value = 1.0
		return
	var remaining: float = _thruster_fuel / max(thruster_fuel_capacity, 0.01)
	_thruster_bar.value = clampf(remaining, 0.0, 1.0)


func _update_wheel_visuals(effective_turn_input: float, delta: float) -> void:
	var target_yaw: float = deg_to_rad(steer_max_degrees) * effective_turn_input
	var back_target_yaw: float = -target_yaw
	var t: float = clampf(steer_visual_speed * delta, 0.0, 1.0)
	_front_left_pivot.rotation.y = lerp_angle(_front_left_pivot.rotation.y, target_yaw, t)
	_front_right_pivot.rotation.y = lerp_angle(_front_right_pivot.rotation.y, target_yaw, t)
	_back_left_pivot.rotation.y = lerp_angle(_back_left_pivot.rotation.y, back_target_yaw, t)
	_back_right_pivot.rotation.y = lerp_angle(_back_right_pivot.rotation.y, back_target_yaw, t)

	var forward_speed: float = linear_velocity.dot(-global_basis.z)
	var spin_delta: float = (forward_speed / max(wheel_radius, 0.01)) * delta
	for wi in range(_wheel_meshes.size()):
		if wi < _wheel_contact.size() and not _wheel_contact[wi]:
			continue
		_wheel_meshes[wi].rotation.x += spin_delta

	var smooth_t: float = clampf(suspension_visual_smooth * delta, 0.0, 1.0)
	for i in range(min(_ground_rays.size(), _wheel_pivots.size())):
		var ray: RayCast3D = _ground_rays[i]
		var pivot: Node3D = _wheel_pivots[i]
		var base_pos: Vector3 = _base_pivot_positions[i]
		var raw_offset: float = 0.0
		if ray.is_colliding():
			var hit: Vector3 = ray.get_collision_point()
			var normal: Vector3 = ray.get_collision_normal()
			var target_hub: Vector3 = hit + normal * wheel_radius
			var pivot_local: Vector3 = to_local(target_hub)
			raw_offset = clampf(pivot_local.y - base_pos.y, -suspension_travel, suspension_travel)
		else:
			raw_offset = -suspension_travel * 0.45
		_suspension_smoothed[i] = lerpf(_suspension_smoothed[i], raw_offset, smooth_t)
		pivot.position.y = base_pos.y + _suspension_smoothed[i]


func _update_thruster_refill(delta: float) -> void:
	if _grounded and not _was_grounded_last_frame:
		_thruster_locked_until_full = true

	if _thruster_locked_until_full:
		_thruster_fuel = minf(thruster_fuel_capacity, _thruster_fuel + thruster_refill_rate * delta)
		if _thruster_fuel >= thruster_fuel_capacity - 0.001:
			_thruster_fuel = thruster_fuel_capacity
			_thruster_locked_until_full = false


func _setup_radar_materials() -> void:
	_radar_button_mats.clear()
	for button in _radar_buttons:
		var base_mat: StandardMaterial3D = button.material_override as StandardMaterial3D
		if base_mat == null:
			continue
		var dup: StandardMaterial3D = base_mat.duplicate() as StandardMaterial3D
		dup.emission_enabled = true
		dup.emission = Color(0.35, 0.03, 0.03, 1.0)
		dup.emission_energy_multiplier = 0.12
		button.material_override = dup
		_radar_button_mats.append(dup)


func _setup_radar_audio() -> void:
	_radar_audio_player = AudioStreamPlayer3D.new()
	_radar_audio_player.name = "RadarBeepPlayer"
	_radar_audio_player.max_distance = 75.0
	_radar_audio_player.unit_size = 8.0
	_radar_audio_player.volume_db = radar_beep_volume_db
	add_child(_radar_audio_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.18
	_radar_audio_player.stream = generator
	_radar_audio_player.play()
	_radar_audio_playback = _radar_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _update_ore_radar(delta: float) -> void:
	_find_nearest_ore()
	var ore_in_range: bool = _nearest_ore != null and _nearest_ore_dist <= radar_range
	if not ore_in_range:
		_radar_flash_timer = 0.0
		_set_radar_flash(false)
		return

	var flash_interval: float = 1.0 / maxf(radar_flash_hz, 0.1)
	_radar_flash_timer += delta
	while _radar_flash_timer >= flash_interval:
		_radar_flash_timer -= flash_interval
		_radar_flash_on = not _radar_flash_on
		_set_radar_flash(_radar_flash_on)
		_emit_radar_beep()


func _set_radar_flash(enabled: bool) -> void:
	_radar_flash_on = enabled
	for mat in _radar_button_mats:
		mat.emission_energy_multiplier = 4.0 if enabled else 0.55


func _emit_radar_beep() -> void:
	if _radar_audio_playback == null:
		return
	var freq: float = 1020.0
	var seconds: float = 0.06
	var sample_rate: float = 22050.0
	var frame_count: int = int(seconds * sample_rate)
	for i in range(frame_count):
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - float(i) / float(maxi(frame_count, 1))
		var amp: float = 0.14 * envelope
		var v: float = sin(TAU * freq * t) * amp
		_radar_audio_playback.push_frame(Vector2(v, v))


func _find_nearest_ore() -> void:
	_nearest_ore = null
	_nearest_ore_dist = INF
	if not is_inside_tree() or get_tree() == null:
		return
	var deposits: Array[Node] = get_tree().get_nodes_in_group("ore_deposit")
	for node in deposits:
		if not is_instance_valid(node):
			continue
		if node.has_method("is_collected") and node.call("is_collected"):
			continue
		var ore_node: Node3D = node as Node3D
		if ore_node == null:
			continue
		var d: float = global_position.distance_to(ore_node.global_position)
		if d < _nearest_ore_dist:
			_nearest_ore_dist = d
			_nearest_ore = ore_node


func _handle_mining_input() -> void:
	if not Input.is_action_just_pressed("mine_ore"):
		return
	if _nearest_ore != null and _nearest_ore_dist <= radar_range:
		_set_ore_direction_hint()
	if _nearest_ore == null or _nearest_ore_dist > mining_range:
		return
	if not _consume_power(_mining_power_cost):
		return
	if not _nearest_ore.has_method("collect"):
		return
	var gained: int = int(_nearest_ore.call("collect"))
	if gained <= 0:
		return
	var collected_distance: float = _nearest_ore_dist
	_ore_collected += gained
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("add_score"):
		state.add_score(gained)
	_nearest_ore.queue_free()
	_nearest_ore = null
	_nearest_ore_dist = INF
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("ore_collected", "value=%d total=%d distance=%.2f" % [gained, _ore_collected, collected_distance])


func _update_gameplay_ui(forward_speed: float) -> void:
	if _score_label == null:
		_score_label = get_node_or_null("/root/Main/HUD/StatusPanel/ScoreLabel") as Label
	if _ore_distance_label == null:
		_ore_distance_label = get_node_or_null("/root/Main/HUD/StatusPanel/OreDistanceLabel") as Label
	if _radar_state_label == null:
		_radar_state_label = get_node_or_null("/root/Main/HUD/StatusPanel/RadarStateLabel") as Label
	if _mining_prompt_label == null:
		_mining_prompt_label = get_node_or_null("/root/Main/HUD/StatusPanel/MiningPromptLabel") as Label
	if _speed_label == null:
		_speed_label = get_node_or_null("/root/Main/HUD/StatusPanel/SpeedLabel") as Label
	if _ore_direction_label == null:
		_ore_direction_label = get_node_or_null("/root/Main/HUD/StatusPanel/OreDirectionLabel") as Label
	if _weapon_label == null:
		_weapon_label = get_node_or_null("/root/Main/HUD/StatusPanel/WeaponLabel") as Label
	if _weapon_stats_label == null:
		_weapon_stats_label = get_node_or_null("/root/Main/HUD/StatusPanel/WeaponStatsLabel") as Label
	if _power_bar == null:
		_power_bar = get_node_or_null("/root/Main/HUD/PowerPanel/PowerBar") as ProgressBar
	if _crosshair == null:
		_crosshair = get_node_or_null("/root/Main/HUD/Crosshair") as Label

	if _score_label != null:
		_score_label.text = "Score: %d ore" % _ore_collected
	if _ore_distance_label != null:
		if _nearest_ore == null:
			_ore_distance_label.text = "Closest Ore: none detected"
		else:
			_ore_distance_label.text = "Closest Ore: %.1f m" % _nearest_ore_dist
	if _radar_state_label != null:
		var radar_on: bool = _nearest_ore != null and _nearest_ore_dist <= radar_range
		if _nearest_ore != null and _nearest_ore_dist <= mining_range and _has_metal_detector:
			_radar_state_label.text = "Radar: MINING WINDOW LOCKED"
		else:
			_radar_state_label.text = "Radar: ORE IN RANGE" if radar_on else "Radar: scanning..."
	if _mining_prompt_label != null:
		var can_mine: bool = _nearest_ore != null and _nearest_ore_dist <= mining_range
		_mining_prompt_label.text = "Mining: Press G to collect" if can_mine else "Mining: Move closer and press G"
	if _ore_direction_label != null:
		var radar_contact: bool = _nearest_ore != null and _nearest_ore_dist <= radar_range
		if radar_contact:
			_ore_direction_label.text = _build_ore_direction_text()
		elif _ore_direction_hint_timer > 0.0:
			_ore_direction_label.text = _ore_direction_hint_text
		else:
			_ore_direction_label.text = "Ore Direction: --"
	if _speed_label != null:
		_speed_label.text = "Speed: %.1f m/s" % absf(forward_speed)
	if _weapon_label != null:
		_weapon_label.text = "Weapon: %s" % _get_weapon_name()
	if _weapon_stats_label != null:
		_weapon_stats_label.text = _build_weapon_stats_text()
	if _power_bar != null:
		var power_ratio: float = 0.0 if _battery_max_power <= 0.01 else _battery_power / _battery_max_power
		_power_bar.value = clampf(power_ratio, 0.0, 1.0)
	if _crosshair != null:
		_crosshair.visible = _has_gatling or _has_big_betsy


func _get_weapon_name() -> String:
	if _has_big_betsy:
		return "Big Betsy"
	if _has_gatling:
		return "Gatling Gun"
	return "None"


func _build_weapon_stats_text() -> String:
	if _has_big_betsy:
		return "Weapon Stats: Dmg 16 | Cooldown 0.65s | Knockback High"
	if _has_gatling:
		return "Weapon Stats: Dmg 6 | Fire Rate 11/s | Knockback Low"
	return "Weapon Stats: --"


func _update_weapon_system(delta: float) -> void:
	_fire_cooldown_timer = maxf(0.0, _fire_cooldown_timer - delta)
	if not (_has_gatling or _has_big_betsy):
		_fire_hold_last_frame = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return
	var fire_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _has_gatling:
		if fire_held:
			_try_fire_weapon(0.09, 95.0, Color(0.95, 0.8, 0.25, 1.0), _weapon_power_cost)
	else:
		var fire_just_pressed: bool = fire_held and not _fire_hold_last_frame
		if fire_just_pressed:
			_try_fire_weapon(0.65, 125.0, Color(1.0, 0.45, 0.2, 1.0), _weapon_power_cost * 1.8)
	_fire_hold_last_frame = fire_held


func _try_fire_weapon(cooldown: float, max_distance: float, color: Color, power_cost: float) -> void:
	if _fire_cooldown_timer > 0.0:
		return
	if not _consume_power(power_cost):
		return
	_fire_cooldown_timer = cooldown
	var start: Vector3 = global_position + (-global_basis.z * 1.55) + (global_basis.y * 0.22)
	var dir: Vector3 = -global_basis.z
	var end: Vector3 = start + dir * max_distance
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [self]
	query.collide_with_areas = true
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("apply_damage"):
			var damage: float = 16.0 if _has_big_betsy else 6.0
			collider.apply_damage(damage)
	_spawn_shot_visual(start, end, color)


func _update_auto_drill(delta: float) -> void:
	if not _has_auto_drill:
		return
	_auto_drill_timer += delta
	if _auto_drill_timer < 0.45:
		return
	_auto_drill_timer = 0.0
	if _nearest_ore == null or _nearest_ore_dist > mining_range:
		return
	if not _consume_power(_mining_power_cost * 0.5):
		return
	if not _nearest_ore.has_method("collect"):
		return
	var gained: int = int(_nearest_ore.call("collect"))
	if gained <= 0:
		return
	_ore_collected += gained
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("add_score"):
		state.add_score(gained)
	_nearest_ore.queue_free()
	_nearest_ore = null
	_nearest_ore_dist = INF
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("ore_auto_collected", "value=%d total=%d" % [gained, _ore_collected])


func _set_ore_direction_hint() -> void:
	if _nearest_ore == null:
		return
	_ore_direction_hint_text = _build_ore_direction_text()
	_ore_direction_hint_timer = 1.75


func _build_ore_direction_text() -> String:
	if _nearest_ore == null:
		return "Ore Direction: --"
	var to_ore: Vector3 = _nearest_ore.global_position - global_position
	var local: Vector3 = global_basis.inverse() * to_ore
	var fb: String = "Front" if local.z < 0.0 else "Back"
	var lr: String = "Left" if local.x < 0.0 else "Right"
	var dominant: String
	if absf(local.x) > absf(local.z) * 1.4:
		dominant = lr
	elif absf(local.z) > absf(local.x) * 1.4:
		dominant = fb
	else:
		dominant = "%s-%s" % [fb, lr]
	return "Ore Direction: %s (%.1fm)" % [dominant, _nearest_ore_dist]


func _update_hint_timers(delta: float) -> void:
	_ore_direction_hint_timer = maxf(0.0, _ore_direction_hint_timer - delta)


func activate_permanent_thrusters() -> void:
	_permanent_thrusters_active = true
	_permanent_thruster_force = thruster_sustain_force + 220.0
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("jetpack_powerup_collected", "permanent_thrusters=true")


func apply_external_knockback(force_vec: Vector3) -> void:
	apply_central_impulse(force_vec)
	sleeping = false


func _spawn_shot_visual(start: Vector3, end: Vector3, color: Color) -> void:
	if _shot_visuals_root == null:
		return
	var distance: float = start.distance_to(end)
	if distance < 0.05:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, distance)
	tracer.mesh = mesh
	tracer.global_position = start.lerp(end, 0.5)
	tracer.look_at(end, global_basis.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	_shot_visuals_root.add_child(tracer)
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free()
	)
	_spawn_simple_burst(start, color, 0.16)
	_spawn_simple_burst(end, color, 0.22)


func _spawn_simple_burst(world_pos: Vector3, color: Color, scale_mul: float) -> void:
	if _shot_visuals_root == null:
		return
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08 * scale_mul
	mesh.height = mesh.radius * 2.0
	puff.mesh = mesh
	puff.global_position = world_pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = mat
	_shot_visuals_root.add_child(puff)
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(puff):
			puff.queue_free()
	)


func _check_button_orientation_reset() -> void:
	_reset_button_ray.force_raycast_update()
	if not _reset_button_ray.is_colliding():
		return

	var contact_normal: Vector3 = _reset_button_ray.get_collision_normal()
	# Only trigger if upside-down enough for the roof button to hit the ground.
	if contact_normal.dot(global_basis.y) > -0.45:
		return
	_handle_run_end(false, "red_button")


func _reset_orientation_only() -> void:
	_resolve_planet()
	var current_origin: Vector3 = global_transform.origin
	if _planet != null:
		var surface_up: Vector3 = (current_origin - _planet.global_position).normalized()
		var forward: Vector3 = (-global_basis.z).slide(surface_up)
		if forward.length_squared() < 0.001:
			forward = surface_up.cross(global_basis.x)
		forward = forward.normalized()
		var basis: Basis = Basis.looking_at(forward, surface_up, true).orthonormalized()
		global_transform = Transform3D(basis, current_origin + surface_up * 0.35)
	else:
		var target_basis: Basis = _spawn_transform.basis.orthonormalized()
		global_transform = Transform3D(target_basis, current_origin + Vector3.UP * 0.2)
	angular_velocity = Vector3.ZERO


func _reset_vehicle_state() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	_front_left_pivot.rotation.y = 0.0
	_front_right_pivot.rotation.y = 0.0
	_back_left_pivot.rotation.y = 0.0
	_back_right_pivot.rotation.y = 0.0
	for i in range(min(_wheel_meshes.size(), _base_pivot_positions.size())):
		_wheel_meshes[i].rotation = Vector3(0, 0, 1.5708)
		_wheel_pivots[i].position = _base_pivot_positions[i]
	for j in range(_suspension_smoothed.size()):
		_suspension_smoothed[j] = 0.0
	_grounded = false
	_was_grounded_last_frame = false
	_thruster_fuel = thruster_fuel_capacity
	_thruster_locked_until_full = false
	_thruster_was_pressed = false
	_battery_power = _battery_max_power


func _log_telemetry(delta: float, forward_speed: float) -> void:
	_telemetry_timer += delta
	if _telemetry_timer < 0.75:
		return
	_telemetry_timer = 0.0
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		var ore_in_radar: bool = _nearest_ore != null and _nearest_ore_dist <= radar_range
		var details: String = "v=%.2f fuel=%.1f grounded=%s variant=%d ore_total=%d ore_in_radar=%s ore_dist=%.2f" % [
			forward_speed,
			_thruster_fuel,
			str(_grounded),
			_active_variant_index,
			_ore_collected,
			str(ore_in_radar),
			_nearest_ore_dist if _nearest_ore != null else -1.0
		]
		logger.log_event("rover_telemetry", details)
