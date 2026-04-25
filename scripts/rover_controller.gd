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
@export var thruster_initial_impulse_force: float = 280.0
@export var thruster_sustain_force: float = 170.0
@export var thruster_afterburner_force: float = 40.0
@export var thruster_fuel_capacity: float = 100.0
@export var thruster_initial_burst_cost: float = 18.0
@export var thruster_burn_rate: float = 22.0
@export var thruster_refill_rate: float = 34.0
@export var planet_path: NodePath = NodePath("../Planet")
@export var gravity_strength: float = 26.0
@export var anti_roll_force: float = 22.0
@export var radar_range: float = 55.0
@export var mining_range: float = 8.0
@export var radar_flash_hz: float = 2.0
@export var radar_beep_volume_db: float = -30.0

@onready var _ground_rays: Array[RayCast3D] = [
	$GroundRays/FrontLeftRay,
	$GroundRays/FrontRightRay,
	$GroundRays/BackLeftRay,
	$GroundRays/BackRightRay
]
@onready var _reset_button_ray: RayCast3D = $ResetButton/ButtonRay
@onready var _front_left_pivot: Node3D = $WheelVisuals/FrontLeftWheelPivot
@onready var _front_right_pivot: Node3D = $WheelVisuals/FrontRightWheelPivot
@onready var _back_left_pivot: Node3D = $WheelVisuals/BackLeftWheelPivot
@onready var _back_right_pivot: Node3D = $WheelVisuals/BackRightWheelPivot
@onready var _wheel_meshes: Array[MeshInstance3D] = [
	$WheelVisuals/FrontLeftWheelPivot/FrontLeftWheel,
	$WheelVisuals/FrontRightWheelPivot/FrontRightWheel,
	$WheelVisuals/BackLeftWheelPivot/BackLeftWheel,
	$WheelVisuals/BackRightWheelPivot/BackRightWheel
]
@onready var _variant_visuals: Array[Node3D] = [
	$VariantRoot/VariantA
]
@onready var _radar_buttons: Array[MeshInstance3D] = [
	$VariantRoot/VariantA/RadarButtonFront,
	$VariantRoot/VariantA/RadarButtonDish
]
@onready var _thruster_bar: ProgressBar = get_node_or_null("/root/Main/HUD/ThrusterPanel/ThrusterBar") as ProgressBar

var _grounded: bool = false
var _was_grounded_last_frame: bool = false
var _thruster_fuel: float = 100.0
var _thruster_locked_until_full: bool = false
var _thruster_was_pressed: bool = false
var _spawn_transform: Transform3D
var _base_pivot_positions: Array[Vector3] = []
var _wheel_contact: Array[bool] = [false, false, false, false]
var _suspension_smoothed: Array[float] = [0.0, 0.0, 0.0, 0.0]
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

const VARIANT_STATS: Array[Dictionary] = [
	{ # Default Rover
		"mass": 8.0, "drive_force": 760.0, "max_drive_speed": 28.0,
		"thruster_fuel_capacity": 100.0, "thruster_initial_impulse_force": 280.0, "thruster_sustain_force": 170.0
	}
]


func _ready() -> void:
	_spawn_transform = global_transform
	_base_pivot_positions = [
		_front_left_pivot.position,
		_front_right_pivot.position,
		_back_left_pivot.position,
		_back_right_pivot.position
	]
	_apply_selected_variant()
	_apply_custom_loadout_stats()
	_apply_selected_color()
	_apply_mission_gravity()
	_setup_radar_materials()
	_setup_radar_audio()
	_thruster_fuel = thruster_fuel_capacity


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_vehicle"):
		_return_to_main_menu()
		return

	_update_wheel_contacts()
	_grounded = _wheel_contact[0] or _wheel_contact[1] or _wheel_contact[2] or _wheel_contact[3]
	_resolve_planet()
	if _planet != null:
		_apply_planet_gravity()
		_apply_stability_torque()
	var forward_input: float = Input.get_axis("move_backward", "move_forward")
	var turn_input: float = Input.get_axis("move_right", "move_left")
	var boost_pressed: bool = Input.is_action_pressed("thruster")
	var forward_speed: float = linear_velocity.dot(-global_basis.z)
	var effective_turn_input: float = _get_effective_turn_input(forward_input, turn_input, forward_speed)

	_apply_drive(forward_input, effective_turn_input, forward_speed)
	_apply_air_control(forward_input, turn_input)
	_apply_ground_grip(delta)
	_apply_thruster(delta, boost_pressed)
	_update_wheel_visuals(effective_turn_input, delta)
	_update_thruster_ui()
	_check_button_orientation_reset()
	_update_thruster_refill(delta)
	_update_ore_radar(delta)
	_handle_mining_input()
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
	thruster_refill_rate = float(stats.get("thruster_refill_rate", thruster_refill_rate))
	thruster_burn_rate = float(stats.get("thruster_burn_rate", thruster_burn_rate))
	radar_range = float(stats.get("radar_range", radar_range))
	mining_range = float(stats.get("mining_range", mining_range))
	radar_flash_hz = float(stats.get("radar_flash_hz", radar_flash_hz))


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
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


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


func _apply_planet_gravity() -> void:
	if _planet == null:
		return
	var toward_center: Vector3 = (_planet.global_position - global_position).normalized()
	apply_central_force(toward_center * gravity_strength * mass)


func _apply_stability_torque() -> void:
	if _planet == null:
		return
	var surface_up: Vector3 = (global_position - _planet.global_position).normalized()
	var align_axis: Vector3 = global_basis.y.cross(surface_up)
	if align_axis.length_squared() < 1e-8:
		return
	var factor: float = 1.0 if _grounded else 0.18
	apply_torque(align_axis.normalized() * anti_roll_force * factor)


func _update_wheel_contacts() -> void:
	for i in range(_ground_rays.size()):
		var ray: RayCast3D = _ground_rays[i]
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
	_apply_force_at_touching_wheels(-global_basis.y * per_down)


func _apply_force_at_touching_wheels(force_vector: Vector3) -> void:
	var pivots: Array[Node3D] = [_front_left_pivot, _front_right_pivot, _back_left_pivot, _back_right_pivot]
	for i in range(min(_wheel_contact.size(), pivots.size())):
		if not _wheel_contact[i]:
			continue
		var rel: Vector3 = pivots[i].global_position - global_position
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
	apply_central_force(lateral_cancel_force + drag_force + bounce_damp)


func _apply_thruster(delta: float, boost_pressed: bool) -> void:
	if not boost_pressed:
		_thruster_was_pressed = false
		return
	if _thruster_locked_until_full:
		# Fuel is recharging after landing; only weak afterburner allowed.
		apply_central_force(global_basis.y * thruster_afterburner_force)
		return

	# Initial tap burst costs fuel once per press.
	if not _thruster_was_pressed:
		_thruster_was_pressed = true
		if _thruster_fuel > 0.0:
			_thruster_fuel = maxf(0.0, _thruster_fuel - thruster_initial_burst_cost)
			apply_central_force(global_basis.y * thruster_initial_impulse_force)

	if _thruster_fuel > 0.0:
		var burn: float = thruster_burn_rate * delta
		_thruster_fuel = maxf(0.0, _thruster_fuel - burn)
		apply_central_force(global_basis.y * thruster_sustain_force)
	else:
		apply_central_force(global_basis.y * thruster_afterburner_force)


func _update_thruster_ui() -> void:
	if _thruster_bar == null:
		_thruster_bar = get_node_or_null("/root/Main/HUD/ThrusterPanel/ThrusterBar") as ProgressBar
		if _thruster_bar == null:
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

	var pivots: Array[Node3D] = [_front_left_pivot, _front_right_pivot, _back_left_pivot, _back_right_pivot]
	var smooth_t: float = clampf(suspension_visual_smooth * delta, 0.0, 1.0)
	for i in range(min(_ground_rays.size(), pivots.size())):
		var ray: RayCast3D = _ground_rays[i]
		var pivot: Node3D = pivots[i]
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
		if _radar_flash_on:
			_emit_radar_beep()


func _set_radar_flash(enabled: bool) -> void:
	_radar_flash_on = enabled
	for mat in _radar_button_mats:
		mat.emission_energy_multiplier = 1.5 if enabled else 0.12


func _emit_radar_beep() -> void:
	if _radar_audio_playback == null:
		return
	var freq: float = 920.0
	var seconds: float = 0.07
	var sample_rate: float = 22050.0
	var frame_count: int = int(seconds * sample_rate)
	for i in range(frame_count):
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - float(i) / float(maxi(frame_count, 1))
		var amp: float = 0.08 * envelope
		var v: float = sin(TAU * freq * t) * amp
		_radar_audio_playback.push_frame(Vector2(v, v))


func _find_nearest_ore() -> void:
	_nearest_ore = null
	_nearest_ore_dist = INF
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
	if _nearest_ore == null or _nearest_ore_dist > mining_range:
		return
	if not _nearest_ore.has_method("collect"):
		return
	var gained: int = int(_nearest_ore.call("collect"))
	if gained <= 0:
		return
	_ore_collected += gained
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("ore_collected", "value=%d total=%d distance=%.2f" % [gained, _ore_collected, _nearest_ore_dist])


func _check_button_orientation_reset() -> void:
	_reset_button_ray.force_raycast_update()
	if not _reset_button_ray.is_colliding():
		return

	var contact_normal: Vector3 = _reset_button_ray.get_collision_normal()
	# Only trigger if upside-down enough for the roof button to hit the ground.
	if contact_normal.dot(global_basis.y) > -0.45:
		return
	_reset_orientation_only()


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
	var pivots: Array[Node3D] = [_front_left_pivot, _front_right_pivot, _back_left_pivot, _back_right_pivot]
	for i in range(min(_wheel_meshes.size(), _base_pivot_positions.size())):
		_wheel_meshes[i].rotation = Vector3(0, 0, 1.5708)
		pivots[i].position = _base_pivot_positions[i]
	for j in range(_suspension_smoothed.size()):
		_suspension_smoothed[j] = 0.0
	_grounded = false
	_was_grounded_last_frame = false
	_thruster_fuel = thruster_fuel_capacity
	_thruster_locked_until_full = false
	_thruster_was_pressed = false


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
